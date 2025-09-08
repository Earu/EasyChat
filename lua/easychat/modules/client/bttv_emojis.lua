local function material_data(mat)
	return Material("../data/" .. mat)
end

local UNCACHED = false
local PROCESSING = true

local cache = {}
local framerate_cache = {}

local FOLDER = "easychat/emojis/bttv"
file.CreateDir(FOLDER, "DATA")

local LOOKUP_SHARED_TABLE_URL = "https://api.betterttv.net/3/emotes/shared/top?limit=100"
local LOOKUP_GLOBAL_TABLE_URL = "https://api.betterttv.net/3/cached/emotes/global"
local lookup = {}
local lookup_gif = {}

if file.Exists(FOLDER .. "/framerate.txt", "DATA") then
	framerate_cache = util.JSONToTable(file.Read(FOLDER .. "/framerate.txt", "DATA")) or {}
end


http.Fetch(LOOKUP_GLOBAL_TABLE_URL, function(body)
	local tbl = util.JSONToTable(body)
	if not tbl or #tbl == 0 then return end
	for _, emoteData in ipairs(tbl) do
		if emoteData.animated then
			lookup_gif[emoteData.code] = emoteData.id
		else
			lookup[emoteData.code] = emoteData.id
		end
		cache[emoteData.code] = UNCACHED
	end
end, function(err)
	EasyChat.Print(true, "Could not get the global lookup table for BTTV")
end)

local function fetchEmotes(depth, before)
	if depth > 25 then -- Fetch the top 25 pages of approx 100 emotes each, should be enough
		EasyChat.Print(("Loaded %d BTTV emote references"):format(table.Count(cache)))
		return
	end

	http.Fetch(LOOKUP_SHARED_TABLE_URL .. (before and ("&before=" .. before) or ""), function(body)
		local tbl = util.JSONToTable(body)
		if not tbl or #tbl == 0 then return end
		local lastID = nil
		for _, emote in ipairs(tbl) do
			local emoteData = emote.emote
			if emoteData.animated then
				lookup_gif[emoteData.code] = emoteData.id
			else
				lookup[emoteData.code] = emoteData.id
			end
			cache[emoteData.code] = UNCACHED
			lastID = emote.id
		end

		fetchEmotes(depth + 1, lastID)
	end, function(err)
		EasyChat.Print(true, "Could not get the lookup table for BTTV")
	end)
end

fetchEmotes(1, nil)
local BTTV_CDN_URL = "https://cdn.betterttv.net/emote/%s/3x"
local GIFTOVTF_URL = "https://sprays.xerasin.com/legacy/get"

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

local function get_bttv_url(name, callback)
	if lookup_gif[name] then
		local gif_url = BTTV_CDN_URL:format(lookup_gif[name])
		http.Post(GIFTOVTF_URL, { url = gif_url }, function(data, len, hdr, http_code)
			if http_code ~= 200 or not data or #data < 10 then
				EasyChat.Print(true, "Could not get GIF info for ", name, ": " .. tostring(http_code))
				return
			end

			local info = util.JSONToTable(data)
			if not info or info.status == 0 then
				timer.Simple(2, function()
					get_bttv_url(name, callback)
				end)
				return
			end

			if info.status < 0 then
				EasyChat.Print(true, "Error getting GIF info for ", name, " (", tostring(info.status), "): " .. tostring(info.status_text))
				return
			end

			framerate_cache[name] = tonumber(info.frame_rate) or 8
			file.Write(FOLDER .. "/framerate.txt", util.TableToJSON(framerate_cache))

			callback(info.url)
		end, function(err)
			EasyChat.Print(true, "Could not get GIF info for ", name, ": " .. err)
		end)
	else
		callback(BTTV_CDN_URL:format(lookup[name]))
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
		local function handleOldGif(url)
			local mat = gif_material(name, path2)
			if mat and not mat:IsError() then
				c = mat
				cache[name] = c
				return c
			end
		end
		if not framerate_cache[name] then
			get_bttv_url(name, handleOldGif)
			return
		end
		return handleOldGif()
	end

	local function fail(err, isvariant)
		EasyChat.Print(true, "Http fetch failed for ", name, ": " .. tostring(err))
	end

	get_bttv_url(name, function(url)

		if not url then
			return fail("No URL returned")
		end

		http.Fetch(url, function(data, len, hdr, code)
			if code ~= 200 or len <= 222 then
				return fail(code)
			end

			if url:EndsWith(".vtf") then
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
	end)
end

EasyChat.ChatHUD:RegisterEmoteProvider("bttv", get_bttv)
EasyChat.AddEmoteLookupTable("bttv", cache)

return "BetterTTV Global Emotes"