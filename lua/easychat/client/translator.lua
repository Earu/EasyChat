local cached_translations = {}
local translator = {}

local EC_TRANSLATE_API_KEY = GetConVar("easychat_translate_api_key")

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

local valid_languages = {}
for _, country_code in pairs(language_lookup) do
	valid_languages[country_code] = true
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

function translator:Translate(text, source_lang, target_lang, on_finish)
	if not text or not valid_languages[source_lang] or not valid_languages[target_lang] or not EC_TRANSLATE_API_KEY:GetString():find("trnsl.1.1.") then
		on_finish(false)
		return
	end

	if cached_translations[text] and cached_translations[text][target_lang] then
		local translated_text = cached_translations[text][target_lang]
		if levenshtein(text, translated_text) > 2 then
			on_finish(true, text, translated_text)
		else
			on_finish(false)
		end

		return
	end

	local language = (source_lang ~= "auto" and source_lang .. "-" or "") .. target_lang
	local url_encoded_text = text:gsub("[^%w]", function(char) return ("%%%02X"):format(char:byte()) end)
	local request_url = ("https://translate.yandex.net/api/v1.5/tr.json/translate?key=%s&text=%s&lang=%s"):format(EC_TRANSLATE_API_KEY:GetString(), url_encoded_text, language)

	http.Fetch(request_url, function(body, size)
		local translated = util.JSONToTable(body)
		if not translated then
			on_finish(false)
			return
		end

		if translated.text and translated.text[1] then
			cached_translations[text] = cached_translations[text] or {}
			cached_translations[text][target_lang] = translated.text[1]
			if levenshtein(text,  translated.text[1]) > 2 then
				on_finish(true, text, translated.text[1])
			else
				on_finish(false)
			end
		else
			on_finish(false)
		end
	end, function(error)
		on_finish(false)
	end)
end

return translator