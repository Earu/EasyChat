--[[-----------------------------------------------------------------------------
	NSFW / gore image filter

	Classifies embedded images entirely on the client, inside a hidden CEF (Chromium)
	browser. Nothing is sent to any third party -- the runtime and models are static
	CDN assets and inference happens locally. Verdicts are cached per url and shared
	with the renderer via EasyChat.ClassifyImage.

	Images arrive as their wsrv.nl-proxied url (wsrv sends `Access-Control-Allow-Origin: *`),
	so the browser can fetch the bytes cross-origin and read them into a canvas without
	tainting it. We fetch the bytes once; gif frames are then decoded locally (omggif),
	so we never re-fetch a gif per frame.

	Two models are ensembled (worst signal wins), because neither covers everything:
	  - OwenElliott/image-safety-classifier-xs (a small SwiftFormer, via onnxruntime-web)
	    gives SFW / NSFW / NSFL(gore) -- strong on photographic porn and the only source of
	    a gore signal, but weak on drawn/hentai.
	  - nsfwjs (a MobileNet, via tensorflow.js) gives Porn/Hentai/Sexy/... -- catches the
	    drawn/hentai content the first model misses.
	The combined nsfw score is max(xs.NSFW, nsfwjs.Porn + nsfwjs.Hentai); gore is xs.NSFL.
	For animated images we sample a few frames and keep the worst, short-circuiting as soon
	as any frame is a confident hide.

	Chromium 86 notes (gmod's CEF version):
	  - onnxruntime-web's SIMD/threaded wasm builds won't compile on 86, so we force the
	    basic build (`wasm.simd = false`, `wasm.numThreads = 1`), which does run. tfjs's own
	    wasm backend (3.x) runs on 86 too; 4.x does not.
	  - ort 1.14 caps at onnx IR version 8, but the onnx model is IR 10. That version is a
	    single varint at byte offset 1 of the protobuf, so we patch it 10 -> 8 in memory
	    before creating the session (the model uses no IR9/10-only features).
	  - the two models' inferences for a frame run in parallel, but we only ever process one
	    image (one frame) at a time, so at most two controlled inferences overlap -- that's
	    stable; the old crash was many classifications piling up at once.
	  - CEF 86 has no in-browser animated-webp frame decoder, so webp frames are still pulled
	    one at a time from wsrv's `&page=` (gif frames are decoded locally).
]]-------------------------------------------------------------------------------

-- easychat_nsfw_filter is created in easychat.lua (so settings.lua can reference it early)
local EC_NSFW = GetConVar("easychat_nsfw_filter")

-- confidence (0-1) the ensemble needs. at/above HIDE we hide the image behind a click; between BLUR
-- and HIDE we're unsure so we just blur it. the nsfw score is the worst of the two models' signals.
local HIDE_THRESHOLD = 0.6
local BLUR_THRESHOLD = 0.4

-- static assets, cache-served after first use. onnxruntime-web 1.14 is the last whose basic wasm
-- build instantiates on chromium 86, and tfjs 3.x + its wasm backend also run there (4.x needs
-- post-86 wasm features). the onnx model is mirrored in this repo's external_data (raw.githubusercontent
-- serves it with `Access-Control-Allow-Origin: *`); nsfwjs, its model and omggif come from jsdelivr.
local ORT_VERSION = "1.14.0"
local ORT_SCRIPT_URL = "https://cdn.jsdelivr.net/npm/onnxruntime-web@" .. ORT_VERSION .. "/dist/ort.min.js"
local ORT_DIST_URL = "https://cdn.jsdelivr.net/npm/onnxruntime-web@" .. ORT_VERSION .. "/dist/"
local MODEL_URL = "https://raw.githubusercontent.com/Earu/EasyChat/master/external_data/image-safety-classifier-xs.onnx"

