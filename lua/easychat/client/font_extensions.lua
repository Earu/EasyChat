-- CREDITS TO PYTHON1320
if not CLIENT then return end

--gotta catch 'em all or very broken stuff
local fonts = {}
local created = {}
local processed = {}
local badfonts = {}
local surface_CreateFont = surface.CreateFont
local surface_SetFont = surface.SetFont

local bad = {
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

function surface.CreateFont(fn, tbl)
	fn = tostring(fn)

	if tbl.font and bad[tbl.font:lower()] then
		local font = tbl.font
		tbl.font = nil
		badfonts[#badfonts + 1] = {font, debug.getinfo(2)}
	end

	local r = surface_CreateFont(fn, tbl)
	local fnl = fn:lower()
	created[fnl] = false
	fonts[fnl] = tbl
	tbl.name = fn

	for k, v in next, processed do
		if tostring(k):lower() == fnl then
			processed[k] = nil
		end
	end
	-- processed={} -- last measure?

	return r
end

local function proc(fn)
	if processed[fn] == nil then
		processed[fn] = true

		if not created[fn:lower()] and fonts[fn:lower()] then
			created[fn:lower()] = true
			--surface_CreateFont(fn,fonts[fn:lower()])
		end
	end
end

function surface.SetFont(fn)
	proc(fn)

	return surface_SetFont(fn)
end

local META = FindMetaTable("Panel")
local SetFontInternal = META.SetFontInternal
if SetFontInternal then
	META.SetFontInternal = function(self, fn)
		proc(fn)

		return SetFontInternal(self, fn)
	end
end

function surface.GetLuaFonts()
	return fonts
end