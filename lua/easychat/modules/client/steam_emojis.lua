local function count(a, n)
	if not a then return 0 end

	local x = 0
	local pos = 1
	for i = 1, #a do
		local newpos = a:find(n, pos, true)
		if not newpos then
			break
		end

		pos = newpos + 1
		x = x + 1
	end

	return x
end

local FOLDER = "easychat/emojis/steam"
file.CreateDir(FOLDER, "DATA")

local EMOTS = FOLDER .. "/steam_emoticons.txt"
local function parse_emote_file() end

local url =	"http://g1.metastruct.net:20080/opendata/public/emote_lzma.dat"
http.Fetch(url, function(dat, len, hdr, ret)
	if not dat or ret ~= 200 then
		EasyChat.Print(true, "Steam emojis update failed")
		return
	end

	local t = {}
	dat = util.Decompress(dat)

	file.Write(EMOTS, dat)
	local count = count(dat, ",")
	EasyChat.Print(("Saved steam emojis lookup table with %d references to: %s"):format(count, EMOTS))
	parse_emote_file(dat)
end, function(err)
	EasyChat.Print(true, err)
end, {
	Referer = "http://steam.tools/emoticons/"
})

local function material_data(mat)
	return Material("../data/" .. mat)
end

local UNCACHED = false
local PROCESSING = true

local cache = {}

parse_emote_file = function(EMOTICONS)
	local inSplitPattern = ","
	local theStart = 1
	local theSplitStart, theSplitEnd = EMOTICONS:find(inSplitPattern, theStart, true)
	while theSplitStart do
		cache[EMOTICONS:sub(theStart, theSplitStart - 1)] = UNCACHED
		theStart = theSplitEnd + 1
		theSplitStart, theSplitEnd = EMOTICONS:find(inSplitPattern, theStart, true)
	end
	cache[EMOTICONS:sub(theStart)] = UNCACHED
end

local function get_steam_emote(name)
	local c = cache[name]
	if c then
		if c == true then return end
		return c
	else
		if c == nil then return false end
	end

	-- Otherwise download dat shit
	cache[name] = PROCESSING

	local path = FOLDER .. "/" .. name .. ".png"

	local exists = file.Exists(path, "DATA")
	if exists then
		local mat = material_data(path)
		if mat and not mat:IsError() then
			c = mat
			cache[name] = c
			return c
		end
	end

	local url = "http://steamcommunity-a.akamaihd.net/economy/emoticonhover/" .. name
	--local url = 'http://cdn.steamcommunity.com/economy/emoticon/'..name
	local function fail(err)
		EasyChat.Print(true, "Http fetch failed for", url, ": " .. tostring(err))
	end

	http.Fetch(url, function(data, len, hdr, code)
		if code ~= 200 or len <= 222 or not data then
			return fail(code)
		end

		local start, ending = data:find([[src="data:image/png;base64,]], 1, true)
		if not start then
			return fail("ending")
		end

		local start2, ending2 = data:find([["]], ending + 64, true)
		if not start2 then
			return fail("start2")
		end

		data = data:sub(ending + 1, start2 - 1)
		if not data or data == "" then
			return fail("sub")
		end

		data = EasyChat.DecodeBase64(data)
		if not data or data == "" then
			return fail("Base64Decode")
		end

		file.Write(path, data)
		local mat = material_data(path)
		if not mat or mat:IsError() then
			file.Delete(path)
			return
		end

		cache[name] = mat
	end, fail)
end

local content = file.Read(EMOTS, "DATA")
if content then
	parse_emote_file(content)
end

EasyChat.ChatHUD:RegisterEmoteProvider("steam", get_steam_emote)
EasyChat.AddEmoteLookupTable("steam", cache)

return "Steam Emojis"