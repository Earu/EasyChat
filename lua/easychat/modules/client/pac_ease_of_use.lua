if not _G.pac and _G.pace and _G.pacx then return "PAC3 Ease of Use" end

local pac_is_opened = false

local function request_invalidation()
	timer.Simple(0.5, function()
		if not EasyChat.ChatHUD then return end -- disabling in the meantime somehow?
		EasyChat.ChatHUD:InvalidateLayout()
	end)
end

hook.Add("pace_OnToggleFocus", "chathud", function()
	pac_is_opened = _G.pace.Active and not _G.pace.IsFocused()
	request_invalidation()
end)

hook.Add("pace_OnOpenEditor", "chathud", function()
	pac_is_opened = true
	request_invalidation()
end)

hook.Add("pace_OnCloseEditor", "chathud", function()
	pac_is_opened = false
	request_invalidation()
end)

local HUD_FOLLOW = GetConVar("easychat_hud_follow")
local last_pac_x, last_pac_w = 0, 0
hook.Add("ECHUDBoundsUpdate", "", function(x, y, w, h)
	if HUD_FOLLOW:GetBool() then return end
	if not pac_is_opened then return end

	local pac_x, _, pac_w, _ = pace.Editor:GetBounds()
	if pac_x + pac_w + w > ScrW() then
		return pac_x - w - 15, y, w, h
	end

	if last_pac_x ~= pac_x or last_pac_w ~= pac_w then
		last_pac_x, last_pac_w = pac_x, pac_w
		request_invalidation()
	end

	return pac_x + pac_w + 15, y, w, h
end)

return "PAC3 Ease of Use"