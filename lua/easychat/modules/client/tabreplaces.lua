local replaces = {
    [".iunno"] = [[¯\_(ツ)_/¯]],
    [".lenny"] = [[( ͡° ͜ʖ ͡° )]],
    [".fliptable"] = [[(╯°□°）╯︵ ┻━┻]],
    [".unflip "] = [[┬─┬ ノ( ゜-゜ノ)]],
}

hook.Add("OnChatTab","EasyChatModuleEmojisReplacement",function(text)
    local args = string.Explode(" ",text)
    if replaces[args[#args]] then
        args[#args] = replaces[args[#args]]
    end
    return table.concat(args," ",1,#args)
end)

return "Tab Replacements"