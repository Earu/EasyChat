local MIGRATIONS_DIRECTORY = "easychat/migrations"

if SERVER then
	for _, f in pairs((file.Find(MIGRATIONS_DIRECTORY .. "/*.lua", "LUA"))) do
		local file_path = ("%s/%s"):format(MIGRATIONS_DIRECTORY, f)
		AddCSLuaFile(file_path)
	end
end

-- for these to be ran in the correct order you must always specify a number in front of the file name
for _, f in pairs((file.Find(MIGRATIONS_DIRECTORY .. "/*.lua", "LUA"))) do
	local file_path = ("%s/%s"):format(MIGRATIONS_DIRECTORY, f)
	include(file_path)
end