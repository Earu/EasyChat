if SERVER then AddCSLuaFile() return end

local EasyChat = _G.EasyChat or {}
_G.EasyChat = EasyChat

local ChatHistory = {}
EasyChat.ChatHistory = ChatHistory

local EC_HISTORY_MAX = CreateConVar("easychat_history_max", "200", FCVAR_ARCHIVE, "Max history messages per channel")
local function max_messages() return math.max(1, EC_HISTORY_MAX:GetInt()) end

local function query(sql_str)
	local res = sql.Query(sql_str)
	if res == false then
		local msg = tostring(sql.LastError())
		-- track sqlite error count and fall back to simple clientside prints
		ChatHistory._sqlite_error_count = (ChatHistory._sqlite_error_count or 0) + 1
		local use_print = ChatHistory._sqlite_error_count > 5
		if hook.Run("ECSQLiteErrored", msg) ~= true then
			if use_print then
				print("[EasyChat] SQL error: " .. msg .. "  Query: " .. tostring(sql_str))
			else
				ErrorNoHalt("[EasyChat] SQL error: " .. msg .. "\n  Query: " .. tostring(sql_str) .. "\n")
			end
		end
		return false, msg
	end
	-- reset error counter on success
	ChatHistory._sqlite_error_count = 0
	return true, res
end

local ok
ok, _ = query([[CREATE TABLE IF NOT EXISTS ec_channels (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	name TEXT NOT NULL UNIQUE
)]])
if not ok then
	ChatHistory.Available = false
	ChatHistory._error = "ec_channels table creation failed"
	return
end

ok, _ = query([[CREATE TABLE IF NOT EXISTS ec_history (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	channel_id INTEGER NOT NULL,
	data TEXT NOT NULL,
	created_at INTEGER NOT NULL
)]])
if not ok then
	ChatHistory.Available = false
	ChatHistory._error = "ec_history table creation failed"
	return
end

query("CREATE INDEX IF NOT EXISTS idx_ec_history_channel ON ec_history(channel_id)")

local CHANNEL_NAMES = {}
local CHANNEL_IDS = {}

for _, name in ipairs({ "global", "admin" }) do
	query(string.format("INSERT OR IGNORE INTO ec_channels (name) VALUES (%s)", sql.SQLStr(name)))
end

do
	local ok, rows = query("SELECT id, name FROM ec_channels")
	if ok and rows then
		for _, row in ipairs(rows) do
			local id = tonumber(row.id)
			local name = row.name
			CHANNEL_IDS[name] = id
			CHANNEL_NAMES[id] = name
		end
	end
end

ChatHistory.Available = true

-- Segment format:
--   { t = "c", r, g, b, a }    -- color
--   { t = "s", v = "text" }    -- string
--   { t = "p", s = "sid64", n = "nick" } -- player (stored by SteamID64)

local function ensure_channel_id(name)
	name = tostring(name)
	local id = CHANNEL_IDS[name]
	if id then return id end

	query(string.format("INSERT OR IGNORE INTO ec_channels (name) VALUES (%s)", sql.SQLStr(name)))

	local ok, rows = query(string.format("SELECT id FROM ec_channels WHERE name = %s", sql.SQLStr(name)))
	if not ok or not rows or not rows[1] then return nil end
	id = tonumber(rows[1].id)
	CHANNEL_IDS[name] = id
	CHANNEL_NAMES[id] = name
	return id
end

function ChatHistory.Save(channel, segments)
	if not channel or not segments or #segments == 0 then return end

	local json = util.TableToJSON(segments)
	if not json then return end

	local cid = ensure_channel_id(channel)
	if not cid then return end

	query(string.format(
		"INSERT INTO ec_history (channel_id, data, created_at) VALUES (%d, %s, %d)",
		cid, sql.SQLStr(json), os.time()
	))

	query(string.format(
		[[DELETE FROM ec_history WHERE channel_id = %d AND id NOT IN (
			SELECT id FROM ec_history WHERE channel_id = %d ORDER BY id DESC LIMIT %d
		)]],
		cid, cid, max_messages()
	))
end

function ChatHistory.Get(channel, limit)
	limit = limit or max_messages()
	local cid = CHANNEL_IDS[tostring(channel)]
	if not cid then return {} end

	local ok, rows = query(string.format(
		"SELECT id, data, created_at FROM ec_history WHERE channel_id = %d ORDER BY id ASC LIMIT %d",
		cid, limit
	))
	if not ok or not rows then return {} end

	local result = {}
	for _, row in ipairs(rows) do
		local segments = util.JSONToTable(row.data)
		if segments then
			table.insert(result, {
				id = tonumber(row.id),
				segments = segments,
				timestamp = tonumber(row.created_at)
			})
		end
	end
	return result
