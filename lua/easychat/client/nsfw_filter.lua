--[[-----------------------------------------------------------------------------
	NSFW / gore image filter

	Classifies embedded images entirely on the client, inside a hidden CEF (Chromium)
	browser. Nothing is sent to any third party -- the runtime and model are static
	CDN assets and inference happens locally. Verdicts are cached per url and shared
	with the renderer via EasyChat.ClassifyImage.

	This works because our embedded images are proxied through wsrv.nl, which sends
	`Access-Control-Allow-Origin: *`, so a cross-origin `<img crossorigin>` can be read
	back into a canvas for inference without tainting it.

	The model is OwenElliott/image-safety-classifier-xs (a small SwiftFormer) which
	classifies an image as SFW / NSFW (porn or highly suggestive) / NSFL (gore) in one
	pass, with normalisation + softmax baked into the graph.

	Chromium 86 notes (gmod's CEF version):
	  - onnxruntime-web's SIMD/threaded wasm builds won't compile on 86, so we force the
	    basic build (`wasm.simd = false`, `wasm.numThreads = 1`), which does run.
	  - ort 1.14 caps at onnx IR version 8, but this model is IR 10. That version is a
	    single varint at byte offset 1 of the protobuf, so we patch it 10 -> 8 in memory
	    before creating the session (the model uses no IR9/10-only features).
]]-------------------------------------------------------------------------------

-- easychat_nsfw_filter is created in easychat.lua (so settings.lua can reference it early)
local EC_NSFW = GetConVar("easychat_nsfw_filter")

-- confidence (0-1) the model needs. at/above HIDE we hide the image behind a click; between BLUR
-- and HIDE we're unsure so we just blur it. scores are softmax probabilities over SFW/NSFW/NSFL.
local HIDE_THRESHOLD = 0.6
local BLUR_THRESHOLD = 0.4

-- static assets, cache-served after first use. 1.14 is the last onnxruntime-web whose basic wasm
-- build still instantiates on chromium 86 (later ones need post-86 wasm features). the model is
-- OwenElliott/image-safety-classifier-xs mirrored in this repo's external_data (raw.githubusercontent
-- serves it with `Access-Control-Allow-Origin: *`, so the browser's fetch() can read it).
local ORT_VERSION = "1.14.0"
local ORT_SCRIPT_URL = "https://cdn.jsdelivr.net/npm/onnxruntime-web@" .. ORT_VERSION .. "/dist/ort.min.js"
local ORT_DIST_URL = "https://cdn.jsdelivr.net/npm/onnxruntime-web@" .. ORT_VERSION .. "/dist/"
local MODEL_URL = "https://raw.githubusercontent.com/Earu/EasyChat/master/external_data/image-safety-classifier-xs.onnx"

-- how long the actual classification may take before we give up and blur. it's measured from when
-- the browser *starts* working on the image, so neither the one-time model download nor time spent
-- queued behind other images counts against it.
local CLASSIFY_TIMEOUT = 8
local MODEL_LOAD_TIMEOUT = 30 -- if the model never loads at all, stop waiting and blur what's pending

local panel -- lazily created hidden classifier browser
local queue = {} -- { { id, url }, ... } waiting to be picked up by the browser
local pending = {} -- url -> { cb, ... } callbacks waiting on a verdict
local id_to_url = {} -- classify id -> url
local verdicts = {} -- url -> verdict (false | "blur" | "hide"), cached
local id_counter = 0
local runtime_failed = false -- the classifier couldn't load; blur everything to be safe
local model_ready = false -- the model has finished loading (lets the timeout exclude load time)

local function build_page()
	return ([==[<html><head></head><body>
<script src="%s"></script>
<script>
	var MODEL_URL = "%s";
	var sessionPromise = null;

	function getSession() {
		if (!sessionPromise) {
			ort.env.wasm.simd = false;       // chromium 86 can't compile the simd wasm build
			ort.env.wasm.numThreads = 1;     // no threaded build (no SharedArrayBuffer in DHTML)
			ort.env.wasm.proxy = false;
			ort.env.wasm.wasmPaths = "%s";
			sessionPromise = fetch(MODEL_URL).then(function(r) {
				return r.arrayBuffer();
			}).then(function(buf) {
				var bytes = new Uint8Array(buf);
				// patch onnx ir_version 10 -> 8 (byte 1) so ort 1.14 accepts the model
				if (bytes[0] === 8 && bytes[1] === 10) { bytes[1] = 8; }
				return ort.InferenceSession.create(bytes);
			});
		}
		return sessionPromise;
	}

	var MAX_FRAMES = 5; // most frames we sample from an animated gif

	// run the model on a single image url -> cb(nsfw, gore), or cb(-1, -1) on any failure
	function scoreImage(url, cb) {
		var img = new Image();
		img.crossOrigin = "anonymous";
		img.onload = function() {
			getSession().then(function(sess) {
				// model wants [1,3,224,224] rgb float32 in 0-255 (normalisation is baked in)
				var c = document.createElement("canvas");
				c.width = 224; c.height = 224;
				var ctx = c.getContext("2d");
				ctx.drawImage(img, 0, 0, 224, 224);
				var d = ctx.getImageData(0, 0, 224, 224).data; // rgba, row-major
				var n = 224 * 224;
				var f = new Float32Array(3 * n);
				for (var i = 0; i < n; i++) { // de-interleave rgba -> planar rgb (drop alpha)
					f[i] = d[i * 4]; f[n + i] = d[i * 4 + 1]; f[2 * n + i] = d[i * 4 + 2];
				}
				return sess.run({ image: new ort.Tensor("float32", f, [1, 3, 224, 224]) }).then(function(out) {
					var pr = out[sess.outputNames[0]].data; // probabilities, order [NSFL, NSFW, SFW]
					cb(pr[1], pr[0]); // nsfw, gore
				});
			}).catch(function() { cb(-1, -1); }); // any failure -> unknown
		};
		img.onerror = function() { cb(-1, -1); };
		img.src = url;
	}

	// count frames in a gif by walking its blocks (each 0x2C image descriptor is one frame)
	function countGifFrames(b) {
		if (b.length < 13 || b[0] !== 0x47 || b[1] !== 0x49 || b[2] !== 0x46) return 1; // not "GIF"
		var p = 13;
		if (b[10] & 0x80) { p += 3 * (1 << ((b[10] & 0x07) + 1)); } // skip global color table
		var frames = 0;
		while (p < b.length) {
			var block = b[p++];
			if (block === 0x3B) break; // trailer
			if (block === 0x2C) { // image descriptor = one frame
				frames++;
				var lflags = b[p + 8];
				p += 9;
				if (lflags & 0x80) { p += 3 * (1 << ((lflags & 0x07) + 1)); } // local color table
				p++; // lzw min code size
				while (p < b.length) { var sz = b[p++]; if (sz === 0) break; p += sz; } // image data sub-blocks
			} else if (block === 0x21) { // extension: label + sub-blocks
				p++;
				while (p < b.length) { var sz2 = b[p++]; if (sz2 === 0) break; p += sz2; }
			} else { break; } // unexpected -> stop counting
		}
		return frames > 0 ? frames : 1;
	}

	// count frames in an animated webp (RIFF container with one ANMF chunk per frame)
	function countWebpFrames(b) {
		var p = 12, frames = 0; // skip "RIFF" + file size + "WEBP"
		while (p + 8 <= b.length) {
			var size = (b[p + 4] | (b[p + 5] << 8) | (b[p + 6] << 16) | (b[p + 7] << 24)) >>> 0;
			if (b[p] === 0x41 && b[p + 1] === 0x4E && b[p + 2] === 0x4D && b[p + 3] === 0x46) frames++; // "ANMF"
			p += 8 + size + (size & 1); // chunk payloads are padded to an even length
		}
		return frames > 0 ? frames : 1;
	}

	// how many frames the image has, dispatched by format magic. only gif and webp -- the formats
	// wsrv can actually page for us -- get a real count; everything else is treated as one frame.
	function countFrames(b) {
		if (b.length >= 4 && b[0] === 0x47 && b[1] === 0x49 && b[2] === 0x46) return countGifFrames(b); // "GIF"
		if (b.length >= 12 && b[0] === 0x52 && b[1] === 0x49 && b[2] === 0x46 && b[3] === 0x46 &&
			b[8] === 0x57 && b[9] === 0x45 && b[10] === 0x42 && b[11] === 0x50) return countWebpFrames(b); // "RIFF"/"WEBP"
		return 1;
	}

	// evenly-spaced frame indices, at most MAX_FRAMES of them
	function pickPages(count) {
		if (count <= 1) return [0];
		if (count <= MAX_FRAMES) { var a = []; for (var i = 0; i < count; i++) a.push(i); return a; }
		var pages = [], seen = {};
		for (var j = 0; j < MAX_FRAMES; j++) {
			var pg = Math.round(j * (count - 1) / (MAX_FRAMES - 1));
			if (!seen[pg]) { seen[pg] = 1; pages.push(pg); }
		}
		return pages;
	}

	// score each frame url in turn, reporting the worst (max nsfw, max gore) across the ones that
	// classified. done sequentially so we never run two wasm inferences at once.
	function scoreFrames(urls, finish) {
		var idx = 0, any = false, worstNsfw = -1, worstGore = -1;
		function nextFrame() {
			if (idx >= urls.length) { finish(any ? worstNsfw : -1, any ? worstGore : -1); return; }
			scoreImage(urls[idx++], function(nsfw, gore) {
				if (nsfw >= 0) {
					any = true;
					if (nsfw > worstNsfw) worstNsfw = nsfw;
					if (gore > worstGore) worstGore = gore;
				}
				nextFrame();
			});
		}
		nextFrame();
	}

	// classify strictly one image at a time -- concurrent wasm inferences spike memory enough to
	// crash chromium 86 (especially when several images pile up while the model is still loading)
	var busy = false;

	function classify(id, url) {
		var done = false;
		function finish(nsfw, gore) {
			if (done) return; // real result or timeout already fired
			done = true;
			NSFW.Result(id, nsfw, gore);
			busy = false;
			pump(); // next one, if any
		}

		// wait for the model before starting the give-up clock, so the one-time model download (and
		// time queued behind other images) never counts against CLASSIFY_TIMEOUT -- it only bounds the
		// classification itself. then fetch the bytes once so we can tell how many frames it has: a
		// still image (or a format we can't page) is scored straight from those bytes -- no second
		// download -- while an animated gif/webp is sampled MAX_FRAMES via wsrv's &page= (worst wins).
		getSession().then(function() {
			setTimeout(function() { finish(-1, -1); }, %d); // took too long -> unknown -> blur
			return fetch(url);
		}).then(function(r) {
			return r.arrayBuffer();
		}).then(function(buf) {
			var count = countFrames(new Uint8Array(buf));
			if (count <= 1) {
				var blobUrl = URL.createObjectURL(new Blob([buf])); // same-origin blob -> canvas is readable
				scoreImage(blobUrl, function(nsfw, gore) { URL.revokeObjectURL(blobUrl); finish(nsfw, gore); });
				return;
			}
			var pages = pickPages(count);
			var base = url.replace("&n=-1", ""); // drop the all-frames flag; request one frame each
			var urls = pages.map(function(pg) { return base + "&n=1&page=" + pg + "&output=png"; });
			scoreFrames(urls, finish);
		}).catch(function() { scoreFrames([url], finish); }); // couldn't fetch -> load via <img> directly
	}

	// pick up the next queued image, but only if we aren't already classifying one
	function pump() {
		if (busy) return;
		NSFW.Next(function(id, url) {
			if (id > 0) { busy = true; classify(id, url); }
		});
	}

	// kick the model download off immediately so it's ready as early as possible, and tell lua when
	// it's loaded (or failed) so the per-image timeout can start counting only from then.
	if (typeof ort === "undefined") {
		NSFW.OnError();
	} else {
		getSession().then(function() { NSFW.OnReady(); pump(); }).catch(function() { NSFW.OnError(); });
	}
</script>
</body></html>]==]):format(ORT_SCRIPT_URL, MODEL_URL, ORT_DIST_URL, CLASSIFY_TIMEOUT * 1000)
end

local function ensure_panel()
	if IsValid(panel) then return end

	panel = vgui.Create("DHTML")
	panel:SetSize(16, 16)
	panel:SetPos(-10000, -10000) -- offscreen; kept in the vgui tree so its browser keeps ticking
	panel:SetAllowLua(false)

	panel:AddFunction("NSFW", "Next", function()
		local req = table.remove(queue, 1)
		if not req then return 0, "" end
		return req.id, req.url
	end)

	panel:AddFunction("NSFW", "OnError", function()
		-- runtime failed to load: stop trying and blur to be safe (we can't tell what's in the
		-- images), and clear anything already waiting instead of making it sit through the timeout
		runtime_failed = true
		EasyChat.Print(true, "nsfw filter: classifier failed to load, images will be blurred")

		for url, waiters in pairs(pending) do
			verdicts[url] = "blur"
			for _, cb in ipairs(waiters) do cb("blur") end
		end
		pending = {}
	end)

	panel:AddFunction("NSFW", "OnReady", function() model_ready = true end)

	panel:AddFunction("NSFW", "Result", function(id, nsfw, gore)
		local url = id_to_url[id]
		if not url then return end
		id_to_url[id] = nil

		-- false = show, "blur" = unsure so blur, "hide" = confidently nsfw/gore. a negative score
		-- means the browser couldn't classify it (image/runtime error) -> blur to be safe.
		local verdict = "blur"
		if nsfw >= 0 then
			local worst = math.max(nsfw, gore)
			if worst >= HIDE_THRESHOLD then
				verdict = "hide"
			elseif worst < BLUR_THRESHOLD then
				verdict = false
			end
		end

		verdicts[url] = verdict

		local waiters = pending[url]
		pending[url] = nil
		if waiters then
			for _, cb in ipairs(waiters) do cb(verdict) end
		end
	end)

	-- if the model never loads at all (e.g. the download wedges), don't leave images waiting forever
	timer.Simple(MODEL_LOAD_TIMEOUT, function()
		if model_ready or runtime_failed then return end
		runtime_failed = true
		EasyChat.Print(true, "nsfw filter: classifier didn't load in time, images will be blurred")
		for url, waiters in pairs(pending) do
			verdicts[url] = "blur"
			for _, cb in ipairs(waiters) do cb("blur") end
		end
		pending = {}
	end)

	panel:SetHTML(build_page())
end

-- Classifies an image url (the wsrv.nl-proxied one, so the canvas can be read cross-origin).
-- cb is always called exactly once with a verdict: false (show), "blur" (unsure/couldn't classify)
-- or "hide" (nsfw/gore). anything we can't get a verdict for blurs, so the filter never fails open.
function EasyChat.ClassifyImage(url, cb)
	if not EC_NSFW:GetBool() then cb(false) return end -- filter off: user's choice, show as-is
	if runtime_failed then cb("blur") return end -- classifier is down: blur to be safe

	local cached = verdicts[url]
	if cached ~= nil then cb(cached) return end

	if pending[url] then -- a classification for this url is already in flight
		pending[url][#pending[url] + 1] = cb
		return
	end
	pending[url] = { cb }

	id_counter = id_counter + 1
	local id = id_counter
	id_to_url[id] = url
	queue[#queue + 1] = { id = id, url = url }

	ensure_panel()
	panel:QueueJavascript("if (typeof pump === 'function') pump();")
	-- the give-up timeout lives in the browser now (started once the model is loaded), so it doesn't
	-- count the model download; the model-load watchdog above covers the model never loading at all.
end

-- synchronous peek at a cached verdict (nil = not classified yet)
function EasyChat.GetImageVerdict(url)
	return verdicts[url]
end
