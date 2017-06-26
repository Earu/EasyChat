# EasyChat is a Garry's Mod addon, it replaces the default souce chat and adds many features.

- Fully customizable colors and font

- Various options like timestamps etc

- Private messages system integrated

- Modular system


## For developers here's the good news:

Easychat is a modular addon, you can make modules for it very easily.
Remember those little scripts that are just about using OnPlayerChat hook or PlayerSay?
Just place them inside easychat/modules and there you go, finally a place to sort things where they belong.
You can also create vgui for EasyChat very easily, make a DPanel that will be parent of your vgui then you can add it to EasyChat frame like so: EasyChat.AddTab("tabnamehere",panelhere) and tada.

### note: The current repository has modules in it you might want to remove them in your installation unless you have the dependancies required for them
