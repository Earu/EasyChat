if jit.arch == "x64" then return end

hook.Add("InitPostEntity", "x64_warning", function()
    if cookie.GetString("gmod_x64_warning") == "1" then return end

    Derma_Query([[You are running a 32-bit version of Garry's Mod. This is not recommended for Garry's Mod 64-bit users.
    If you are using a 64-bit operating system, you should install the 64-bit version of Garry's Mod.
    It can be done by changing your Garry's Mod beta in your Steam library to "x86-64 - Chromium + 64-bit binaries"]], "Warning",
        "Ok", function()
            gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=2725447709")
        end)

    cookie.Set("gmod_x64_warning", "1")
end)