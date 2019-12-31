local chathud = EasyChat.ChatHUD

local function count(a, n)
	local x = 0
	local pos = 1
	for i = 1, #a do
		local new_pos = a:find(n, pos, true)
		if not new_pos then
			break
		end

		pos = new_pos + 1
		x = x + 1
	end

	return x
end

local cache = {}

local EMOTE_URL = "https://g1cf.metastruct.net/opendata/public/emote_lzma.dat"
local EMOTES = "steam_emoticons.txt"
local UNCACHED = false
local PROCESSING = true

local function parse_emote_file(data)
	local in_split_pattern = ","
	local start = 1
	local split_start, split_end = data:find(in_split_pattern, start, true)
	while split_start do
		cache[data:sub(start, split_start - 1)] = UNCACHED
		start = split_end + 1
		split_start, split_end = data:find(in_split_pattern, start, true)
	end
	cache[data:sub(start)] = UNCACHED
end

http.Fetch(EMOTE_URL, function(dat, len, hdr, ret)
	if not dat or ret ~= 200 then
		ErrorNoHalt("steam emoticons update failed\n")
		return
	end

	local t = {}
	dat = util.Decompress(dat)

	file.Write(EMOTES, dat)
	local count = count(dat, ",")
	print(("Saved %d emoticons to %s"):format(count, EMOTES))
	parse_emote_file(dat)
end, function(err)
	ErrorNoHalt("[SteamEmots] " .. err .. "\n")
end, { Referer = "http://steam.tools/emoticons/" })

local FOLDER = "steam_emoticons_big"
file.CreateDir(FOLDER, "DATA")

local function material_data(mat)
	return Material("../data/" .. mat)
end

local BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64_decode(data)
	data = string.gsub(data, "[^" .. BASE64 .. "=]", "")
	return (data:gsub(".", function(x)
		if (x == "=") then return "" end
		local r, f = "", (BASE64:find(x) - 1)
		for i = 6, 1, -1 do
			r = r .. (f % 2^i - f % 2^(i-1) > 0 and "1" or "0")
		end

		return r
	end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
		if (#x ~= 8) then return "" end
		local c = 0
		for i=1, 8 do
			c = c + (x:sub(i, i) == "1" and 2^(8 - i) or 0)
		end

		return string.char(c)
	end))
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

		if not mat or mat:IsError() then
			Msg("[Emoticons] ")
			print("Material found, but is error: ", name, "redownloading")
		else
			c = mat
			cache[name] = c
			return c
		end
	end

	local url = "http://steamcommunity-a.akamaihd.net/economy/emoticonhover/" .. name
	local function fail(err)
		Msg("[Emoticons] ")
		print("Http fetch failed for", url, ": " .. tostring(err))
	end

	http.Fetch(url, function(data, len, hdr, code)
		if code ~= 200 or len <= 222 then return fail(code) end

		local start, ending = data:find([[src="data:image/png;base64,]], 1, true)
		if not data then return fail("ending") end

		local start2, ending2 = data:find([["]], ending + 64, true)
		if not start2 then return fail("start2") end

		data = data:sub(ending + 1, start2 - 1)
		if not data or data == "" then return fail("sub") end

		data = base64_decode(data)
		if not data or data == "" then return fail("Base64Decode") end

		file.Write(path,data)

		local mat = material_data(path)

		if not mat or mat:IsError() then
			Msg("[Emoticons] ")
			print("Downloaded material, but is error: ", name)
			return
		end

		cache[name] = mat

	end, fail)
end

local function steam_emote(name)
	local mat = get_steam_emote(name)

	if mat then return function()
		surface.SetMaterial(mat)
		return mat
	end end

	if mat == false then
		return function() end
	end

	return function()
		if not mat then
			mat = get_steam_emote(name)
			if not mat then
				surface.SetTexture(0)
				return
			end
		end

		surface.SetMaterial(mat)
		return mat
	end
end

local content = file.Read(EMOTES,"DATA")
if content then
	parse_emote_file(content)
end

local surface_DrawTexturedRect = surface.DrawTexturedRect
local draw_NoTexture = draw.NoTexture
--[[-----------------------------------------------------------------------------
	Steam Emote Component

	Displays steam emotes.
]]-------------------------------------------------------------------------------
local emote_part = {
	SetEmoteMaterial = function() draw.NoTexture() end
}

function emote_part:Ctor(str)
	local em_components = string.Explode("%s*,%s*", str, true)
	local name, size = em_components[1], em_components[2]
	self.Height = math.Clamp(tonumber(size) or draw.GetFontHeight(chathud.DefaultFont), 16, 128)
	self.SetEmoteMaterial = steam_emote(name)

	return self
end

function emote_part:ComputeSize()
	self.Size = { W = self.Height, H = self.Height }
end

function emote_part:LineBreak()
	local new_line = chathud:NewLine()
	new_line:PushComponent(self)
end

function emote_part:Draw()
	self.SetEmoteMaterial()
	surface_DrawTexturedRect(self.Pos.X, self.Pos.Y, self.Size.W, self.Size.H)
	draw_NoTexture()
end

chathud:RegisterPart("emote", emote_part, "%:([A-Za-z0-9_]+)%:", {
	"STEAM%_%d%:%d%:%d+"
})

return "Steam Emotes"