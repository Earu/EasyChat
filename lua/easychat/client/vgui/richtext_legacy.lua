local PANEL = {}

function PANEL:Init()
	local last_color = self:GetFGColor()
	local old_insert_color_change = self.InsertColorChange
	self.InsertColorChange = function(self, r, g, b, a)
		last_color = istable(r) and Color(r.r, r.g, r.b) or Color(r, g, b)
		old_insert_color_change(self, last_color.r, last_color.g, last_color.b, last_color.a)
	end

	self.GetLastColorChange = function(self) return last_color end

	local old_is_hovered = self.IsHovered
	self.IsHovered = function(self)
		return old_is_hovered(self) or self:IsChildHovered()
	end

	--[[
		Below are hacks to determine whether a clickable segment of text is being hovered or not
	]]--
	local last_value
	local old_insert_clickable_text_start = self.InsertClickableTextStart
	local old_insert_clickable_text_end = self.InsertClickableTextEnd
	self.InsertClickableTextStart = function(self, value)
		last_value = value
		old_insert_clickable_text_start(self, value)
	end

	local cur_id = 0
	self.InsertClickableTextEnd = function(self)
		local pre_count = #self:GetChildren()
		old_insert_clickable_text_end(self)

		local signal_value = last_value
		local timer_name = "ECLegacyRichTextHoverHack_" .. cur_id
		timer.Create(timer_name, 0.1, 0, function()
			if not IsValid(self) then
				timer.Remove(timer_name)
				return
			end

			local children = self:GetChildren()
			local count = #children
			if pre_count ~= count then
				local last = children[#children]

				local last_hover = false
				local rt = self
				function last:Think()
					local hover_state = self:IsHovered()
					if last_hover ~= hover_state then
						last_hover = hover_state
						rt:OnTextHover(signal_value, hover_state)
					end
				end

				timer.Remove(timer_name)
			end
		end)

		cur_id = cur_id + 1
	end
end

-- compat for RichTextX
function PANEL:AppendImageURL(url)
end

-- for overrides
function PANEL:OnTextHover(text_value, is_hover)
end

vgui.Register("RichTextLegacy", PANEL, "RichText")