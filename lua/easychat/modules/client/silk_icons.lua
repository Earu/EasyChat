local UNCACHED = false
local PROCESSING = true

local cache = {}

local lookup = {}
for _, name in pairs(file.Find("materials/icon16/*.png", "MOD")) do
    local n = name:Replace(".png", "")
    lookup[n] = true
    cache[n] = UNCACHED
end

local function get_silk(name)
    if not lookup[name] then
        return false
    end

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

    cache[name] = PROCESSING

    local path = "icon16/" .. name .. ".png"

    local exists = file.Exists("materials/" .. path, "MOD")
    if exists then
        local mat = Material(path)

        if not mat or mat:IsError() then
            Msg("[Emoticons] ")
            print("Vanilla silk icon is error????: " .. path)
        else
            c = mat
            cache[name] = c
            return c
        end
    end
end

EasyChat.ChatHUD:RegisterEmoteProvider("silkicons", get_silk)

return "Silk Icons"