local TFJS_VERSION = "3.21.0"
local NSFWJS_VERSION = "2.4.2"
local TFJS_SCRIPT_URL = "https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@" .. TFJS_VERSION .. "/dist/tf.min.js"
local TFJS_WASM_SCRIPT_URL = "https://cdn.jsdelivr.net/npm/@tensorflow/tfjs-backend-wasm@" .. TFJS_VERSION .. "/dist/tf-backend-wasm.min.js"
local TFJS_WASM_DIR = "https://cdn.jsdelivr.net/npm/@tensorflow/tfjs-backend-wasm@" .. TFJS_VERSION .. "/dist/"
local NSFWJS_SCRIPT_URL = "https://cdn.jsdelivr.net/npm/nsfwjs@" .. NSFWJS_VERSION .. "/dist/nsfwjs.min.js"
local NSFWJS_MODEL_URL = "https://cdn.jsdelivr.net/gh/infinitered/nsfwjs@master/models/mobilenet_v2/model.json"
local OMGGIF_SCRIPT_URL = "https://cdn.jsdelivr.net/npm/omggif@1.0.10/omggif.js"

-- how long the actual classification may take before we give up and blur. it's measured from when
-- the browser *starts* working on the image, so neither the one-time model download nor time spent
-- queued behind other images counts against it.
local CLASSIFY_TIMEOUT = 8
local MODEL_LOAD_TIMEOUT = 30 -- if the models never load at all, stop waiting and blur what's pending

local panel -- lazily created hidden classifier browser
local queue = {} -- { { id, url }, ... } waiting to be picked up by the browser
local pending = {} -- url -> { cb, ... } callbacks waiting on a verdict
local id_to_url = {} -- classify id -> url
local verdicts = {} -- url -> verdict (false | "blur" | "hide"), cached
local id_counter = 0
local runtime_failed = false -- the classifier couldn't load; blur everything to be safe
local model_ready = false -- the models have finished loading (lets the timeout exclude load time)