end

function ChatHistory.Clear(channel)
	if channel then
		local cid = CHANNEL_IDS[tostring(channel)]
		if cid then
			query(string.format("DELETE FROM ec_history WHERE channel_id = %d", cid))
		end
	else
		query("DELETE FROM ec_history")
	end
end

function ChatHistory.GetChannels()
	local ok, rows = query("SELECT DISTINCT channel_id FROM ec_history ORDER BY channel_id")
	if not ok or not rows then return {} end
	local channels = {}
	for _, row in ipairs(rows) do
		local name = CHANNEL_NAMES[tonumber(row.channel_id)]
		if name then
			table.insert(channels, name)
		end
	end
	return channels
end

function ChatHistory.Count(channel)
	local cid = CHANNEL_IDS[tostring(channel)]
	if not cid then return 0 end

	local ok, rows = query(string.format(
		"SELECT COUNT(*) as cnt FROM ec_history WHERE channel_id = %d",
		cid
	))
	if ok and rows and rows[1] then
		return tonumber(rows[1].cnt) or 0
	end
	return 0
end

function ChatHistory.Replay(channel, richtext)
	local history = ChatHistory.Get(channel)
	for _, entry in ipairs(history) do
		for _, seg in ipairs(entry.segments) do
			if seg.t == "c" then
				richtext:InsertColorChange(seg.r, seg.g, seg.b, seg.a or 255)
			elseif seg.t == "s" then
				richtext:AppendText(seg.v)
			elseif seg.t == "p" then
				local ply = seg.s and player.GetBySteamID64 and player.GetBySteamID64(seg.s)
				if IsValid(ply) then
					local tc = team.GetColor(ply:Team())
					richtext:InsertColorChange(tc.r, tc.g, tc.b, tc.a)
					richtext:AppendText(ply:Nick())
				else
					richtext:AppendText(seg.n or "[Offline Player]")
				end
			end
		end
	end
	if #history > 0 then
		local last_ts = history[#history].timestamp
		local ts = last_ts and last_ts > 1000000000 and os.date("%Y-%m-%d %H:%M", last_ts) or "????-??-?? ??:??"

		richtext:InsertColorChange(80, 80, 80)
		richtext:AppendText("\n______________________________________\n")
		richtext:InsertColorChange(80, 160, 255)
		richtext:AppendText("    ")
		richtext:AppendText(language.GetPhrase("chat"))
		richtext:AppendText(" ")
		richtext:AppendText(language.GetPhrase("history"))
		richtext:AppendText(": ")
		richtext:AppendText(ts)
		richtext:AppendText("\n")
		richtext:InsertColorChange(80, 80, 80)
		richtext:AppendText("______________________________________\n\n")
	end
end

concommand.Add("easychat_history_clear", function()
	ChatHistory.Clear()
	print("[EasyChat History] All history cleared")
end)

concommand.Add("easychat_history_debug", function()
	if not ChatHistory.Available then
		print("[EasyChat History] SQLite not available")
		return
	end

	local channels = ChatHistory.GetChannels()
	if #channels == 0 then
		print("[EasyChat History] No history found")
		return
	end

	print("[EasyChat History] Channels: " .. #channels)
	for _, ch in ipairs(channels) do
		local entries = ChatHistory.Get(ch, 500)
		print(string.format("  [%s] %d entries", ch, #entries))
		for _, e in ipairs(entries) do
			local time_str = os.date("%Y-%m-%d %H:%M:%S", e.timestamp)
			local seg_summary = {}
			for _, seg in ipairs(e.segments) do
				if seg.t == "c" then
					table.insert(seg_summary, string.format("Color(%d,%d,%d)", seg.r, seg.g, seg.b))
				elseif seg.t == "s" then
					local v = seg.v:gsub("\n", "\\n"):sub(1, 60)
					table.insert(seg_summary, string.format("%q", v))
				elseif seg.t == "p" then
					table.insert(seg_summary, string.format("Player(%s)", seg.n or seg.s))
				end
			end
			print(string.format("    #%d [%s] %s", e.id, time_str, table.concat(seg_summary, ", ")))
		end
	end
end)

return ChatHistory
