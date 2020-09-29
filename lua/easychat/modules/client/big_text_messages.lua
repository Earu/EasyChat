local color_white = color_white

local function update_big_chat_font(default_font_data)
	local font_data

	if not default_font_data then
		font_data = table.Copy(surface.GetLuaFonts()[EasyChat.ChatHUD.DefaultFont:lower()])
	else
		font_data = table.Copy(default_font_data)
	end

	font_data.size = 30

	local shadow_font_data = table.Copy(font_data)
	shadow_font_data.blursize = 1
	shadow_font_data.size = 30

	surface.CreateFont("BigChatText", font_data)
	surface.CreateFont("ECHUDShadow_BigChatText", shadow_font_data)
end

update_big_chat_font()

hook.Add("ECHUDFontChanged", "EasyChatModuleBigChatText", update_big_chat_font)
hook.Add("OnPlayerChat", "EasyChatModuleBigChatText", function(ply, msg, is_team, is_dead, is_local)
	local match = msg:match("![!1]+$")
	if not match then return end
	if #match < 3 then return end

	local msg_components = {}
	if is_dead then
		EasyChat.AddDeadTag(msg_components)
	end

	if is_team then
		EasyChat.AddTeamTag(msg_components)
	end

	if is_local then
		EasyChat.AddLocalTag(msg_components)
	end

	EasyChat.AddNameTags(ply, msg_components)

	table.insert(msg_components, ply)
	table.insert(msg_components, color_white)
	table.insert(msg_components, ": <font=BigChatText>")
	table.insert(msg_components, msg)

	chat.AddText(unpack(msg_components))

	return true
end)

return "Big Chat Text"