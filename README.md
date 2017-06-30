# An open-source advanced chat addon for users and developers.
Modular,Fully customizable and developer friendly EasyChat provides a good amount of features for both users and developers.

## Users
EasyChat aims to be easy but also to provide a good amount of features at the same time, for that a lot of settings for customization have been added throught the development.

#### Default Tabs
- The "Global" tab is basically the chat, type from here to chat with others players.
- The "PM's" tab is where you can send private messages to others players.
- The "LuaTab" tab is for developers, you can run lua code from there.
- The "Settings" tab is where all the default user-friendly settings are located (the rest are console commands).

#### Typing Modes
As you probably noticed when you're typing in the main tab("Global") you have a small button next to the area of where you are typing to text other players. This button shows you current mode of typing and allows you to change it (you can also use tab with chat empty).

There are 3 default modes for EasyChat by default:
- "Say" mode, is the basic mode it allows you to talk with other players like with the default chat.
- "Local" mode, allows you to talk to nearby players, you can change the distance at which player will be albe to see what you typed with easychat_local_msg_distance console command.
- "Console" mode, allows you type in your console from the chat.

#### The Color Settings
The colors of EasyChat can be changed easily, in the "Settings" tab at the top left corner you should be able to see 4 tickboxes and a button that says "Apply Color".

To change the color of an element of EasyChat you need to check the tickbox relative to the element, select a color in the mixer at the right of the settings tab and click "Apply Color" so EasyChat register the color you settled for this element.

#### Font Options
If you know what fonts Garry's Mod posseses you can change the font of your chatbox and chatHUD by typing the name of your font in the text entry and pressing the "Apply Font" button. (yes capital letters matter)

You can also change the size of the font in the chatbox and chatHUD by changing the numbers relative to them, those should be placed under the font name text entry.

#### Various other settings
- "ChatHUD follows chatbox", this makes the chat HUD follows the chatbox position on your screen.
- "Display timestamps", if you enable it you will see the time at which a message was sent.
- "Display team tags",enabled it will show the rank of a player on the server.
- "Color team tags",enabled it will give the rank tag(team tag if enabled) its respectful color.
- "Color player",this give players their rank color in chat.
- "Global tab on open",enabled it will always open the tab corresponding to chat.

- The "Reset Options" button will reset the settings above it (what is explained above basically).
- The "Reset Everything" button will reset every chat setting to its default state even the colors.
- The "Restart" button will restart EasyChat.
- The "Use Dermaskin" button will reload EasyChat in order for it to use the Dermaskin you use if you have any, and if not it will use the default Garry's Mod look.

#### Console Commands
Here's the list of console commands that EasyChat has by default:
- easychat_enable
- easychat_font
- easychat_font_size
- easychat_hud_font_size
- easychat_global_on_open
- easychat_hud_follow
- easychat_local_msg_distance
- easychat_reload
- easychat_reset_settings
- easychat_teams
- easychat_teams_colored
- easychat_timestamps
- easychat_use_dermaskin
- easychat_players_colored
- easychat_no_modules


## Developers
When making EasyChat, I didnt forget fellow developers that would mess with it, or even add content to it, that's why I made EasyChat modular and plug & play.

#### Adding a module
Every of us, developers have already made those silly little scripts using PlayerSay or OnPlayerChat hooks, well if you were looking for a place to put those little scripts, you can just put them in easychat/modules/ directory, its as simple as that.
In theory EasyChat can run everything as a module, if it placed correctly within its module directory.
 
 - A clientside script goes into modules/client/
 - A serverside script goes into modules/server
 - A shared script just goes in modules/
 
 
#### Adding a typing mode
To add a mode to EasyChat main tab its very easy, theres a function for it and its called "EasyChat.AddMode", this function has two parameters.

The first one is a string that will be the name of the mode, and the second one is a function. The function passed as second argument have one parameter which is a string, it is the currently typed DTextEntry text.

Example:

EasyChat.AddMode("Console",function(text) LocalPlayer():ConCommand(text) end)

#### Adding a tab
To adda tab to EasyChat, you need to use "EasyChat.AddTab" which has two parameters.

The first parameter is a string that is the name of the tab, and the second one is a vgui panel.
/!\ you must create the panel with vgui.Create before adding it as a tab/!\

Example:

local panel = vgui.Create("DPanel")
EasyChat.AddTab("A new tab",panel)

#### Auto-focus
EasyChat has an auto-focus feature that allows you to set a panel the user will be focused on when your tab will be active.
For that to happen you need to use "EasyChat.SetFocusForOn", the function has two parameters.

First parameter is a string, its the name of your tab, and the second one is the panel that the user will be focused on when opening your tab and pressing keys.

Example:

local tabname = "test"
local panel = vgui.Create("DPanel")

EasyChat.AddTab(tabname,panel)
local textentry = panel:Add("DTextEntry")
EasyChat.SetFocusFor(tabname,textentry)

#### Notifications
Like for the private message tab you can create notifications for your tab by using the function "EasyChat.FlashTab", this function has one argument.

The only argument of that function is the name of your tab, afterward it will proceed to flash it as its name says.
Each time FlashTab is called, it creates a new notification, the user will be showed those notifications when he will open his chatbox to type.

Example:

local tabname = "test"
local panel = vgui.Create("DPanel")

EasyChat.AddTab(tabname,panel)
EasyChat.FlashTab(tabname)
EasyChat.FlashTab(tabname)

Output:
"EC ⮞ 2 new notifications from test"
