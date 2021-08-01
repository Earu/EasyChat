local function emoji_count(content, char)
	if not content then return 0 end

	local x = 0
	local pos = 1
	for i = 1, #content do
		local new_pos = content:find(char, pos, true)
		if not new_pos then
			break
		end

		pos = new_pos + 1
		x = x + 1
	end

	return x
end

local FOLDER = "easychat/emojis/steam"
file.CreateDir(FOLDER, "DATA")

local EMOTS = FOLDER .. "/steam_emoticons.txt"
local function parse_emote_file() end

local EMOTE_PACKAGE_URL = "https://raw.githubusercontent.com/Earu/EasyChat/master/external_data/steam_emoticons.txt"
http.Fetch(EMOTE_PACKAGE_URL, function(body, _, _, code)
	if not body or code ~= 200 then
		EasyChat.Print(true, "Steam emojis update failed")
		return
	end

	file.Write(EMOTS, body)
	local count = emoji_count(body, ",")
	EasyChat.Print(("Saved steam emojis lookup table with %d references to: %s"):format(count, EMOTS))
	parse_emote_file(body)
end, function(err)
	EasyChat.Print(true, err)
end)

local function material_data(mat)
	return Material("../data/" .. mat)
end

local UNCACHED = false
local PROCESSING = true

local cache = {}
parse_emote_file = function(EMOTICONS)
	local split_pattern = ","
	local start = 1
	local split_start, split_end = EMOTICONS:find(split_pattern, start, true)
	while split_start do
		cache[EMOTICONS:sub(start, split_start - 1)] = UNCACHED
		start = split_end + 1
		split_start, split_end = EMOTICONS:find(split_pattern, start, true)
	end

	cache[EMOTICONS:sub(start)] = UNCACHED
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

		local start2, _ = data:find([["]], ending + 64, true)
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
