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

hook.Add("HUDPaint", "pac_in_editor", function()
	for _, ply in ipairs(player.GetHumans()) do
		if ply ~= LocalPlayer() and ply:GetNW2Bool("pac_in_editor") then

			if ply.pac_editor_cam_pos then
				if not IsValid(ply.pac_editor_camera) then
					ply.pac_editor_camera = ClientsideModel("models/tools/camera/camera.mdl")

					-- if there's some server lag it's possible that it gets deleted or something apparently
					if IsValid(ply.pac_editor_camera) then
						ply.pac_editor_camera:SetModelScale(0.25,0)
						local ent = ply.pac_editor_camera
						ply:CallOnRemove("pac_editor_camera", function()
							SafeRemoveEntity(ent)
						end)
					end
				end

				local ent = ply.pac_editor_camera
				local dt = math.Clamp(FrameTime() * 5, 0.0001, 0.5)

				ent:SetPos(LerpVector(dt, ent:GetPos(), ply.pac_editor_cam_pos))
				ent:SetAngles(LerpAngle(dt, ent:GetAngles(), ply.pac_editor_cam_ang))

				local pos_3d = ent:GetPos()
				local dist = pos_3d:Distance(EyePos())

				if dist > 10 then
					local pos_2d = pos_3d:ToScreen()
					if pos_2d.visible then
						local alpha = math.Clamp(pos_3d:Distance(EyePos()) * -1 + 500, 0, 500) / 500
						if alpha > 0 then
							local mk = ec_markup.CachePlayer("PAC3", ply, function()
								return ec_markup.AdvancedParse(("%s's PAC3 camera"):format(ply:Nick()), {
									nick = true,
									default_font = "ChatFont",
									default_color = color_white,
									no_shadow = true,
								})
							end)

							surface.SetAlphaMultiplier(alpha)
							mk:Draw(pos_2d.x, pos_2d.y)
							surface.SetAlphaMultiplier(1)

							if not ply.pac_editor_part_pos:IsZero() then
								surface.SetDrawColor(255, 255, 255, alpha * 100)
								local endpos = ply.pac_editor_part_pos:ToScreen()
								if endpos.visible then
									surface.DrawLine(pos_2d.x, pos_2d.y, endpos.x, endpos.y)
								end
							end
						end
					end
				end
			end

			local pos_3d = ply:NearestPoint(ply:EyePos()) + Vector(0,0,5)
			local alpha = math.Clamp(pos_3d:Distance(EyePos()) * -1 + 500, 0, 500)/500
			if alpha > 0 then
				local pos_2d = pos_3d:ToScreen()
				draw.DrawText("In PAC3 Editor", "ChatFont", pos_2d.x, pos_2d.y, Color(255, 255, 255, alpha * 255), 1)
			end
		else
			if ply.pac_editor_camera then
				SafeRemoveEntity(ply.pac_editor_camera)
				ply.pac_editor_camera = nil
			end
		end
	end
end)

return "PAC3 Ease of Use"