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

local CLASSIFY_TIMEOUT = 20 -- give up (and fail open) if the browser never answers

local panel -- lazily created hidden classifier browser
local queue = {} -- { { id, url }, ... } waiting to be picked up by the browser
local pending = {} -- url -> { cb, ... } callbacks waiting on a verdict
local id_to_url = {} -- classify id -> url
local verdicts = {} -- url -> verdict (false | "blur" | "hide"), cached
local id_counter = 0
local runtime_failed = false -- the classifier couldn't load; stop trying, just show images

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

	// classify strictly one image at a time -- concurrent wasm inferences spike memory enough to
	// crash chromium 86 (especially when several images pile up while the model is still loading)
	var busy = false;

	function classify(id, url) {
		var img = new Image();
		img.crossOrigin = "anonymous";

		function finish(nsfw, gore) {
			NSFW.Result(id, nsfw, gore);
			busy = false;
			pump(); // next one, if any
		}

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
					finish(pr[1], pr[0]); // nsfw, gore
				});
			}).catch(function() { finish(-1, -1); }); // any failure -> unknown
		};
		img.onerror = function() { finish(-1, -1); };
		img.src = url;
	}

	// pick up the next queued image, but only if we aren't already classifying one
	function pump() {
		if (busy) return;
		NSFW.Next(function(id, url) {
			if (id > 0) { busy = true; classify(id, url); }
		});
	}

	if (typeof ort !== "undefined") {
		NSFW.OnReady();
		pump(); // drain anything queued before the page finished loading
	} else {
		NSFW.OnError();
	}
</script>
</body></html>]==]):format(ORT_SCRIPT_URL, MODEL_URL, ORT_DIST_URL)
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

	panel:AddFunction("NSFW", "OnReady", function() end)

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

	timer.Simple(CLASSIFY_TIMEOUT, function()
		local waiters = pending[url]
		if not waiters then return end -- already answered

		pending[url] = nil
		verdicts[url] = "blur" -- never answered in time -> blur to be safe
		for _, waiter in ipairs(waiters) do waiter("blur") end
	end)
end

-- synchronous peek at a cached verdict (nil = not classified yet)
function EasyChat.GetImageVerdict(url)
	return verdicts[url]
end

return "NSFW Filter"
