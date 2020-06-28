local function material_data(mat)
    return Material("../data/" .. mat)
end

local UNCACHED = false
local PROCESSING = true

local cache = {}

local FOLDER = "easychat/emojis/twitch"
file.CreateDir(FOLDER, "DATA")

local LOOKUP_TABLES = {
    "https://api.twitchemotes.com/api/v4/channels/0", -- default twitch
    "https://api.twitchemotes.com/api/v4/channels/5"  -- prime emotes
}

local lookup = {}
for _, url in ipairs(LOOKUP_TABLES) do
    http.Fetch(url, function(body)
        local tbl = util.JSONToTable(body) or {}
        if not tbl.emotes then
            EasyChat.Print(true, "Could not get the lookup table for Twitch")
            return
        end

        for _, v in ipairs(tbl.emotes) do
            -- skip shorthand emotes (for now? they'd have to be remapped)
            -- if we do plan to remap, do we also remap the turbo ones too?
            if v.id >= 15 then
                lookup[v.code] = v.id
                cache[v.code] = UNCACHED
            end
        end
    end, function(err)
        EasyChat.Print(true, "Could not get the lookup table for Twitch")
    end)
end

local TWITCH_CDN_URL = "https://static-cdn.jtvnw.net/emoticons/v1/%s/3.0"
local REPLACEMENTS_URL = "https://cdn.frankerfacez.com/script/replacements/"

local REPLACEMENTS = {
    [15] = "15-JKanStyle.png",
    [16] = "16-OptimizePrime.png",
    [17] = "17-StoneLightning.png",
    [18] = "18-TheRinger.png",
    [22] = "22-RedCoat.png",
    [26] = "26-JonCarnage.png",
    [30] = "30-BCWarrior.png",
    [33] = "33-DansGame.png",
    [36] = "36-PJSalt.png"
}

local function get_twitch_url(name)
    if REPLACEMENTS[lookup[name]] then
        return REPLACEMENTS_URL .. REPLACEMENTS[lookup[name]]
    else
        return TWITCH_CDN_URL:format(lookup[name])
    end
end

local function get_twitch(name)
    if not lookup[name] then return false end

    local c = cache[name]
    if c then
        if c == true then
            return
        end
        return c
    else
        if c == nil then
            return false
        end
    end

    -- Otherwise download dat shit
    cache[name] = PROCESSING

    local path = FOLDER .. "/" .. name .. ".png"

    local exists = file.Exists(path, "DATA")
    if exists then
        local mat = material_data(path)

        if mat and not mat:IsError() then
            c = mat
            cache[name] = c
            return c
        end
    end

    local url = get_twitch_url(name)

    local function fail(err, isvariant)
        EasyChat.Print(true, "Http fetch failed for", url, ": " .. tostring(err))
    end

    http.Fetch(url, function(data, len, hdr, code)
        if code ~= 200 or len <= 222 then
            return fail(code)
        end

        file.Write(path, data)
        local mat = material_data(path)
        if not mat or mat:IsError() then
            file.Delete(path)
            return
        end

        cache[name] = mat
    end, fail)
end

EasyChat.ChatHUD:RegisterEmoteProvider("twitch", get_twitch)
EasyChat.AddEmoteLookupTable("twitch", cache)

return "Twitch Global & Prime Emotes"
