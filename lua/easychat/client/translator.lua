if util.IsBinaryModuleInstalled("ollama") and not _G.Ollama then
	require("ollama")
	_G.Ollama.SetConfig("http://localhost:11434", 60)
end

local translator = {}
local language_lookup = {
	["Automatic"] = "auto",

	["Afrikaans"] = "af", ["Irish"] = "ga", ["Albanian"] = "sq", ["Italian"] = "it", ["Arabic"] = "ar", ["Japanese"] = "ja",
	["Azerbaijani"] = "az", ["Kannada"] = "kn", ["Basque"] = "eu", ["Korean"] = "ko", ["Bengali"] = "bn", ["Latin"] = "la",
	["Belarusian"] = "be", ["Latvian"] = "lv", ["Bulgarian"] =	"bg", ["Lithuanian"] = "lt", ["Catalan"] = "ca",
	["Macedonian"] = "mk", ["Chinese Simplified"] = "zh-CN", ["Malay"] =	"ms", ["Chinese Traditional"] = "zh-TW", ["Maltese"] = "mt",
	["Croatian"] = "hr", ["Norwegian"] = "no", ["Czech"] = "cs", ["Persian"] = "fa", ["Danish"] = "da", ["Polish"] = "pl", ["Dutch"] = "nl",
	["Portuguese"] = "pt", ["English"] = "en", ["Romanian"] = "ro", ["Esperanto"] =	"eo", ["Russian"] = "ru", ["Estonian"] = "et", ["Serbian"] = "sr",
	["Filipino"] = "tl", ["Slovak"] = "sk", ["Finnish"] = "fi", ["Slovenian"] =	"sl", ["French"] = "fr", ["Spanish"] = "es", ["Galician"] = "gl",
	["Swahili"] = "sw", ["Georgian"] = "ka", ["Swedish"] = "sv", ["German"] = "de", ["Tamil"] =	"ta", ["Greek"] = "el", ["Telugu"] = "te",
	["Gujarati"] = "gu", ["Thai"] = "th", ["Haitian Creole"] = "ht", ["Turkish"] = "tr", ["Hebrew"] = "iw", ["Ukrainian"] =	"uk", ["Hindi"] = "hi",
	["Urdu"] = "ur", ["Hungarian"] = "hu", ["Vietnamese"] = "vi", ["Icelandic"] = "is", ["Welsh"] = "cy", ["Indonesian"] = "id", ["Yiddish"] = "yi",
}

local reverse_language_lookup = {}
for lang_name, country_code in pairs(language_lookup) do
	reverse_language_lookup[country_code] = lang_name
end

-- Extract translated text from JSON response
local function extract_translation_from_json(response)
	-- Try to find JSON in the response
	local json_start = response:find("{") or 1
	local json_end = response:find("}", json_start) or #response

	local json_str = response:sub(json_start, json_end)
	local success, json_data = pcall(util.JSONToTable, json_str)

	if success and json_data and json_data.translation and json_data.source_language then
		return json_data.translation:Trim(), json_data.source_language:Trim():lower()
	end

	return nil
end

function translator:Translate(text, source_lang, target_lang, on_finish, retries)
	-- Check if Ollama is available
	if not util.IsBinaryModuleInstalled("ollama") then
		on_finish(false)
		return
	end

	-- If Ollama is not loaded, load it
	if util.IsBinaryModuleInstalled("ollama") and not _G.Ollama then
		require("ollama")
		_G.Ollama.SetConfig("http://localhost:11434", 60)
	end

	if not _G.Ollama.IsRunning() then
		on_finish(false)
		return
	end

	-- Validate parameters
	if not text or text == "" or not reverse_language_lookup[source_lang] or not reverse_language_lookup[target_lang] then
		on_finish(false)
		return
	end

	-- Build translation prompt with JSON structure request
	local target_language = reverse_language_lookup[target_lang]
	local source_language = reverse_language_lookup[source_lang]

	local prompt
	if source_lang == "auto" then
		prompt = string.format([[Translate the following text to %s. Respond with ONLY a JSON object in this exact format:
{"translation": "your translated text here", "source_language": "the original language of the text (if unknown, use 'unknown')"}

Text to translate: %s]], target_language, text)
	else
		prompt = string.format([[Translate the following text from %s to %s. Respond with ONLY a JSON object in this exact format:
{"translation": "your translated text here", "source_language": "the original language of the text (if unknown, use 'unknown')"}

Text to translate: %s]], source_language, target_language, text)
	end

	retries = retries or 0

	_G.Ollama.IsModelAvailable("gemma3", function(err, available)
		if err then
			on_finish(false)
			return
		end

		if not available then
			on_finish(false)
			return
		end

		-- Use Ollama to translate
		_G.Ollama.Generate("gemma3", prompt, nil, function(err, data)
			if err then
				on_finish(false)
				return
			end

			if not data or not data.response then
				on_finish(false)
				return
			end

			local translated_text, detected_language = extract_translation_from_json(data.response)
			if not translated_text or not detected_language then
				if retries < 3 then
					-- try again
					translator:Translate(text, source_lang, target_lang, on_finish, retries + 1)
				else
					on_finish(false)
				end
				return
			end

			if detected_language == target_language:lower() or detected_language == "unknown" then
				on_finish(false) -- dont translate if the language is the same
				return
			end

			on_finish(true, text, translated_text)
		end)
	end)
end

return translator