local function build_page()
	return ([==[<html><head></head><body>
<script src="%s"></script>
<script src="%s"></script>
<script src="%s"></script>
<script src="%s"></script>
<script src="%s"></script>
<script>
	var MODEL_URL = "%s", ORT_DIST = "%s", TFJS_WASM_DIR = "%s", NSFWJS_MODEL = "%s", HIDE = %s;
	var MAX_FRAMES = 5;      // most frames we sample from an animated image
	var modelsPromise = null;

	// load both classifiers. image-safety-classifier-xs (onnx) covers photographic porn + gore;
	// nsfwjs (tfjs mobilenet) covers drawn/hentai the first one misses.
	function getModels() {
		if (!modelsPromise) {
			ort.env.wasm.simd = false;       // chromium 86 can't compile the simd wasm build
			ort.env.wasm.numThreads = 1;     // no threaded build (no SharedArrayBuffer in DHTML)
			ort.env.wasm.proxy = false;
			ort.env.wasm.wasmPaths = ORT_DIST;
			modelsPromise = fetch(MODEL_URL).then(function(r) {
				return r.arrayBuffer();
			}).then(function(buf) {
				var bytes = new Uint8Array(buf);
				if (bytes[0] === 8 && bytes[1] === 10) { bytes[1] = 8; } // onnx ir_version 10 -> 8 for ort 1.14
				return ort.InferenceSession.create(bytes);
			}).then(function(session) {
				// load tfjs + nsfwjs *after* ort resolves, not alongside it -- two wasm modules compiling
				// at once spikes memory on chromium 86
				tf.wasm.setWasmPaths(TFJS_WASM_DIR);
				return tf.setBackend("wasm").then(function() {
					return nsfwjs.load(NSFWJS_MODEL, { size: 224 });
				}).then(function(nsfw) {
					return { session: session, nsfw: nsfw };
				});
			});
		}
		return modelsPromise;
	}

	// draw an image or canvas into a fresh 224x224 canvas (the size both models want)
	function to224(src) {
		var c = document.createElement("canvas");
		c.width = 224; c.height = 224;
		c.getContext("2d").drawImage(src, 0, 0, 224, 224);
		return c;
	}

	function loadImg(url) {
		return new Promise(function(resolve, reject) {
			var img = new Image();
			img.crossOrigin = "anonymous";
			img.onload = function() { resolve(img); };
			img.onerror = function() { reject(); };
			img.src = url;
		});
	}

	// score a 224x224 canvas with both models *in parallel* -> { nsfw, gore }. distinct runtimes, and
	// two controlled inferences overlapping is stable on 86 (unlike many classifications at once).
	function scoreCanvas(c) {
		return getModels().then(function(m) {
			var d = c.getContext("2d").getImageData(0, 0, 224, 224).data; // rgba, row-major
			var n = 224 * 224, f = new Float32Array(3 * n);
			for (var i = 0; i < n; i++) { // de-interleave rgba -> planar rgb (drop alpha), 0-255
				f[i] = d[i * 4]; f[n + i] = d[i * 4 + 1]; f[2 * n + i] = d[i * 4 + 2];
			}
			var xsP = m.session.run({ image: new ort.Tensor("float32", f, [1, 3, 224, 224]) }).then(function(out) {
				var pr = out[m.session.outputNames[0]].data; // probabilities, order [NSFL, NSFW, SFW]
				return { nsfw: pr[1], gore: pr[0] };
			});
			var njP = m.nsfw.classify(c).then(function(preds) { // classes Neutral/Drawing/Sexy/Hentai/Porn
				var o = {};
				for (var j = 0; j < preds.length; j++) { o[preds[j].className] = preds[j].probability; }
				return (o.Porn || 0) + (o.Hentai || 0); // nsfwjs's nsfw signal
			});
			return Promise.all([xsP, njP]).then(function(a) {
				return { nsfw: Math.max(a[0].nsfw, a[1]), gore: a[0].gore };
			});
		});
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

	// evenly-spaced frame indices, at most MAX_FRAMES of them (ascending)
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

	// a "producer" is a function returning a Promise of a 224x224 canvas for one sampled frame.

	// gif: decode + composite frames locally (omggif) so we never re-fetch. producers are called in
	// ascending page order, so we blit frames incrementally into a shared buffer.
	function gifProducers(bytes) {
		var reader = new GifReader(bytes);
		var W = reader.width, H = reader.height;
		var pages = pickPages(reader.numFrames());
		var full = document.createElement("canvas");
		full.width = W; full.height = H;
		var fctx = full.getContext("2d");
		var buf = new Uint8Array(W * H * 4), cursor = 0, prev = null;

		// a frame's disposal applies *before the next frame* is composited: 2 = clear its rect back to
		// transparent, 3 = restore the buffer to how it looked before the frame. without this, patched
		// frames accumulate stale pixels and the composite is garbage.
		function dispose(info) {
			if (info.disposal === 2) {
				for (var yy = 0; yy < info.height; yy++) {
					var start = ((info.y + yy) * W + info.x) * 4;
					for (var xx = 0; xx < info.width * 4; xx++) { buf[start + xx] = 0; }
				}
			} else if (info.disposal === 3 && info.snapshot) {
				buf.set(info.snapshot);
			}
		}

		return pages.map(function(pg) {
			return function() {
				while (cursor <= pg) { // producers run in ascending page order, so this only moves forward
					if (prev) { dispose(prev); prev = null; }
					var info = reader.frameInfo(cursor);
					if (info.disposal === 3) { info.snapshot = buf.slice(0); }
					reader.decodeAndBlitFrameRGBA(cursor, buf);
					prev = info; // dispose it before the next frame, not before capturing this one
					cursor++;
				}
				var id = fctx.createImageData(W, H);
				id.data.set(buf);
				fctx.putImageData(id, 0, 0);
				return Promise.resolve(to224(full));
			};
		});
	}

	// single still image (or a format we can't sample): score it straight from the fetched bytes
	function stillProducer(buf) {
		return function() {
			var u = URL.createObjectURL(new Blob([buf])); // same-origin blob -> canvas is readable
			return loadImg(u).then(function(img) { var c = to224(img); URL.revokeObjectURL(u); return c; });
		};
	}

	// run producers in order, keeping the worst (max nsfw, max gore); stop early once any frame is a
	// confident hide (it can't get worse than that). a producer/scoring failure just skips that frame.
	function scoreFrames(producers, finish) {
		var idx = 0, any = false, worstNsfw = -1, worstGore = -1;
		function next() {
			if (idx >= producers.length) { finish(any ? worstNsfw : -1, any ? worstGore : -1); return; }
			producers[idx++]().then(scoreCanvas).then(function(r) {
				any = true;
				if (r.nsfw > worstNsfw) worstNsfw = r.nsfw;
				if (r.gore > worstGore) worstGore = r.gore;
				if (Math.max(worstNsfw, worstGore) >= HIDE) { finish(worstNsfw, worstGore); return; } // already hide
				next();
			}).catch(function() { next(); }); // this frame failed; try the rest
		}
		next();
	}

	// classify strictly one image at a time (busy gate) -- lets at most the two parallel inferences of
	// a single frame overlap, never a pile-up.
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

		// wait for the models before starting the give-up clock, so the one-time load (and time queued
		// behind other images) never counts against CLASSIFY_TIMEOUT -- it only bounds the work itself.
		getModels().then(function() {
			setTimeout(function() { finish(-1, -1); }, %d); // took too long -> unknown -> blur
			return fetch(url);
		}).then(function(r) {
			// bail if we didn't actually get an image (e.g. wsrv refused the domain -> 400 json, or a
			// url that resolves to an html page). no point decoding it -- report unknown so it blurs.
			var ct = r.headers.get("content-type") || "";
			if (!r.ok || ct.indexOf("image/") !== 0) { finish(-1, -1); return null; }
			return r.arrayBuffer();
		}).then(function(buf) {
			if (!buf) return; // wasn't an image; already finished above
			var bytes = new Uint8Array(buf), producers;
			var isGif = bytes.length >= 4 && bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46;
			var isWebp = bytes.length >= 12 && bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 &&
				bytes[3] === 0x46 && bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50;
			try {
				if (isGif) {
					producers = gifProducers(bytes); // decode frames locally, no per-frame refetch
				} else if (isWebp && countWebpFrames(bytes) > 1) {
					// animated webp: no local decoder on 86, so pull frames from wsrv's &page=
					var strip = url.replace("&n=-1", "");
					producers = pickPages(countWebpFrames(bytes)).map(function(pg) {
						return function() { return loadImg(strip + "&n=1&page=" + pg + "&output=png").then(to224); };
					});
				} else {
					producers = [ stillProducer(buf) ];
				}
			} catch (e) { producers = [ stillProducer(buf) ]; } // malformed gif etc -> just score it whole
			scoreFrames(producers, finish);
		}).catch(function() { finish(-1, -1); }); // fetch/decode failed -> unknown -> blur
	}

	// pick up the next queued image, but only if we aren't already classifying one
	function pump() {
		if (busy) return;
		NSFW.Next(function(id, url) {
			if (id > 0) { busy = true; classify(id, url); }
		});
	}

	// kick the model downloads off immediately so they're ready as early as possible, and tell lua
	// when they're loaded (or failed) so the per-image timeout can start counting only from then.
	if (typeof ort === "undefined" || typeof tf === "undefined" || typeof nsfwjs === "undefined" || typeof GifReader === "undefined") {
		NSFW.OnError();
	} else {
		getModels().then(function() { NSFW.OnReady(); pump(); }).catch(function() { NSFW.OnError(); });
	}
</script>
</body></html>]==]):format(ORT_SCRIPT_URL, TFJS_SCRIPT_URL, TFJS_WASM_SCRIPT_URL, NSFWJS_SCRIPT_URL, OMGGIF_SCRIPT_URL,
		MODEL_URL, ORT_DIST_URL, TFJS_WASM_DIR, NSFWJS_MODEL_URL, HIDE_THRESHOLD, CLASSIFY_TIMEOUT * 1000)
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

	-- if the models never load at all (e.g. the download wedges), don't leave images waiting forever
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
	-- the give-up timeout lives in the browser now (started once the models are loaded), so it doesn't
	-- count the model download; the model-load watchdog above covers the models never loading at all.
end

-- synchronous peek at a cached verdict (nil = not classified yet)
function EasyChat.GetImageVerdict(url)
	return verdicts[url]
end
