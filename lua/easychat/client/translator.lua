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

function translator:Translate(text, source_lang, target_lang, on_finish)
	local apiKey = EC_TRANSLATE_API_KEY:GetString()
	if not valid_languages[source_lang] or not valid_languages[target_lang] or not apiKey:find("trnsl.1.1.") then
		on_finish(false)
		return
	end

	if cached_translations[text] and cached_translations[text][target_lang] then
		on_finish(true, text, cached_translations[text][target_lang])
		return
	end

	text = text:gsub("[^%w]", function(char)
		return string.format("%%%02X", char:byte())
	end)

	local langStr = (source_lang ~= "auto" and source_lang.."-" or "")..target_lang
	local reqUrl = string.format("https://translate.yandex.net/api/v1.5/tr.json/translate?key=%s&text=%s&lang=%s", apiKey, text, langStr)

	http.Fetch(reqUrl, function(body, size)
		local translated = util.JSONToTable(body)

		if translated.text and translated.text[1] then
			cached_translations[text] = cached_translations[text] or {}
			cached_translations[text][target_lang] = translated.text[1]
			on_finish(true, text, translated.text[1])
		else
			on_finish(false)
		end
	end, function(error)
		on_finish(false)	
	end)
end

return translator