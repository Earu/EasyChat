local surface_SetMaterial = _G.surface.SetMaterial
local surface_SetDrawColor = _G.surface.SetDrawColor
local surface_DrawTexturedRect = _G.surface.DrawTexturedRect
local surface_DrawRect = _G.surface.DrawRect
local surface_DrawOutlinedRect = _G.surface.DrawOutlinedRect

local render_SetScissorRect = _G.render.SetScissorRect
local render_UpdateScreenEffectTexture = _G.render.UpdateScreenEffectTexture

local ScrW, ScrH = _G.ScrW, _G.ScrH

local blur = Material("pp/blurscreen")
return function(x, y, w, h, layers, quality)
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