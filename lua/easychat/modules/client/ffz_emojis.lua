local function material_data(mat)
	return Material("../data/" .. mat)
end

local UNCACHED = false
local PROCESSING = true

local cache = {}

local FOLDER = "easychat/emojis/ffz"
file.CreateDir(FOLDER, "DATA")

local LOOKUP_TABLE_URL = "https://api.frankerfacez.com/v1/set/global"
local lookup = {}
http.Fetch(LOOKUP_TABLE_URL, function(body)
	local tbl = util.JSONToTable(body)
	if not tbl then
		EasyChat.Print(true, "Could not get the lookup table for FFZ")
		return
	end

	for _, set in pairs(tbl.sets) do
		for _, v in pairs(set.emoticons) do
			local name = v.name
			lookup[name] = v.urls[4] and v.urls[4] or (v.urls[2] and v.urls[2] or v.urls[1])
			cache[name] = UNCACHED
		end
	end
end, function()
	EasyChat.Print(true, "Could not get the lookup table for FFZ")
end)

local function get_ffz_url(name)
	return "https:" .. lookup[name]
end

local function get_ffz(name)
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

		if mat and not mat:IsError() then
			c = mat
			cache[name] = c
			return c
		end
	end

	local url = get_ffz_url(name)

	local function fail(err, isvariant)
		EasyChat.Print(true, "Http fetch failed for", url, ": " .. tostring(err))

		-- bad hack
		if not isvariant then
			EasyChat.Print("Retrying without variant selector just in case...")
			http.Fetch(url:Replace("-fe0f.png",".png"), function(data, len, hdr, code)
				if code ~= 200 or len <= 222 then
					return fail(code)
				end

				file.Write(path, data)
				local mat = material_data(path)
				if not mat or mat:IsError() then
					file.Delete(path)
					return
				end

				cache[name] = mat
			end, function(e) fail(e, true) end)
		end
	end

	http.Fetch(url, function(data, len, hdr, code)
		if code ~= 200 or len <= 222 then
			return fail(code)
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

EasyChat.ChatHUD:RegisterEmoteProvider("ffz", get_ffz, 1)
EasyChat.AddEmoteLookupTable("ffz", cache)

return "FrankerFaceZ Global Emotes"