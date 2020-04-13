local LOOKUP_URL = "https://gist.githubusercontent.com/Earu/c53daf7627c105d057a5a67b79471033/raw/0fbcafb3538af6663ae558c70b0b4be1f4e61e56/transliteration_lookup.json"
local LOOKUP_PATH = "easychat/transliteration_lookup.json"
local MAX_SUPPORTED_UNICODE = 0xFFFF -- gmod cannot render anything above this codepoint

local transliterator = {}

transliterator.Lookup = {}
transliterator.Ready = false

local function fail(err)
	EasyChat.Print(true, err)
	transliterator.Ready = false
end

local function load_lookup(json)
	local global_lookup = util.JSONToTable(json)
	transliterator.Lookup = global_lookup and global_lookup.characters or {}
	transliterator.Ready = true
end

if file.Exists(LOOKUP_PATH, "DATA") then
	local json = file.Read(LOOKUP_PATH, "DATA")
	load_lookup(json)
else
	http.Fetch(LOOKUP_URL, function(json, size, _, code)
		if code ~= 200 then
			fail("Could not fetch transliteration lookup: " .. ("HTTP CODE %d"):format(code))
			return
		end

		if size == 0 then
			fail("Transliteration lookup is empty?!")
			return
		end

		if not file.Exists("easychat", "DATA") then
			file.CreateDir("easychat")
		end

		file.Write(LOOKUP_PATH, json)
		load_lookup(json)
	end, function(err)
		fail("Could not fetch transliteration lookup: " .. err)
	end)
end

function transliterator:IsRenderable(input)
	for _, code_point in utf8.codes(input) do
		if code_point > MAX_SUPPORTED_UNICODE then
			return false
		end
	end

	return true
end

-- Goal is to transliterate a unicode string "𝕊𝕙𝕦𝕝𝕝" to an ascii string "Shull"
function transliterator:Transliterate(input)
	if not input then return "" end
	if #input == 0 then return "" end

	input = utf8.force(input)

	-- if no character is "special" just return the input
	if self:IsRenderable(input) then return input end
	if not self.Ready then return input end

	local output = ""
	for _, code_point in utf8.codes(input) do
		if code_point <= MAX_SUPPORTED_UNICODE then
			output = output .. utf8.char(code_point)
		else
			local high = bit.rshift(code_point, 8)
			local low = bit.band(code_point, 0xff)
			local transliteration = self.Lookup[high]
			if transliteration then
				output = output .. transliteration[low + 1]
			end
		end
	end

	return output
end

return transliterator