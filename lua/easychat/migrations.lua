local MIGRATIONS_DIRECTORY = "easychat/migrations"

local files = (file.Find(MIGRATIONS_DIRECTORY .. "/*.lua", "LUA"))
local migrations = {}
for _, f in pairs(files) do
	local file_path = ("%s/%s"):format(MIGRATIONS_DIRECTORY, f)
	local timestamp = tonumber(f:match("^(%d+)_"))
	if timestamp then
		migrations[timestamp] = file_path
	else
		local err = ("[ECMigrations] > migration \'%s\' did not have a timestamp and was discarded"):format(f)
		ErrorNoHalt(err)
	end
end

table.sort(migrations)

if SERVER then
	for migration_timestamp, file_path in pairs(migrations) do
		AddCSLuaFile(file_path)
		local cookie_name = ("EC_MIGRATION_%d"):format(migration_timestamp)
		if not cookie.GetNumber(cookie_name) then
			print(("[ECMigrations - SV] > Running %s"):format(file_path))
			include(file_path)
			cookie.Set(cookie_name, "1")
		end
	end
end

if CLIENT then
	for migration_timestamp, file_path in pairs(migrations) do
		local cookie_name = ("EC_MIGRATION_%d"):format(migration_timestamp)
		if not cookie.GetNumber(cookie_name) then
			print(("[ECMigrations - CL] > Running %s"):format(file_path))
			include(file_path)
			cookie.Set(cookie_name, "1")
		end
	end
end