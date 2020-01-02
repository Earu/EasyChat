local chathud = EasyChat.ChatHUD

--[[-----------------------------------------------------------------------------
	Fetch Steam emotes
]]-------------------------------------------------------------------------------
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

local STEAM_CACHE = {}
local EMOTE_URL = "https://g1cf.metastruct.net/opendata/public/emote_lzma.dat"
local EMOTES = "steam_emoticons.txt"
local UNCACHED = false
local PROCESSING = true

local function parse_emote_file(data)
	local in_split_pattern = ","
	local start = 1
	local split_start, split_end = data:find(in_split_pattern, start, true)
	while split_start do
		STEAM_CACHE[data:sub(start, split_start - 1)] = UNCACHED
		start = split_end + 1
		split_start, split_end = data:find(in_split_pattern, start, true)
	end
	STEAM_CACHE[data:sub(start)] = UNCACHED
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

local STEAM_FOLDER = "steam_emoticons_big"
file.CreateDir(STEAM_FOLDER, "DATA")

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
	local c = STEAM_CACHE[name]
	if c then
		if c == true then return end
		return c
	else
		if c == nil then return false end
	end

	-- Otherwise download dat shit
	STEAM_CACHE[name] = PROCESSING

	local path = STEAM_FOLDER .. "/" .. name .. ".png"

	local exists = file.Exists(path, "DATA")
	if exists then
		local mat = material_data(path)

		if not mat or mat:IsError() then
			Msg("[Emoticons] ")
			print("Material found, but is error: ", name, "redownloading")
		else
			c = mat
			STEAM_CACHE[name] = c
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

		STEAM_CACHE[name] = mat

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

--[[-----------------------------------------------------------------------------
	Fetch Twemojis
]]-------------------------------------------------------------------------------

local TWEMOJI_CACHE = {}
local TWEMOJIS_FOLDER = "twemojis"
file.CreateDir(TWEMOJIS_FOLDER, "DATA")

local LOOKUP_TABLE_URL = "https://raw.githubusercontent.com/amio/emoji.json/master/emoji.json"
local lookup = {}
http.Fetch(LOOKUP_TABLE_URL, function(body)
	local tbl = util.JSONToTable(body)
	for _, v in ipairs(tbl) do
		lookup[string.Replace(v.name, " ", "_")] = string.Replace(string.lower(v.codes), " ", "_")
	end
end)

local function get_twemoji_url(name)
	return "https://twemoji.maxcdn.com/v/12.1.4/72x72/" .. lookup[name] .. ".png"
end

local function get_twemoji(name)
	if not lookup[name] then return false end

	local c = TWEMOJI_CACHE[name]
	if c then
		if c == true then return end
		return c
	else
		if c == nil then return false end
	end

	-- Otherwise download dat shit
	TWEMOJI_CACHE[name] = PROCESSING

	local path = TWEMOJIS_FOLDER .. "/" .. name .. ".png"

	local exists = file.Exists(path, "DATA")
	if exists then
		local mat = MaterialData(path)

		if not mat or mat:IsError() then
			Msg("[Emoticons] ")
			print("Material found, but is error: ", name, "redownloading")
		else
			c = mat
			TWEMOJI_CACHE[name] = c
			return c
		end
	end

	local url = get_twemoji_url(name)

	local function fail(err)
		Msg("[DiscordEmoticons] ")
		print("Http fetch failed for", url, ": " .. tostring(err))
	end

	http.Fetch(url, function(data, len, hdr, code)
		if code ~= 200 or len <= 222 then
			return fail(code)
		end

		file.Write(path,data)

		local mat = MaterialData(path)

		if not mat or mat:IsError() then
			Msg("[Emoticons] ")
			print("Downloaded material, but is error: ", name)
			return
		end

		TWEMOJI_CACHE[name] = mat

	end,fail)
end

local function twemoji(name)
	local mat = get_twemoji(name)

	if mat then return function()
		surface.SetMaterial(mat)
		return mat
	end end

	if mat == false then error("invalid emoticon") end

	return function()
		if not mat then
			mat = get_twemoji(name)
			if not mat then
				surface.SetTexture(0)
				return
			end
		end

		surface.SetMaterial(mat)
		return mat
	end
end

local surface_DrawTexturedRect = surface.DrawTexturedRect
local draw_NoTexture = draw.NoTexture
--[[-----------------------------------------------------------------------------
	Emote Component

	Displays emotes.
]]-------------------------------------------------------------------------------
local emote_part = {
	SetEmoteMaterial = function() draw_NoTexture() end,
	RealPos = { X = 0, Y = 0 }
}

function emote_part:Ctor(str)
	local em_components = string.Explode("%s*,%s*", str, true)
	local name, size = em_components[1], em_components[2]
	self.Height = math.Clamp(tonumber(size) or draw.GetFontHeight(chathud.DefaultFont), 16, 64)
	self:TryGetEmote(name)

	return self
end

function emote_part:TryGetEmote(name)
	local ret = get_twemoji(name)
	if ret ~= false then
		self.SetEmoteMaterial = twemoji(name)
	else
		ret = get_steam_emote(name)
		if ret ~= false then
			self.SetEmoteMaterial = steam_emote(name)
		else
			self.Invalid = true
		end
	end
end

function emote_part:ComputeSize()
	if self.Invalid then
		self.Size = { W = 0, H = 0 }
	else
		self.Size = { W = self.Height, H = self.Height }
	end
end

function emote_part:LineBreak()
	local new_line = chathud:NewLine()
	new_line:PushComponent(self)
end

local EC_HUD_SMOOTH = GetConVar("easychat_hud_smooth")
local smoothing_speed = 1000
function emote_part:ComputePos()
	if not EC_HUD_SMOOTH:GetBool() then
		self.RealPos.Y = self.Pos.Y
		return
	end

    if self.RealPos.Y ~= self.Pos.Y then
        if self.RealPos.Y > self.Pos.Y then
            local factor = math.EaseInOut((self.RealPos.Y - self.Pos.Y) / 100, 0.02, 0.02) * smoothing_speed * RealFrameTime()
            self.RealPos.Y = math.max(self.RealPos.Y - factor, self.Pos.Y)
        else
            local factor = math.EaseInOut((self.Pos.Y - self.RealPos.Y) / 100, 0.02, 0.02) * smoothing_speed * RealFrameTime()
            self.RealPos.Y = math.min(self.RealPos.Y + factor, self.Pos.Y)
        end
    end
end

function emote_part:GetDrawPos(ctx)
	return self.Pos.X + ctx.TextOffset.X, self.RealPos.Y + ctx.TextOffset.Y
end

function emote_part:PostLinePush()
    self.RealPos = table.Copy(self.Pos)
end

function emote_part:Draw(ctx)
	if self.Invalid then return end

    self:ComputePos()

    local x, y = self:GetDrawPos(ctx)

    ctx:CallPreTextDrawFunctions(x, y, self.Size.W, self.Size.H)

    self.SetEmoteMaterial()
	surface_DrawTexturedRect(x, y, self.Size.W, self.Size.H)
    draw_NoTexture()

    ctx:CallPostTextDrawFunctions(x, y, self.Size.W, self.Size.H)
end

chathud:RegisterPart("emote", emote_part, "%:([A-Za-z0-9_]+)%:", {
	"STEAM%_%d%:%d%:%d+", -- steamids
	"%d%d:%d%d:%d%d" -- timestamps
})

return "Chat Emotes"