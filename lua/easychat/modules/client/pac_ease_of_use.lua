if not _G.pac and _G.pace and _G.pacx then return "PAC3 Ease of Use" end

local pac_is_opened = false

hook.Add("pace_OnToggleFocus", "chathud", function()
	pac_is_opened = _G.pace.Active and not _G.pace.IsFocused()
end)

hook.Add("pace_OnOpenEditor", "chathud", function()
	pac_is_opened = true
end)

hook.Add("pace_OnCloseEditor", "chathud", function()
	pac_is_opened = false
end)

local HUD_FOLLOW = GetConVar("easychat_hud_follow")
hook.Add("ECHUDBoundsUpdate", "", function(x, y, w, h)
	if HUD_FOLLOW:GetBool() then return end
	if not pac_is_opened then return end

	local pac_x, _, pac_w, _ = pace.Editor:GetBounds()
	if pac_x + pac_w + w > ScrW() then
		return pac_x - w - 15, y, w, h
	end

	return pac_x + pac_w + 15, y, w, h
end)

return "PAC3 Ease of Use"