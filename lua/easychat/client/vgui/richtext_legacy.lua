local PANEL = {}

function PANEL:Init()
	local last_color = self:GetFGColor()
	local old_insert_color_change = self.InsertColorChange
	self.InsertColorChange = function(self, r, g, b, a)
		last_color = istable(r) and Color(r.r, r.g, r.b) or Color(r, g, b)
		old_insert_color_change(self, last_color.r, last_color.g, last_color.b, last_color.a)
	end

	self.GetLastColorChange = function(self) return last_color end
end

-- compat for RichTextX
function PANEL:AppendImageURL(url)
end

-- compat for RichTextX
function PANEL:OnTextHover(text_value, is_hover)
end

vgui.Register("RichTextLegacy", PANEL, "RichText")