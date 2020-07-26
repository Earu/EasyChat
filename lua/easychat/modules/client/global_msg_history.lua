local HISTORY_PATH = "easychat/msg_history.txt"
local function save_history()
	if not file.Exists("easychat", "DATA") then
		file.CreateDir("easychat")
	end

	if not IsValid(EasyChat.GUI.TextEntry) then return end

	local history_length = #EasyChat.GUI.TextEntry.History
	local start_pos = history_length > 100 and history_length - 100 or 1
	local contents = table.concat(EasyChat.GUI.TextEntry.History, "\n", start_pos, history_length)
	file.Write(HISTORY_PATH, contents)
end

hook.Add("ECPreDestroy", "EasyChatModuleMsgHistory", save_history)
hook.Add("ShutDown", "EasyChatModuleMsgHistory", save_history)

hook.Add("ECInitialized", "EasyChatModuleMsgHistory", function()
	if not IsValid(EasyChat.GUI.TextEntry) then return end
	local contents = file.Read(HISTORY_PATH, "DATA") or ""
	EasyChat.GUI.TextEntry.History = contents:Split("\n")
	EasyChat.GUI.TextEntry.HistoryPos = 0
end)

return "Message History"