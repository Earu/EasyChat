local PANEL = {}

surface.CreateFont("EasyChatCompletionFont", {
	font = "Roboto",
	size = 16,
})

function PANEL:Init()
	self.PlaceholderColor = color_white
	self.LastKey = KEY_ENTER

	self:SetFont("EasyChatCompletionFont")
	self:SetUpdateOnType(true)
	self:SetMultiline(true)
end

function PANEL:OnTab() end

function PANEL:SetCompletionText(text)
	if not text or text:Trim() == "" then
		self.CompletionText = nil
	else
		self.CompletionText = text
	end
end

function PANEL:SetPlaceholderColor(col)
	self.PlaceholderColor = col
end

function PANEL:OnKeyCodeTyped(key_code)
	EasyChat.SetupHistory(self, key_code)
	EasyChat.UseRegisteredShortcuts(self, self.LastKey, code)

	if key_code == KEY_TAB then
		self:OnTab()
		return true
	elseif key_code == KEY_ENTER or key_code == KEY_PAD_ENTER then
		self:OnEnter()
	end

	self.LastKey = key_code
end

local surface_SetTextColor = _G.surface.SetTextColor
local surface_DrawOutlinedRect = _G.surface.DrawOutlinedRect
local surface_SetFont = _G.surface.SetFont
local surface_GetTextSize = _G.surface.GetTextSize
local surface_SetTextPos = _G.surface.SetTextPos
local surface_DrawText = _G.surface.DrawText
local string_format, string_find, string_sub = _G.string.format, _G.string.find, _G.string.sub

function PANEL:PaintOver(w, h)
	if not self.CompletionText then return end

	local cur_value = self:GetText()
	surface_SetTextColor(self.PlaceholderColor)
	surface_SetFont("EasyChatCompletionFont")
	local cur_text_w = surface_GetTextSize(cur_value)
	local start_pos, end_pos = string_find(self.CompletionText, cur_value, 1, true)
	if start_pos then
		local sub_completion = string_sub(self.CompletionText, end_pos + 1)
		surface_SetTextPos(cur_text_w + 3, 2)
		surface_DrawText(sub_completion)
	else
		local sub_completion = string_format("<< %s >>", self.CompletionText)
		surface_SetTextPos(cur_text_w + 15, 2)
		surface_DrawText(sub_completion)
	end
end

vgui.Register("TextEntryLegacy", PANEL, "DTextEntry")