local PANEL = {
	CurrentValue = "",
}

function PANEL:Init()
	self:SetFocusTopLevel(true)
	self:SetKeyBoardInputEnabled(true)
	self:SetAllowLua(true)
	self:SetHTML([[<html>
		<body>
			<style>
				html, body {
					padding: 0;
					margin: 0;
					border: none;
				}

				#text-entry {
					margin: 0;
					height: 100%;
					width: 100%;
					border: none;
					padding-left: 3px;
					font-family: 'Roboto', sans-serif;
				}
			</style>
			<input
				id="text-entry"
				autocomplete="off"
				autocorrect="off"
				autocapitalize="off"
				spellcheck="false"
				type="text"/>
		</body>
	</html>]])

	self:AddFunction("TextEntryX", "OnChange", function(value)
		self.CurrentValue = value
		self:OnChange()
		self:OnValueChange()
	end)

	self:AddFunction("TextEntryX", "OnImagePaste", function(name, base64)
		self:OnImagePaste(name, base64)
	end)

	self:AddFunction("TextEntryX", "OnEnter", function()
		self:OnEnter()
	end)

	self:AddFunction("TextEntryX", "Debug", PrintTable)

	self:QueueJavascript([[
		var TEXT_ENTRY = document.getElementById("text-entry");
		TEXT_ENTRY.addEventListener("keyup", (ev) => TextEntryX.OnChange(ev.target.value));
		TEXT_ENTRY.addEventListener("paste", (ev) => {
			let items = (ev.clipboardData || window.clipboardData).items;
			if (!items) return;

			for (let item of items) {
				if (item.type.match("^image/")) {
					let blob = item.getAsFile();
					let reader = new FileReader();
					reader.onload = () => {
						let b64 = reader.result.replace(/^data:.+;base64,/, "");
						TextEntryX.OnImagePaste(blob.name, b64);
					};

					reader.readAsDataURL(blob);
					break;
				}
			}
		});
		TEXT_ENTRY.addEventListener("keydown", (ev) => {
			if (ev.which === 9) {
				ev.preventDefault();
				return false;
			}
		});
		TEXT_ENTRY.addEventListener("keypress", (ev) => {
			if (ev.which === 13) {
				TextEntryX.OnEnter();
			}
		});
		TEXT_ENTRY.click();
		TEXT_ENTRY.focus();
	]])

	local skin = self:GetSkin()
	self:SetBackgroundColor(skin.colTextEntryBG)
	self:SetTextColor(skin.colTextEntryText)
	self.BorderColor = skin.colTextEntryBorder
	self.ActiveColor = skin.control_color_active
end

function PANEL:GetText()
	return self.CurrentValue
end
PANEL.GetValue = PANEL.GetText

function PANEL:SetText(text)
	self.CurrentValue = text
	local js = ([[TEXT_ENTRY.value = `%s`;]]):format(text:JavascriptSafe())
	self:QueueJavascript(js)
end
PANEL.SetValue = PANEL.SetText

function PANEL:SetTextColor(col)
	local js = ([[TEXT_ENTRY.style.color = "rgba(%d,%d,%d,%d)";]]):format(col.r, col.g, col.b, col.a / 255)
	self:QueueJavascript(js)
	self.TextColor = col
end

function PANEL:GetTextColor()
	return self.TextColor
end

function PANEL:SetBackgroundColor(col)
	local js = ([[TEXT_ENTRY.style.backgroundColor = "rgba(%d,%d,%d,%d)";]]):format(col.r, col.g, col.b, col.a / 255)
	self:QueueJavascript(js)
	self.BackgroundColor = col
end

function PANEL:GetBackgroundColor()
	return self.BackgroundColor
end

function PANEL:PaintOver(w, h)
	surface.SetDrawColor(self.BorderColor)
	surface.DrawOutlinedRect(0, 0, w, h)
end

-- /!\ TODO: Find out how to receive key codes
function PANEL:OnKeyCodeReleased(keyCode)
	print(keyCode)
end

function PANEL:OnEnter() end
function PANEL:OnChange() end
function PANEL:OnValueChange(value) end
function PANEL:OnImagePaste(name, base64) end

vgui.Register("TextEntryX", PANEL, "DHTML")

--[[
	test code
]]--

local function test(class, x, y)
	local p = vgui.Create(class)
	p:SetPos(x, y)
	p:SetSize(200, 25)
	p:MakePopup()

	timer.Simple(10, function()
		p:Remove()
	end)
end

test("TextEntryX", 200, 200)
--test("DTextEntry", 200, 300)