-- CREDITS TO PYTHON1320
if not CLIENT then return end

--gotta catch 'em all or very broken stuff
local fonts = {}
local created = {}
local processed = {}
local bad_fonts = {}
local surface_CreateFont = surface.CreateFont
local surface_SetFont = surface.SetFont

local blacklisted_fonts = {
	defaultbold = true,
	trebuchet18 = true,
	["clear sans medium"] = true, -- might be real
	hudnumber = true,
	tablarge = true,
	defaultsmall = true,
	debugfixed = true,
	tacoma = true,
	dermalarge = true,
	trebuchet24 = true,
	trebuchet = true,
	consoletext = true,
	dermadefault = true,
	default = true,
	monospace = true -- might be real?
}

function surface.CreateFont(font_name, font_data)
	font_name = tostring(font_name)

	if font_data.font and (blacklisted_fonts[font_data.font:lower()] or #font_data.font > 31) then
		local font = font_data.font
		font_data.font = nil
		bad_fonts[#bad_fonts + 1] = { font, debug.getinfo(2) }
	end

	font_data.extended = true -- why would you want ascii only?

	local result = surface_CreateFont(font_name, font_data)
	local font_name_lower = font_name:lower()
	created[font_name_lower] = false
	fonts[font_name_lower] = font_data
	font_data.name = font_name

	for k, _ in pairs(processed) do
		if tostring(k):lower() == font_name_lower then
			processed[k] = nil
		end
	end

	return result
end

local function process_font(font_name)
	if processed[font_name] == nil then
		processed[font_name] = true

		if not created[font_name:lower()] and fonts[font_name:lower()] then
			created[font_name:lower()] = true
		end
	end
end

function surface.SetFont(font_name)
	process_font(font_name)
	return surface_SetFont(font_name)
end

local META = FindMetaTable("Panel")
local SetFontInternal = META.SetFontInternal
if SetFontInternal then
	META.SetFontInternal = function(self, font_name)
		process_font(font_name)
		return SetFontInternal(self, font_name)
	end
end

function surface.GetLuaFonts()
	return fonts
end