-- this is inspired off
-- https://github.com/meepen/gmodchatmod

local TAG = "EasyChatEngineChatHack"
local EC_ENABLED = GetConVar("easychat_enable")

local engine_panel
local is_chat_opened = false
local function hack_msg_send()
	local parent_panel = engine_panel:GetParent()
	local engine_chat = parent_panel:GetParent()
	local label = parent_panel:GetChildren()[1]
	--engine_panel:SetKeyboardInputEnabled(false) -- lets not do that lol

	local text_entry = parent_panel:Add("DTextEntry")
	text_entry:SetZPos(9999999)
	text_entry:SetFocusTopLevel(true)
	text_entry:SetFont("ChatFont")
	text_entry:SetTextColor(color_white)
	text_entry:SetUpdateOnType(true)
	EC_CHAT_HACK = text_entry

	local selection_color = Color(255, 0, 0, 127)
	function text_entry:Paint()
		self:DrawTextEntryText(EasyChat.TextColor, selection_color, EasyChat.TextColor)
	end

	hook.Add("Think", text_entry, function(self)
		if engine_panel:HasFocus() then
			engine_panel:KillFocus()
			self:RequestFocus()
		end

		self:SetPos(engine_panel:GetPos())
		self:SetSize(engine_panel:GetSize())
		self:SetVisible(is_chat_opened and not EC_ENABLED:GetBool())
	end)

	function text_entry:OnValueChange(text)
		hook.Run("ChatTextChanged", text)
	end

	function text_entry:OnTab()
		local text = self:GetText()
		if #text == 0 then return end

		local completion = hook.Run("OnChatTab", text)
		if completion then self:SetText(completion) end

		timer.Simple(0, function()
			self:SetCaretPos(#self:GetText())
			engine_panel:KillFocus()
			self:RequestFocus()
		end)
	end

	function text_entry:OnKeyCodeTyped(key_code)
		if key_code == KEY_TAB then
			self:OnTab()
			return true
		end

		if key_code == KEY_ESCAPE then
			self:SetText("")
			hook.Run("ChatTextChanged", "")
			chat.Close()
			return true
		end

		if key_code == KEY_ENTER or key_code == KEY_PAD_ENTER then
			local msg = EasyChat.ExtendedStringTrim(self:GetText())
			if #msg > 0 then
				local is_team = label:GetText():lower():match("team")
				EasyChat.SendGlobalMessage(msg, is_team, false)
				self:SetText("")
			end

			hook.Run("ChatTextChanged", "")
			chat.Close()
			return true
		end
	end
end

hook.Add("StartChat", TAG, function(is_team)
	is_chat_opened = true

	if EC_ENABLED:GetBool() then return end
	if IsValid(engine_panel) then return end

	hook.Add("Think", TAG, function()
		if IsValid(vgui.GetKeyboardFocus()) then
			engine_panel = vgui.GetKeyboardFocus()
			hack_msg_send()
			hook.Remove("Think", TAG)
		end
	end)
end)

hook.Add("FinishChat", TAG, function()
	is_chat_opened = false
end)