
local PLY = FindMetaTable("Player")
local TAG = "EasyChat"

local NET_BROADCAST_MSG = "EASY_CHAT_BROADCAST_MSG"
local NET_SEND_MSG = "EASY_CHAT_RECEIVE_MSG"
local NET_ADD_TEXT = "EASY_CHAT_ADD_TEXT"
local NET_SYNC_BLOCKED = "EASY_CHAT_SYNC_BLOCKED"
local NET_MSG_EMBED = "EASY_CHAT_MSG_EMBED"

local COLOR_PRINT_CHAT_TIME = Color(0, 161, 255)
local COLOR_PRINT_CHAT_NICK = Color(222, 222, 255)
local COLOR_PRINT_CHAT_MSG = Color(255, 255, 255)

local native = true
function EasyChat.IsCallingNativeHooks()
	return native
end

if SERVER then
	local msgc_native = _G._MsgC or _G.MsgC -- epoe compat

	util.AddNetworkString(NET_SEND_MSG)
	util.AddNetworkString(NET_BROADCAST_MSG)
	util.AddNetworkString(NET_ADD_TEXT)
	util.AddNetworkString(NET_SYNC_BLOCKED)
	util.AddNetworkString(NET_MSG_EMBED)

	local EC_RESOLVE_URLS = CreateConVar("easychat_resolve_urls", "1", FCVAR_ARCHIVE, "Let the server resolve posted urls (media/website metadata) and send embeds to clients")
	local RESOLVE_CACHE_TTL = 600
	local RESOLVE_MAX_BODY = 512 * 1024
	local RESOLVE_MAX_INFLIGHT = 8
	local FAVICON_MAX_BYTES = 48 * 1024
	local FAVICON_MAX_DIM = 128
	local FAVICON_MAX_CANDIDATES = 4

	local MEDIA_PROVIDER_HOSTS = {
		"tenor%.com", "giphy%.com", "gph%.is", "klipy%.co", "klipy%.com", "redgifs%.com",
	}

	local resolve_cache = {}
	local resolve_inflight = 0

	local function html_decode(str)
		if not str then return str end
		str = str:gsub("&#x(%x+);", function(hex) return utf8.char(tonumber(hex, 16) or 0xFFFD) end)
		str = str:gsub("&#(%d+);", function(dec) return utf8.char(tonumber(dec) or 0xFFFD) end)
		str = str:gsub("&quot;", "\""):gsub("&apos;", "'"):gsub("&#39;", "'")
			:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&")
		return str
	end

	local function get_tag_attr(tag, attr)
		return tag:match(attr .. "%s*=%s*\"([^\"]*)\"") or tag:match(attr .. "%s*=%s*'([^']*)'")
	end

	local function parse_page_meta(html)
		local meta = {}
		for tag in html:gmatch("<meta%s+([^>]-)/?>") do
			local key = get_tag_attr(tag, "property") or get_tag_attr(tag, "name")
			local content = get_tag_attr(tag, "content")
			if key and content and not meta[key:lower()] then
				meta[key:lower()] = html_decode(content)
			end
		end

		local title = html:match("<title[^>]*>(.-)</title>")
		if title then meta.__title = html_decode(title):Trim() end

		return meta
	end

	local function nonempty(str)
		str = isstring(str) and str:Trim() or nil
		return (str and str ~= "") and str or nil
	end

	local function ld_first_image(v)
		if isstring(v) then return v end
		if istable(v) then
			if isstring(v.url) then return v.url end
			if v["@list"] then return ld_first_image(v["@list"][1]) end
			if v[1] then return ld_first_image(v[1]) end
		end
		return nil
	end

	local function parse_ld_json(html)
		local out = {}
		for blob in html:gmatch("application/ld%+json[^>]*>(.-)</script>") do
			local ok, data = pcall(util.JSONToTable, blob)
			if ok and istable(data) then
				local nodes = data["@graph"] or (data[1] and data) or { data }
				for _, node in ipairs(nodes) do
					if istable(node) then
						out.title = out.title or nonempty(node.headline) or nonempty(node.name)
						out.description = out.description or nonempty(node.description) or nonempty(node.articleBody)
						out.image = out.image or ld_first_image(node.image)
						if istable(node.author) then out.author = out.author or nonempty(node.author.name) end
					end
				end
			end
		end
		return out
	end

	local function resolve_url(page_url, href)
		if href:find("^https?://") then return href end

		local scheme, host = page_url:match("^(https?)://([^/]+)")
		if not host then return nil end

		if href:find("^//") then return scheme .. ":" .. href end
		if href:find("^/") then return scheme .. "://" .. host .. href end

		local path = page_url:match("^https?://[^/]+(/[^?#]*)") or "/"
		local dir = path:gsub("[^/]*$", "")
		return scheme .. "://" .. host .. dir .. href
	end

	local function image_dims(bytes)
		if #bytes < 24 then return nil end

		if bytes:sub(1, 8) == "\137PNG\r\n\26\n" then
			local function u32(o) return bytes:byte(o) * 0x1000000 + bytes:byte(o + 1) * 0x10000 + bytes:byte(o + 2) * 0x100 + bytes:byte(o + 3) end
			return u32(17), u32(21)
		elseif bytes:sub(1, 3) == "GIF" then
			return bytes:byte(7) + bytes:byte(8) * 256, bytes:byte(9) + bytes:byte(10) * 256
		elseif bytes:sub(1, 4) == "\0\0\1\0" then -- .ico, first directory entry (0 means 256)
			local w, h = bytes:byte(7), bytes:byte(8)
			return w == 0 and 256 or w, h == 0 and 256 or h
		end

		return nil
	end

	local function fetch_favicon(page_url, html, cb)
		local scheme, host = page_url:match("^(https?)://([^/]+)")
		if not host then return cb(nil) end

		local candidates, seen = {}, {}
		local function add(url, dim, apple)
			if not url or seen[url] then return end
			seen[url] = true
			candidates[#candidates + 1] = { url = url, dim = dim, apple = apple }
		end

		for tag in html:gmatch("<link%s+([^>]->)") do
			local rel = (get_tag_attr(tag, "rel") or ""):lower()
			if rel:find("icon") then
				local href = get_tag_attr(tag, "href")
				if href then
					local sizes = get_tag_attr(tag, "sizes") or ""
					add(resolve_url(page_url, html_decode(href)), tonumber(sizes:match("(%d+)")), rel:find("apple") ~= nil)
				end
			end
		end
		add(scheme .. "://" .. host .. "/favicon.ico", nil, false)

		-- prefer real icons sized <= 128 (bigger is sharper), then unsized, avoid huge apple-touch icons
		local function score(c)
			local s = c.dim and (c.dim <= FAVICON_MAX_DIM and c.dim or -c.dim) or 40
			return c.apple and s - 200 or s
		end
		table.sort(candidates, function(a, b) return score(a) > score(b) end)

		local index = 0
		local function try_next()
			index = index + 1
			local c = candidates[index]
			if not c or index > FAVICON_MAX_CANDIDATES then return cb(nil) end

			http.Fetch(c.url, function(data, _, headers, code)
				if not data or #data == 0 or #data > FAVICON_MAX_BYTES
					or (code and (code < 200 or code >= 300))
				then
					return try_next()
				end

				local ct
				for k, v in pairs(headers or {}) do
					if k:lower() == "content-type" then ct = v:lower() break end
				end
				-- some sites answer /favicon.ico with an html 404 page
				if ct and not (ct:find("image") or ct:find("icon")) then return try_next() end

				local w, h = image_dims(data)
				if w and h and (w > FAVICON_MAX_DIM or h > FAVICON_MAX_DIM) then return try_next() end

				local compressed = util.Compress(data)
				if not compressed or #compressed > FAVICON_MAX_BYTES then return try_next() end

				cb({ mime = ct or "image/x-icon", data = compressed })
			end, try_next)
		end

		try_next()
	end

	local function build_embed(url, content_type, body)
		-- the resource itself is an image
		if content_type and content_type:find("^image/") then
			return { kind = "image", url = url }
		end

		-- only meta-scrape html-ish pages
		if content_type and not (content_type:find("text/html") or content_type:find("xhtml")) then
			return nil
		end

		local meta = parse_page_meta(body)
		local ld = parse_ld_json(body)

		-- prefer og/twitter tags, fall back to JSON-LD (schema.org) for anything missing.
		-- a page's real content image (og/ld) is preferred over a tiny twitter:image avatar.
		local title = nonempty(meta["og:title"]) or nonempty(meta["twitter:title"]) or ld.title or nonempty(meta.__title)
		local description = nonempty(meta["og:description"]) or nonempty(meta["twitter:description"]) or ld.description
		local image = nonempty(meta["og:image:secure_url"]) or nonempty(meta["og:image"]) or ld.image or nonempty(meta["twitter:image"])
		local site_name = nonempty(meta["og:site_name"]) or ld.author
		local og_type = meta["og:type"] or ""

		-- tumblr-style "Title - " leftovers where the site name is empty
		if title then title = title:gsub("%s+%-%s*$", "") end

		-- some sites (tumblr) prepend the title to the article body; drop the duplicate
		if title and description and description:sub(1, #title) == title then
			description = description:sub(#title + 1):Trim()
		end

		-- article bodies can be huge; keep the card compact
		if description and #description > 300 then
			description = description:sub(1, 300):gsub("%s+%S*$", "") .. "…"
		end

		local host = (url:match("^https?://([^/]+)") or ""):lower()
		local is_media_provider = false
		for _, provider in ipairs(MEDIA_PROVIDER_HOSTS) do
			if host:find(provider) then is_media_provider = true break end
		end

		-- gif/video providers: embed the media itself instead of a card
		if image and (is_media_provider or og_type:find("video") or og_type:find("gif")) then
			return { kind = "image", url = image, page_url = url }
		end

		if not (title or description or image) then return nil end

		-- website cards only carry text + a favicon (attached later); no content image
		return {
			kind = "link",
			url = url,
			page_url = url,
			title = title,
			description = description,
			site_name = site_name,
		}
	end

	local function is_private_host(host)
		host = host:gsub(":%d+$", ""):gsub("[%[%]]", ""):lower() -- strip port/ipv6 brackets
		if host == "localhost" or host == "127.0.0.1" or host == "::1" then return true end

		local a, b = host:match("^(%d+)%.(%d+)%.%d+%.%d+$")
		if a then
			a, b = tonumber(a), tonumber(b)
			if a == 0 or a == 10 or a == 127 then return true end
			if a == 169 and b == 254 then return true end -- link-local
			if a == 192 and b == 168 then return true end
			if a == 172 and b >= 16 and b <= 31 then return true end
			if a == 100 and b >= 64 and b <= 127 then return true end -- CGNAT
		end

		if host:find("^f[cde]") then return true end -- rough ipv6 fc00::/7 & fe80::/10
		return false
	end

	local function resolve_klipy(url, cb)
		local slug = url:match("klipy%.com/gifs/([%w%-]+)")
		if not slug then return cb(nil) end

		http.Fetch("https://api.klipy.com/api/v1/gifs/" .. slug, function(body, _, _, code)
			if code and code ~= 200 then return cb(nil) end

			local ok, data = pcall(util.JSONToTable, body)
			if not ok or not istable(data) or not istable(data.data) then return cb(nil) end

			local file = data.data.file or {}
			local function gif_of(size) return istable(size) and istable(size.gif) and size.gif.url or nil end
			local gif = gif_of(file.md) or gif_of(file.hd) or gif_of(file.sm) or gif_of(file.xs)
			if not gif then return cb(nil) end

			cb({ kind = "image", url = gif, page_url = url })
		end, function() cb(nil) end)
	end

	local PROVIDER_RESOLVERS = {
		{ pattern = "^https?://[%w%.]-klipy%.com/gifs/", resolve = resolve_klipy },
	}

	function EasyChat.ResolveURLEmbed(ply, url, cb)
		if EasyChat.IsDirectImageURL(url) then
			cb({ kind = "image", url = url })
			return
		end

		-- only ever touch http(s), never private/local hosts (best-effort SSRF guard)
		local scheme, host = url:match("^(%w+)://([^/]+)")
		if not host or (scheme ~= "http" and scheme ~= "https") then return end
		if is_private_host(host) then return end

		local cached = resolve_cache[url]
		if cached and (SysTime() - cached.time) < RESOLVE_CACHE_TTL then
			if cached.embed then cb(cached.embed) end
			return
		end

		if resolve_inflight >= RESOLVE_MAX_INFLIGHT then return end
		resolve_inflight = resolve_inflight + 1

		local function finish(embed)
			resolve_inflight = math.max(0, resolve_inflight - 1)
			resolve_cache[url] = { embed = embed or false, time = SysTime() }
			if embed then cb(embed) end
		end

		for _, provider in ipairs(PROVIDER_RESOLVERS) do
			if url:find(provider.pattern) then
				return provider.resolve(url, finish)
			end
		end

		http.Fetch(url, function(body, _, headers, code)
			if code and (code < 200 or code >= 300) then return finish(nil) end

			local content_type
			for k, v in pairs(headers or {}) do
				if k:lower() == "content-type" then content_type = v:lower() break end
			end

			if body and #body > RESOLVE_MAX_BODY then
				body = body:sub(1, RESOLVE_MAX_BODY)
			end

			local ok, embed = pcall(build_embed, url, content_type, body or "")
			embed = ok and embed or nil

			-- website cards get the domain favicon (a second server-side fetch)
			if embed and embed.kind == "link" then
				fetch_favicon(url, body or "", function(favicon)
					embed.favicon = favicon
					finish(embed)
				end)
			else
				finish(embed)
			end
		end, function()
			finish(nil)
		end)
	end

	function EasyChat.PlayerAddText(ply, ...)
		if not istable(ply) and not IsValid(ply) then return end

		net.Start(NET_ADD_TEXT)
		net.WriteTable({ ... })
		net.Send(ply)
	end

	function EasyChat.Warn(ply, msg)
		EasyChat.PlayerAddText(ply, COLOR_RED, "[WARN] " ..  msg)
	end

	local function print_chat_msg(ply, msg, is_team, is_dead)
		local print_args = {}

		table.insert(print_args, COLOR_PRINT_CHAT_TIME)
		table.insert(print_args, os.date("!%H:%M:%S "))

		if is_team then
			table.insert(print_args, COLOR_TEAM)
			table.insert(print_args, "(Team) ")
		end

		if is_dead then
			table.insert(print_args, COLOR_DEAD)
			table.insert(print_args, "*DEAD* ")
		end

		local stripped_ply_nick = ply:Nick()
		if #stripped_ply_nick > 20 then
			stripped_ply_nick = stripped_ply_nick:sub(1, 20) .. "..."
		end

		table.insert(print_args, COLOR_PRINT_CHAT_NICK)
		table.insert(print_args, stripped_ply_nick)

		table.insert(print_args, COLOR_PRINT_CHAT_MSG)
		table.insert(print_args, (": %s\n"):format(msg))

		msgc_native(unpack(print_args))
	end

	function EasyChat.SendGlobalMessage(ply, str, is_team, is_local, skip_player_say)
		local msg
		if not skip_player_say then
			native = true
			local result = hook.Run("PlayerSay", ply, str, is_team, is_local)
			native = false

			if result == true then return -- kill the message
			elseif result == false then -- let the message pass
			elseif type(result) == "string" then -- replace the message
				msg = result
			end
		else
			msg = str
		end

		msg = EasyChat.ExtendedStringTrim(msg)
		if #msg == 0 then return end

		-- transform text after PlayerSay
		local datapack = { msg, is_team, is_local }
		if EasyChat.SafeHookRun("PlayerSayPostTransform", ply, datapack, is_team, is_local) == false then return end

		msg, is_team, is_local = unpack(datapack)

		msg = EasyChat.ExtendedStringTrim(msg)
		if #msg == 0 then return end

		-- compact with gameevent
		hook.Run("player_say", {
			priority = 1,
			userid = IsValid(ply) and ply:UserID() or 0,
			text = msg,
			teamonly = is_team and 1 or 0,
			is_local = is_local and 1 or 0
		})

		local filter = {}
		local broken_count = 1
		local function add_to_filter(ply_to_add)
			local id = ply_to_add:AccountID()
			if not id then
				filter[broken_count] = ply_to_add
				broken_count = broken_count + 1
			else
				filter[id] = ply_to_add
			end
		end

		add_to_filter(ply)
		for _, listener in ipairs(player.GetAll()) do
			if listener ~= ply then
				local can_see = hook.Run("PlayerCanSeePlayersChat", msg, is_team, listener, ply, is_local)
				if can_see == true then -- can be another type than a bool
					add_to_filter(listener)
				elseif can_see == false then -- can be nil so need to check for false
					filter[listener:AccountID() or 0] = nil
				end
			end
		end

		filter = table.ClearKeys(filter)

		EasyChat.MessageIdCounter = (EasyChat.MessageIdCounter or 0) + 1
		if EasyChat.MessageIdCounter >= 0xFFFFFFFF then EasyChat.MessageIdCounter = 1 end
		local msg_id = EasyChat.MessageIdCounter

		local is_dead = not ply:Alive()
		net.Start(NET_BROADCAST_MSG)
		net.WriteUInt(msg_id, 32)
		net.WriteUInt(ply:UserID(), 16)
		net.WriteString(ply:RichNick())
		net.WriteString(msg)
		net.WriteBool(is_dead)
		net.WriteBool(is_team)
		net.WriteBool(is_local)
		net.Send(filter)

		-- resolve posted urls server-side (once) and broadcast the resulting embeds to the
		-- same recipients, keyed by msg_id so clients can attach them under the message
		if EC_RESOLVE_URLS:GetBool() and EasyChat.ResolveURLEmbed then
			local recipients = filter -- sequential player list (table.ClearKeys'd above)
			local url_count = 0
			for _, url in ipairs(EasyChat.ExtractURLs(msg)) do
				url_count = url_count + 1
				if url_count > 3 then break end -- cap embeds per message

				EasyChat.ResolveURLEmbed(ply, url, function(embed)
					if not embed then return end

					local valid = {}
					for _, recipient in ipairs(recipients) do
						if IsValid(recipient) then valid[#valid + 1] = recipient end
					end
					if #valid == 0 then return end

					net.Start(NET_MSG_EMBED)
					net.WriteUInt(msg_id, 32)
					-- whether the url was the whole message (so the hud omitted its raw text)
					net.WriteBool(msg:Trim() == url)
					net.WriteString(embed.kind or "link")
					net.WriteString(embed.url or url)
					net.WriteString(embed.page_url or url)
					net.WriteString(embed.title or "")
					net.WriteString(embed.description or "")
					net.WriteString(embed.site_name or "")

					local favicon = embed.favicon
					net.WriteBool(favicon ~= nil)
					if favicon then
						net.WriteString(favicon.mime)
						net.WriteUInt(#favicon.data, 32)
						net.WriteData(favicon.data, #favicon.data)
					end

					net.Send(valid)
				end)
			end
		end

		if game.IsDedicated() and not is_local then
			-- shows in server console
			print_chat_msg(ply, msg, is_team, is_dead)
		end
	end

	local SPAM_STEP = 1 -- how many messages can be sent per second after burst
	local SPAM_MAX = 5 -- max amount of messages per burst

	local spam_watch_lookup = {}
	local function get_message_cost(msg, is_same_msg)
		local _, real_msg_len = msg:gsub("[^\128-\193]", "")
		if real_msg_len > 1024 then
			return SPAM_MAX - 1
		else
			local is_same_msg_spam = is_same_msg and real_msg_len > 128
			return is_same_msg_spam and 3 or 0
		end
	end

	local function spam_watch(ply, msg)
		if ply:IsAdmin() then return false end

		local time = RealTime()
		local last_msg = spam_watch_lookup[ply] or { Time = 0, Message = "" }

		-- if the last_msg.Time is inferior to current time it means the player is not
		-- being rate-limited (spamming) update its time to the current one
		if last_msg.Time < time then
			last_msg.Time = time
		end

		local is_same_msg = last_msg.Message == msg
		last_msg.Message = msg

		-- compute what time is appropriate for the current message
		local new_msg_time = last_msg.Time + SPAM_STEP + get_message_cost(msg, is_same_msg)

		-- if the computed time is superior to our limit then its spam, rate-limit the player
		if new_msg_time > time + SPAM_MAX then
			-- we dont want the rate limit to last forever, clamp the max new time
			local max_new_time = time + SPAM_MAX + 3
			if new_msg_time > max_new_time then
				new_msg_time = max_new_time
			end

			spam_watch_lookup[ply] = { Time = new_msg_time, Message = msg }
			return true
		end

		spam_watch_lookup[ply] = { Time = new_msg_time, Message = msg }
		return false
	end
	EasyChat.SpamWatch = spam_watch

	local EC_MAX_CHARS = GetConVar("easychat_max_chars")
	function EasyChat.ReceiveGlobalMessage(ply, msg, is_team, is_local)
		-- we sub the message len clientside if we receive something bigger here
		-- it HAS to be malicious
		if #msg > EC_MAX_CHARS:GetInt() then
			EasyChat.SafeHookRun("ECBlockedMessage", ply, msg, is_team, is_local, "too big")
			EasyChat.Warn(ply, ("NOT SENT (TOO BIG): %s..."):format(msg:sub(1, 100)))
			return false
		end

		-- anti-spam
		if spam_watch(ply, msg) then
			EasyChat.SafeHookRun("ECBlockedMessage", ply, msg, is_team, is_local, "spam")
			EasyChat.Warn(ply, ("NOT SENT (SPAM): %s..."):format(msg:sub(1, 100)))
			return false
		end

		-- trim the message to remove any oddities so its clean to process for hooks etc...
		msg = EasyChat.ExtendedStringTrim(msg)

		-- Transform text before PlayerSay
		local datapack = { msg, is_team, is_local }
		if EasyChat.SafeHookRun("PlayerSayTransform", ply, datapack, is_team, is_local) == false then return false end

		local skip_player_say = datapack.SkipPlayerSay
		msg, is_team, is_local = unpack(datapack, 1, 3)

		EasyChat.SendGlobalMessage(ply, msg, is_team, is_local, skip_player_say)
	end

	local is_valid = _G.IsValid
	local blocked_players = EasyChat.BlockedPlayers or {}
	EasyChat.BlockedPlayers = blocked_players
	function EasyChat.IsBlockedPlayer(ply, steam_id)
		if not is_valid(ply) or not steam_id then return false end

		local lookup = blocked_players[ply]
		if not lookup then return false end
		if not lookup[steam_id] then return false end

		return true
	end

	net.Receive(NET_SEND_MSG, function(_, ply)
		local msg = net.ReadString()
		local is_team = net.ReadBool()
		local is_local = net.ReadBool()

		EasyChat.ReceiveGlobalMessage(ply, msg, is_team, is_local)
	end)

	net.Receive(NET_SYNC_BLOCKED, function(_, ply)
		local partial = net.ReadBool()
		if not partial then
			local lookup = {}
			local blocked_steam_ids = net.ReadTable()
			for _, steam_id in pairs(blocked_steam_ids) do
				lookup[steam_id] = true
			end

			EasyChat.BlockedPlayers[ply] = lookup
		else
			local blocked_steam_ids = EasyChat.BlockedPlayers[ply] or {}
			local steam_id = net.ReadString()
			local blocked = net.ReadBool()
			blocked_steam_ids[steam_id] = blocked or nil
			EasyChat.BlockedPlayers[ply] = blocked_steam_ids
		end
	end)

	function EasyChat.PlayerCanSeePlayersChat(_, _, listener, speaker, is_local)
		if is_local then
			if not IsValid(listener) or not IsValid(speaker) then
				return false
			end

			if is_local and listener:GetPos():Distance(speaker:GetPos()) > speaker:GetInfoNum("easychat_local_msg_distance", 150) then
				return false
			end
		end

		if IsValid(listener) and IsValid(speaker) and EasyChat.IsBlockedPlayer(listener, speaker:SteamID()) then
			return false
		end
	end

	local get_steam_id = FindMetaTable("Player").SteamID
	local is_ply_blocked = EasyChat.IsBlockedPlayer
	function EasyChat.PlayerCanHearPlayersVoice(listener, talker)
		if is_ply_blocked(listener, get_steam_id(talker)) then return false end
	end

	hook.Add("PlayerCanSeePlayersChat", TAG, EasyChat.PlayerCanSeePlayersChat)
	hook.Add("PlayerCanHearPlayersVoice", TAG, EasyChat.PlayerCanHearPlayersVoice)
	hook.Add("PlayerDisconnected", TAG, function(ply)
		spam_watch_lookup[ply] = nil
		EasyChat.BlockedPlayers[ply] = nil
	end)
end

if CLIENT then
	local BLOCKED_PLAYERS_PATH = "easychat/blocked_players.json"
	local BLOCKED_STRINGS_PATH = "easychat/BLOCKED_STRINGS.json"

	-- translation
	local EC_TRANSLATE_INC_MSG = CreateConVar("easychat_translate_inc_msg", "0", FCVAR_ARCHIVE, "Translates incoming chat messages")
	local EC_TRANSLATE_INC_SRC_LANG = CreateConVar("easychat_translate_inc_source_lang", "auto", FCVAR_ARCHIVE, "Language used in incoming chat messages")
	local EC_TRANSLATE_INC_TARGET_LANG = CreateConVar("easychat_translate_inc_target_lang", "en", FCVAR_ARCHIVE, "Language to translate incoming chat messages to")
	local EC_TRANSLATE_OUT_MSG = CreateConVar("easychat_translate_out_msg", "0", FCVAR_ARCHIVE, "Translates your chat messages")
	local EC_TRANSLATE_OUT_SRC_LANG = CreateConVar("easychat_translate_out_source_lang", "auto", FCVAR_ARCHIVE, "Language used in your chat messages")
	local EC_TRANSLATE_OUT_TARGET_LANG = CreateConVar("easychat_translate_out_target_lang", "en", FCVAR_ARCHIVE, "Language to translate your chat messages to")

	function user_id_to_ply(user_id)
		for _, ply in ipairs(player.GetAll()) do
			if ply:UserID() == user_id then
				return ply
			end
		end

		return false
	end

	local BLOCKED_STRINGS = file.Read(BLOCKED_STRINGS_PATH, "DATA") or ""
	EasyChat.BlockedStrings = util.JSONToTable(BLOCKED_STRINGS) or {}

	function EasyChat.BlockString(word, is_pattern)
		table.insert(EasyChat.BlockedStrings, {
			Content = word,
			IsPattern = is_pattern or false
		})

		file.Write(BLOCKED_STRINGS_PATH, util.TableToJSON(EasyChat.BlockedStrings))
	end

	function EasyChat.UnblockString(id)
		table.remove(EasyChat.BlockedStrings, id)
		file.Write(BLOCKED_STRINGS_PATH, util.TableToJSON(EasyChat.BlockedStrings))
	end

	-- Censorship depends on steam language
	-- shortest racial slur from every language from steam api in 2021
	local racial_slur_testers = util.Base64Decode("bmlnZ2VyCmhvbW8KYmliYQpwaWNoa3UKbmVncgpsZXNiYQpwZApqaWQKz4DOv8+Nz4PPhM63CmphcMOzCmNoZWNjCuyVoOyekAptYXJpY2EKY2lwCmZ1ZmEKbXVpc3QKZmF4YQpvw6cK0LPQtdC5CsSRxKk="):Split("\n")
	local is_steam_filtering_chat = nil

	function EasyChat.IsSteamFilteringChat()
		if is_steam_filtering_chat ~= nil then return is_steam_filtering_chat end

		-- we can only loosen restrictions so this should catch most cases
		-- BUG: We cannot catch custom filtered words, but the player then likely has filtering on regardless
		for filter_mode = TEXT_FILTER_UNKNOWN, TEXT_FILTER_NAME do
			for _, racial_slur_test in pairs(racial_slur_testers) do
				local filtered = util.FilterText(racial_slur_test, filter_mode)

				if filtered ~= racial_slur_test then
					is_steam_filtering_chat = true

					return true
				end
			end
		end

		is_steam_filtering_chat = false

		return false
	end

	local broken_filtering = nil

	function EasyChat.IsFilteringBroken()
		-- Automatically becomes fixed in easychat if ever fixed in GMod (or in steam?)
		if broken_filtering ~= nil then return broken_filtering end
		local broken = "\xe2\x96\x88"
		local broken_result = util.FilterText(broken, TEXT_FILTER_UNKNOWN)
		broken_filtering = broken ~= broken_result

		return broken_filtering
	end

	function EasyChat.FilterString(str)
		local original_str = str
		local base_str = ec_markup.GetText(str)
		if EasyChat.IsFilteringBroken() and EasyChat.IsSteamFilteringChat() then
			--TODO: Alternative (better) approach:
			--      Redo in Lua all that is being accidentally filtered
			--      and check if string matches util.FilterText result

			str = util.FilterText(base_str) -- respect the Steam filter settings
		end

		for _, blocked_str in ipairs(EasyChat.BlockedStrings) do
			local content = blocked_str.Content
			if not blocked_str.IsPattern then
				content = blocked_str.Content:PatternSafe()
			end

			str = str:gsub(content, function(match)
				return ("*"):rep(#match)
			end)
		end

		if base_str ~= str then
			return str
		end

		return original_str
	end

	function EasyChat.ReceiveGlobalMessage(ply, msg, is_dead, is_team, is_local)
		if EasyChat.IsBlockedPlayer(ply) then return end

		-- so we never have the two together
		if is_local and is_team then
			is_team = false
		end

		local only_local = GetConVar("easychat_only_local")
		if only_local and only_local:GetBool() and not is_local then return end

		msg = EasyChat.FilterString(msg)

		local source_lang, target_lang =
			EC_TRANSLATE_INC_SRC_LANG:GetString(),
			EC_TRANSLATE_INC_TARGET_LANG:GetString()

		if EC_TRANSLATE_INC_MSG:GetBool() and source_lang ~= target_lang and ply ~= LocalPlayer() and target_lang ~= "auto" then
			EasyChat.Translator:Translate(msg, source_lang, target_lang, function(success, _, translation)
				local datapack = { msg }
				if EasyChat.SafeHookRun("OnPlayerChatTransform", ply, datapack, is_team, is_local) == false then return end

				msg = datapack[1]
				if not msg then return end

				-- dont use the gamemode default function here as it always returns true
				local suppress = hook.Call("OnPlayerChat", nil, ply, msg, is_team, is_dead, is_local)
				if not suppress then
					-- call the gamemode function if we're not suppressed otherwise it wont display
					GAMEMODE:OnPlayerChat(ply, msg, is_team, is_dead, is_local)
					if translation and msg ~= translation then
						chat.AddText(ply, ("▲ %s ▲"):format(translation))
					end

					-- compact with gameevent
					hook.Run("player_say", {
						priority = 1,
						userid = IsValid(ply) and ply:UserID() or 0,
						text = msg,
						teamonly = is_team and 1 or 0,
						is_local = is_local and 1 or 0
					})
				end
			end)
		else
			hook.Run("OnPlayerChat", ply, msg, is_team, is_dead, is_local)

			-- compact with gameevent
			hook.Run("player_say", {
				priority = 1,
				userid = IsValid(ply) and ply:UserID() or 0,
				text = msg,
				teamonly = is_team and 1 or 0,
				is_local = is_local and 1 or 0
			})
		end
	end

	local MAX_RETRIES = 40
	local RETRY_DELAY = 0.25
	local DISCONNECTED_COLOR = Color(110, 247, 177)
	net.Receive(NET_BROADCAST_MSG, function()
		local msg_id = net.ReadUInt(32)
		local user_id = net.ReadUInt(16)
		local user_name = net.ReadString()
		local msg = net.ReadString()
		local is_dead = net.ReadBool()
		local is_team = net.ReadBool()
		local is_local = net.ReadBool()

		local function receive(retries)
			retries = retries or 0

			local ply = user_id_to_ply(user_id)
			if not IsValid(ply) then
				if retries > MAX_RETRIES then
					chat.AddText(
						DISCONNECTED_COLOR,
						"[DISCONNECTED] ",
						COLOR_PRINT_CHAT_MSG,
						user_name,
						COLOR_PRINT_CHAT_MSG,
						(": %s"):format(msg)
					)

					return
				end

				timer.Simple(RETRY_DELAY, function()
					receive(retries + 1)
				end)

				return
			end

			-- tag the render so networked embeds attach under this message (see GlobalAddText).
			-- flag whether the message is *only* a url, so the hud can swap it for the embed
			-- while keeping the raw url visible when it's part of a longer message.
			local trimmed = msg:Trim()
			local url_start, url_end = EasyChat.IsURL(trimmed)
			EasyChat.RenderMessageId = msg_id
			EasyChat.RenderStandaloneURL = url_start == 1 and url_end == #trimmed
			EasyChat.ReceiveGlobalMessage(ply, msg, is_dead, is_team, is_local)
			EasyChat.RenderMessageId = nil
			EasyChat.RenderStandaloneURL = nil
		end

		receive()
	end)

	net.Receive(NET_ADD_TEXT, function()
		local args = net.ReadTable()
		chat.AddText(unpack(args))
	end)

	net.Receive(NET_MSG_EMBED, function()
		local msg_id = net.ReadUInt(32)
		local standalone_url = net.ReadBool() -- was the url the whole message (its raw text omitted from the hud)?
		local embed = {
			kind = net.ReadString(),
			url = net.ReadString(),
			page_url = net.ReadString(),
			title = net.ReadString(),
			description = net.ReadString(),
			site_name = net.ReadString(),
		}

		for _, key in ipairs({ "title", "description", "site_name" }) do
			if embed[key] == "" then embed[key] = nil end
		end

		if net.ReadBool() then
			local mime = net.ReadString()
			local raw = util.Decompress(net.ReadData(net.ReadUInt(32)))
			if raw and raw ~= "" then
				embed.favicon = ("data:%s;base64,%s"):format(mime, util.Base64Encode(raw, true))
			end
		end

		if EasyChat.GUI and IsValid(EasyChat.GUI.RichText)
			and EasyChat.GUI.RichText.AppendEmbed and GetConVar("easychat_images"):GetBool()
		then
			EasyChat.GUI.RichText:AppendEmbed(msg_id, embed)
		end

		-- put the resolved media in the hud: images via the image part, websites via the (opt-in)
		-- embed part -- which falls back to plain link text for a standalone url when disabled.
		if EasyChat.ChatHUD and GetConVar("easychat_hud_custom"):GetBool() then
			if embed.kind == "image" then
				-- when the url is part of a longer message its text stays, so put the image on
				-- its own line below it (a standalone url was omitted, so the image takes its place)
				if not standalone_url then EasyChat.ChatHUD:NewLine() end
				EasyChat.ChatHUD:AppendImageURL(embed.url)
			elseif embed.kind == "link" then
				EasyChat.ChatHUD:AppendEmbed(embed, standalone_url)
			end
			EasyChat.ChatHUD:InvalidateLayout()
		end
	end)

	function EasyChat.SendGlobalMessage(msg, is_team, is_local, no_translate)
		if msg:find("\0", 1, true) then
			ErrorNoHalt("Null byte on chat message, unhandled!")
		end

		msg = EasyChat.MacroProcessor:ProcessString(msg)

		local ply = LocalPlayer()

		-- transform text before PlayerSay
		local datapack = { msg }
		if EasyChat.SafeHookRun("PlayerSayTransform", ply, datapack, is_team, is_local) == false then return false end

		msg = EasyChat.ExtendedStringTrim(datapack[1])
		if #msg == 0 then return false end

		--  this isn't in the specs but it is now :|
		native = false
		local result = EasyChat.SafeHookRun("PlayerSay", ply, msg, is_team, is_local)
		native = true

		if result == true then -- kill the message
			return false
		elseif result == false then -- let the message pass
		elseif type(result) == "string" then -- Replace the message
			msg = EasyChat.ExtendedStringTrim(result)
		end

		if #msg == 0 then return false end

		-- Transform text after PlayerSay
		datapack = { msg }
		if EasyChat.SafeHookRun("PlayerSayPostTransform", ply, datapack, is_team, is_local) == false then return false end

		msg = EasyChat.ExtendedStringTrim(datapack[1])
		if #msg == 0 then return false end

		local result = EasyChat.SafeHookRun("SendChatMessage", msg, is_team, is_local)
		if result == false then return false end

		local source_lang, target_lang =
			EC_TRANSLATE_OUT_SRC_LANG:GetString(),
			EC_TRANSLATE_OUT_TARGET_LANG:GetString()

		if not no_translate and EC_TRANSLATE_OUT_MSG:GetBool() and source_lang ~= target_lang and target_lang ~= "auto" then
			EasyChat.Translator:Translate(msg, source_lang, target_lang, function(success, _, translation)
				net.Start(NET_SEND_MSG)
				net.WriteString(success and translation or msg)
				net.WriteBool(is_team)
				net.WriteBool(is_local)
				net.SendToServer()
			end)
		else
			net.Start(NET_SEND_MSG)
			net.WriteString(msg)
			net.WriteBool(is_team)
			net.WriteBool(is_local)
			net.SendToServer()
		end
	end

	function EasyChat.LoadBlockedPlayers()
		local BLOCKED_PLAYERS = file.Read(BLOCKED_PLAYERS_PATH, "DATA") or ""
		EasyChat.BlockedPlayers = util.JSONToTable(BLOCKED_PLAYERS) or {}

		local lookup = {}

		if GetConVar("easychat_sync_steam_blocks"):GetBool() then
			for _, ply in ipairs(player.GetAll()) do
				if ply:GetFriendStatus() == "blocked" then
					table.insert(lookup, ply:SteamID())
				end
			end
		end

		for steam_id, _ in pairs(EasyChat.BlockedPlayers) do
			table.insert(lookup, steam_id)
		end

		EasyChat.RunOnNextFrame(function()
			net.Start(NET_SYNC_BLOCKED)
			net.WriteBool(false)
			net.WriteTable(lookup)
			net.SendToServer()
		end)
	end

	hook.Add("Initialize", "EasyChatBlockListInit", EasyChat.LoadBlockedPlayers)

	function EasyChat.BlockPlayer(steam_id)
		EasyChat.BlockedPlayers[steam_id] = true
		file.Write(BLOCKED_PLAYERS_PATH, util.TableToJSON(EasyChat.BlockedPlayers))
		notification.AddLegacy("Blocked user: " .. steam_id, NOTIFY_GENERIC, 5)

		net.Start(NET_SYNC_BLOCKED)
		net.WriteBool(true)
		net.WriteString(steam_id)
		net.WriteBool(true)
		net.SendToServer()

		EasyChat.SafeHookRun("ECBlockedPlayer", steam_id)
	end

	function EasyChat.UnblockPlayer(steam_id)
		EasyChat.BlockedPlayers[steam_id] = nil
		file.Write(BLOCKED_PLAYERS_PATH, util.TableToJSON(EasyChat.BlockedPlayers))
		notification.AddLegacy("Unblocked user: " .. steam_id, NOTIFY_UNDO, 5)

		net.Start(NET_SYNC_BLOCKED)
		net.WriteBool(true)
		net.WriteString(steam_id)
		net.WriteBool(false)
		net.SendToServer()

		EasyChat.SafeHookRun("ECUnblockedPlayer")
	end

	function EasyChat.IsBlockedPlayer(ply)
		if not IsValid(ply) then return false end
		if not ply:IsPlayer() then return false end

		if GetConVar("easychat_sync_steam_blocks"):GetBool() then
			local steam_blocked = (ply:GetFriendStatus() or "") == "blocked"
			if steam_blocked then return true end
		end

		local steam_id = ply:SteamID() or ""
		if LocalPlayer():SteamID() == steam_id then return false end

		return EasyChat.BlockedPlayers[steam_id] and true or false
	end

	-- sync up data for players joining, we dont want a funny steam blocked person to avoid blocking
	gameevent.Listen("player_spawn")
	hook.Add("player_spawn", TAG, function(data)
		if not GetConVar("easychat_sync_steam_blocks"):GetBool() then return end

		timer.Simple(10, function()
			local ply = Player(data.userid)
			if not IsValid(ply) then return end
			if ply:GetFriendStatus() ~= "blocked" then return end

			net.Start(NET_SYNC_BLOCKED)
			net.WriteBool(true)
			net.WriteString(ply:SteamID())
			net.WriteBool(true)
			net.SendToServer()
		end)
	end)
end

PLY.old_IsTyping = PLY.old_IsTyping or PLY.IsTyping
function PLY:IsTyping()
	if self:ECIsEnabled() then
		return self:GetNWBool("ec_is_typing", false)
	else
		return self:old_IsTyping()
	end
end

local function say_override(ply, msg, is_team, is_local)
	if not msg then return end

	msg = EasyChat.ExtendedStringTrim(msg)
	if #msg == 0 then return end

	if SERVER then
		if not IsValid(ply) then
			RunConsoleCommand(is_team and "say_team" or "say", msg)
			return
		end

		EasyChat.ReceiveGlobalMessage(ply, msg, is_team or false, is_local or false)
	end

	if CLIENT then
		if ply ~= LocalPlayer() then return end

		local should_send = EasyChat.SafeHookRun("ECShouldSendMessage", msg)
		if should_send == false then return end

		EasyChat.SendGlobalMessage(msg, is_team or false, is_local or false)
	end
end

PLY.old_Say = PLY.old_Say or PLY.Say -- in case we need the old version
function PLY:Say(msg, is_team, is_local)
	say_override(self, msg, is_team, is_local)
end

function Say(msg, is_team, is_local)
	if CLIENT then
		say_override(LocalPlayer(), msg, is_team, is_local)
	end

	if SERVER then
		say_override(nil, msg, is_team, is_local)
	end
end
