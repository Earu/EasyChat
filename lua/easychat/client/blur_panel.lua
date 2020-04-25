local surface_SetMaterial = _G.surface.SetMaterial
local surface_SetDrawColor = _G.surface.SetDrawColor
local surface_DrawTexturedRect = _G.surface.DrawTexturedRect
local surface_DrawRect = _G.surface.DrawRect
local surface_DrawOutlinedRect = _G.surface.DrawOutlinedRect

local render_SetScissorRect = _G.render.SetScissorRect
local render_UpdateScreenEffectTexture = _G.render.UpdateScreenEffectTexture

local ScrW, ScrH = _G.ScrW, _G.ScrH

local blur = Material("pp/blurscreen")
local function blur_rect(x, y, w, h, layers, quality)
    surface_SetMaterial(blur)
    surface_SetDrawColor(255, 255, 255)

	render_SetScissorRect(x, y, x + w, y + h, true)
        for i = 1, layers do
            blur:SetFloat("$blur", (i / layers) * quality)
            blur:Recompute()

            render_UpdateScreenEffectTexture()
            surface_DrawTexturedRect(0, 0, ScrW(), ScrH())
        end
    render_SetScissorRect(0, 0, 0, 0, false)
end

-- we cant use weak keys here because gmod crashes when it calls IsValid when a key gets gcd
local blur_panels = {}
hook.Add("HUDPaint", "EasyChatBlur", function()
    for panel, data in pairs(blur_panels) do
        if not IsValid(panel) then
            blur_panels[panel] = nil
        elseif panel:IsVisible() and EasyChat.OutlayColor.a < 255 then
            local x, y, w, h = panel:GetBounds()
            blur_rect(x + data.OffsetX, y + data.OffsetY, w + data.OffsetW, h + data.OffsetH, 10, 2)
        end
    end
end)

function EasyChat.BlurPanel(panel, offset_x, offset_y, offset_w, offset_h)
    blur_panels[panel] = { OffsetX = offset_x, OffsetY = offset_y, OffsetW = offset_w, OffsetH = offset_h }
end