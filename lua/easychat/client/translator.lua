local translator = {}

if util.IsBinaryModuleInstalled("ollama") then
	require("ollama")

	-- Configure Ollama connection
	Ollama.SetConfig("http://localhost:11434", 60)
end

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

-- Returns the Levenshtein distance between the two given strings
-- Lower numbers are better
local function levenshtein(str1, str2)
	local len1 = #str1
	local len2 = #str2
	local matrix = {}
	local cost = 1
	local min = math.min

	-- quick cut-offs to save time
	if len1 == 0 then return len2 end
	if len2 == 0 then return len1 end
	if str1 == str2 then return 0 end

	-- initialise the base matrix values
	for i = 0, len1, 1 do
		  matrix[i] = {}
		  matrix[i][0] = i
	end

	for j = 0, len2, 1 do
		  matrix[0][j] = j
	end

	-- actual Levenshtein algorithm
	for i = 1, len1, 1 do
		  for j = 1, len2, 1 do
			if str1:byte(i) == str2:byte(j) then cost = 0 end
			matrix[i][j] = min(matrix[i-1][j] + 1, matrix[i][j-1] + 1, matrix[i-1][j-1] + cost)
		  end
	end

	-- return the last value - this is the Levenshtein distance
	return matrix[len1][len2]
end

-- Extract translated text from JSON response
local function extract_translation_from_json(response)
	-- Try to find JSON in the response
	local json_start = response:find("{")
	local json_end = response:find("}", json_start)
	
	if not json_start or not json_end then
		-- Fallback: look for JSON-like structure
		local translation = response:match('"translation"%s*:%s*"([^"]*)"')
		if translation then
			return translation
		end
		
		-- Last resort: return cleaned response
		return response:gsub("^%s*(.-)%s*$", "%1")
	end
	
	local json_str = response:sub(json_start, json_end)
	local success, json_data = pcall(util.JSONToTable, json_str)
	
	if success and json_data and json_data.translation then
		return json_data.translation
	end
	
	-- Fallback to basic pattern matching
	local translation = response:match('"translation"%s*:%s*"([^"]*)"')
	if translation then
		return translation
	end
	
	-- Last resort
	return response:gsub("^%s*(.-)%s*$", "%1")
end

function translator:Translate(text, source_lang, target_lang, on_finish)
	-- Check if Ollama is available
	if not util.IsBinaryModuleInstalled("ollama") or not Ollama or not Ollama.IsRunning() then
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
{"translation": "your translated text here"}

Text to translate: %s]], target_language, text)
	else
		prompt = string.format([[Translate the following text from %s to %s. Respond with ONLY a JSON object in this exact format:
{"translation": "your translated text here"}

Text to translate: %s]], source_language, target_language, text)
	end

	Ollama.IsModelAvailable("gemma3", function(err, available)	
		if err then
			on_finish(false)
			return
		end

		if not available then
			on_finish(false)
			return
		end

		-- Use Ollama to translate
		Ollama.Generate("gemma3", prompt, nil, function(err, data)
			if err then
				on_finish(false)
				return
			end

			if not data or not data.response then
				on_finish(false)
				return
			end

			local translated_text = extract_translation_from_json(data.response)
			
			-- Validate translation quality
			if not translated_text or translated_text == "" or levenshtein(text, translated_text) <= 2 then
				on_finish(false)
				return
			end
			
			on_finish(true, text, translated_text)
		end)
	end)
end

return translator