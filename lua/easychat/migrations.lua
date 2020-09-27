local MIGRATIONS_DIRECTORY = "easychat/migrations"

local files = file.Find(MIGRATIONS_DIRECTORY .. "/*.lua", "LUA")
local migrations = {}
for _, f in pairs(files) do
	local file_path = ("%s/%s"):format(MIGRATIONS_DIRECTORY, f)
	local timestamp = tonumber(f:match("^(%d+)_"))
	if timestamp then
		table.insert(migrations, { timestamp, file_path })
	else
		local err = ("[ECMigrations] > migration \'%s\' did not have a timestamp and was discarded\n"):format(f)
		ErrorNoHalt(err)
	end
end

-- sort by timestamp
table.sort(migrations, function(a, b) return a[1] < b[1] end)

if SERVER then
	for _, migration in ipairs(migrations) do
		local timestamp, file_path = migration[1], migration[2]
		AddCSLuaFile(file_path)
		local cookie_name = ("EC_MIGRATION_%d"):format(timestamp)
		if not cookie.GetNumber(cookie_name) then
			print(("[ECMigrations - SV] > Running %s"):format(file_path))
			include(file_path)
			cookie.Set(cookie_name, "1")
		end
	end
end

if CLIENT then
	for _, migration in ipairs(migrations) do
		local timestamp, file_path = migration[1], migration[2]
		local cookie_name = ("EC_MIGRATION_%d"):format(timestamp)
		if not cookie.GetNumber(cookie_name) then
			print(("[ECMigrations - CL] > Running %s"):format(file_path))
			include(file_path)
			cookie.Set(cookie_name, "1")
		end
	end
end