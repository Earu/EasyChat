local function material_data(mat)
	return Material("../data/" .. mat)
end

local UNCACHED = false
local PROCESSING = true

local cache = {}
local framerate_cache = {}

local FOLDER = "easychat/emojis/bttv"
file.CreateDir(FOLDER, "DATA")

local LOOKUP_TABLE_URL = "https://api.betterttv.net/2/emotes"
local lookup = {}
local lookup_gif = {}
http.Fetch(LOOKUP_TABLE_URL, function(body)
	local tbl = util.JSONToTable(body)
	if not tbl then
		EasyChat.Print(true, "Could not get the lookup table for BTTV")
		return
	end

	for _, v in ipairs(tbl.emotes) do
		local name = v.code:Replace(":","_")
		if v.imageType == "gif" then
			lookup_gif[name] = v.id
		else
			lookup[name] = v.id
		end
		cache[name] = UNCACHED
	end
end, function(err)
	EasyChat.Print(true, "Could not get the lookup table for BTTV")
end)

local function URLEncode(s)
	s = tostring(s)
	local new = ""

	for i = 1, #s do
		local c = s:sub(i, i)
		local b = c:byte()
		if (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or
			(b >= 48 and b <= 57) or
			c == "_" or c == "." or c == "~" then
			new = new .. c
		else
			new = new .. ("%%%X"):format(b)
		end
	end

	return new
end

local BTTV_CDN_URL = "https://cdn.betterttv.net/emote/%s/3x"
local GIFINFO_URL = "http://sprays.xerasin.com/gifinfo.php?url=%s"
local GIFTOVTF_URL = "http://sprays.xerasin.com/getimage2.php?url=%s&type=vtf"

local function gif_material(name, path)
	return CreateMaterial("ecemote_" .. name, "UnlitGeneric", {
		["$basetexture"] = "../data/" .. path,
		["$vertexcolor"] = 1,
		["$vertexalpha"] = 1,
		["$transparent"] = 1,
		["Proxies"] = {
			AnimatedTexture = {
				animatedtexturevar = "$basetexture",
				animatedtextureframenumvar = "$frame",
				animatedtextureframerate = framerate_cache[name] or 8,
			}
		},
	})
end

local function get_bttv_url(name)
	if lookup_gif[name] then
		http.Fetch(GIFINFO_URL:format(URLEncode(BTTV_CDN_URL:format(lookup_gif[name]))), function(data, len, hdr, http_code)
			if http_code ~= 200 or len <= 222 then
				return function(code)
					EasyChat.Print(true, "Could not get GIF framerate for ", name, ": " .. code)
				end
			end

			framerate_cache[name] = tonumber(data)
		end, function(err)
			EasyChat.Print(true, "Could not get GIF framerate for ", name, ": " .. err)
		end)
		return GIFTOVTF_URL:format(URLEncode(BTTV_CDN_URL:format(lookup_gif[name]) .. "?_=.gif"))
	else
		return BTTV_CDN_URL:format(lookup[name])
	end
end

local function get_bttv(name)
	if not lookup[name] and not lookup_gif[name] then
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
	local path2 = FOLDER .. "/" .. name .. ".vtf"

	local exists = file.Exists(path, "DATA")
	local exists2 = file.Exists(path2, "DATA")
	if exists then
		local mat = material_data(path)

		if mat and not mat:IsError() then
			c = mat
			cache[name] = c
			return c
		end
	elseif exists2 then
		local mat = gif_material(name, path2)

		if mat and not mat:IsError() then
			c = mat
			cache[name] = c
			return c
		end
	end

	local url = get_bttv_url(name)

	local function fail(err, isvariant)
		EasyChat.Print(true, "Http fetch failed for ", url, ": " .. tostring(err))
	end

	http.Fetch(url, function(data, len, hdr, code)
		if code ~= 200 or len <= 222 then
			return fail(code)
		end

		if url:EndsWith("&type=vtf") then
			file.Write(path2, data)
			local mat = gif_material(name, path2)
			if not mat or mat:IsError() then
				file.Delete(path2)
				return
			end

			cache[name] = mat
		else
			file.Write(path, data)
			local mat = material_data(path)
			if not mat or mat:IsError() then
				file.Delete(path)
				return
			end

			cache[name] = mat
		end
	end, fail)
end

EasyChat.ChatHUD:RegisterEmoteProvider("bttv", get_bttv)
EasyChat.AddEmoteLookupTable("bttv", cache)

return "BetterTTV Global Emotes"