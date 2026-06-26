if not CLIENT then return end

local shown = false
hook.Add("ECSQLiteErrored", "EasyChat_SQLiteErrorDialog", function(msg)
	msg = tostring(msg or "")
	if not msg:find("database or disk is full") and not msg:find("database disk image is malfo") then return end
	if shown then return true end
	if not IsValid(LocalPlayer()) then return end -- should probably show error if any were encountered
	shown = true

	local frame = vgui.Create("DFrame")
	frame:SetSize(500, 230)
	frame:Center()
	frame:SetTitle(language.GetPhrase("system_error") .. ": "..language.GetPhrase("gameui_console_storagetoofulltitle")..' or File Corruption Detected')
	frame:SetDeleteOnClose(true)
	frame:MakePopup()

	local label = vgui.Create("DLabel", frame)
	label:SetPos(10, 35)
	label:SetSize(480, 150)
	label:SetText([[Your disk may be full or a file corruption has occured.

	If your disk is not actually full, close the game, 
	rename or remove GarrysMod/garrysmod/cl.db and restart the game.
	
	Error details:]]..tostring(msg))
	label:SetWrap(true)
	label:SetAutoStretchVertical(true)

	local close = vgui.Create("DButton", frame)
	close:SetPos(200, 195)
	close:SetSize(100, 25)
	close:SetText("OK")
	close.DoClick = function() frame:Close() end

	return true
end)
