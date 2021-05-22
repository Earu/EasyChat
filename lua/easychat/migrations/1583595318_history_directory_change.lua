if SERVER then return end

local OLD_PATH = "easychat"
local NEW_PATH = "easychat/history"

local files = (file.Find(("%s/*_history.txt"):format(OLD_PATH),"DATA"))
for _, f in pairs(files) do
	local old_file_path = ("%s/%s"):format(OLD_PATH, f)
	local new_file_path = ("%s/%s"):format(NEW_PATH, f)

	-- dont override file if it exists
	if not file.Exists(new_file_path, "DATA") then
		local content = file.Read(old_file_path, "DATA")
		file.Write(new_file_path, content)
	end

	file.Delete(old_file_path)
end