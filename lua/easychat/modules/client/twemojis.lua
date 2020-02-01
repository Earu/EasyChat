local function material_data(mat)
	return Material("../data/" .. mat)
end

local UNCACHED = false
local PROCESSING = true

local cache = {}

local FOLDER = "easychat/emojis/twemojis"
file.CreateDir(FOLDER, "DATA")

local LOOKUP_TABLE_URL = "https://gist.githubusercontent.com/Cynosphere/6aa8c1f37870e96796608a4ffc9d1ccb/raw/1ac67bc24a794d319011b712014f8ba6e4f26055/emojis.json"
local lookup = {}
http.Fetch(LOOKUP_TABLE_URL, function(body)
	local tbl = util.JSONToTable(body)
	for _, v in ipairs(tbl) do
		local name = v.name
		lookup[name] = v.codes:lower():Replace(" ", "-")
		cache[name] = UNCACHED
	end
end, function(err)
	Msg("[Emoticons] ")
	print("Could not get the lookup table for twemojis")
end)

local function get_twemoji_url(name)
	return "https://twemoji.maxcdn.com/v/12.1.4/72x72/" .. lookup[name] .. ".png"
end

local function get_twemoji(name)
	if not lookup[name] then
		return false
	end

	local c = cache[name]
	if c then
		if c == true then
			return
		end
		return c
	else
		if c == nil then
			return false
		end
	end

	-- Otherwise download dat shit
	cache[name] = PROCESSING

	local path = FOLDER .. "/" .. name .. ".png"

	local exists = file.Exists(path, "DATA")
	if exists then
		local mat = material_data(path)

		if not mat or mat:IsError() then
			Msg("[Emoticons] ")
			print("Material found, but is error: ", name, "redownloading")
		else
			c = mat
			cache[name] = c
			return c
		end
	end

	local url = get_twemoji_url(name)

	local function fail(err)
		Msg("[Emoticons] ")
		print("Http fetch failed for", url, ": " .. tostring(err))
	end

	http.Fetch(url, function(data, len, hdr, code)
		if code ~= 200 or len <= 222 then
			return fail(code)
		end

		file.Write(path, data)

		local mat = material_data(path)

		if not mat or mat:IsError() then
			Msg("[Emoticons] ")
			print("Downloaded material, but is error: ", name)
			return
		end

		cache[name] = mat
	end, fail)
end

EasyChat.ChatHUD:RegisterEmoteProvider("twemojis", get_twemoji, 1)

return "Twemojis"