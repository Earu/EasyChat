local PANEL = {
	CurrentValue = "",
	History = {},
	HistoryPos = 0,
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

	self:AddInternalCallback("OnChange", function(value)
		self.CurrentValue = value

		self:OnChange()
		self:OnValueChange(value)
	end)

	self:AddInternalCallback("OnArrowUp", function()
		self.HistoryPos = self.HistoryPos - 1
		self:UpdateFromHistory()
	end)

	self:AddInternalCallback("OnArrowDown", function()
		self.HistoryPos = self.HistoryPos + 1
		self:UpdateFromHistory()
	end)

	self:AddInternalCallback("OnImagePaste", function(name, base64)
		self:OnImagePaste(name, base64)
	end)

	self:AddInternalCallback("OnEnter", function()
		self:AddHistory(self:GetText())
		self.HistoryPos = 0

		self:OnEnter()
	end)

	self:AddInternalCallback("OnTab", function()
		self:OnTab()
	end)

	self:AddInternalCallback("Debug", print)

	self:QueueJavascript([[
		const TEXT_ENTRY = document.getElementById("text-entry");
		TEXT_ENTRY.addEventListener("paste", (ev) => {
			let items = (ev.clipboardData || window.clipboardData).items;
			if (!items) return;

			for (let item of items) {
				if (item.type.match("^image/")) {
					let file = item.getAsFile();
					let reader = new FileReader();
					reader.onload = () => {
						let b64 = btoa(reader.result);
						TextEntryX.OnImagePaste(file.name, b64);
					};

					reader.readAsBinaryString(file);
					break;
				}
			}
		});
		TEXT_ENTRY.addEventListener("keyup", (ev) => TextEntryX.OnChange(ev.target.value));
		TEXT_ENTRY.addEventListener("keydown", (ev) => {
			switch (ev.which) {
				case 9:
					ev.preventDefault();
					TextEntryX.OnTab();
					return false;
				case 13:
					TextEntryX.OnEnter();
					break;
				case 38:
					ev.preventDefault();
					TextEntryX.OnArrowUp();
					return false;
				case 40:
					ev.preventDefault();
					TextEntryX.OnArrowDown();
					return false;
				default:
					// right now is too early
					setTimeout(() => TextEntryX.OnChange(ev.target.value), 1);
					break;
			}
		});
		TEXT_ENTRY.click();
		TEXT_ENTRY.focus();
	]])

	local skin = self:GetSkin()
	self:SetBackgroundColor(skin.colTextEntryBG)
	self:SetTextColor(skin.colTextEntryText)
	self:SetBorderColor(skin.colTextEntryBorder)
end

function PANEL:AddInternalCallback(name, callback)
	self:AddFunction("TextEntryX", name, callback)
end

function PANEL:UpdateFromHistory()
	local pos = self.HistoryPos
	-- is the Pos within bounds?
	if pos < 0 then pos = #self.History end
	if pos > #self.History then pos = 0 end

	local text = self.History[pos]
	text = text or ""

	self:SetText(text)
	self:OnChange()
	self:OnValueChange(text)
	self.HistoryPos = pos
end

function PANEL:AddHistory(text)
	if not text or text == "" then return end

	table.RemoveByValue(self.History, text)
	table.insert(self.History, text)
end

function PANEL:GetText()
	return self.CurrentValue
end
PANEL.GetValue = PANEL.GetText

function PANEL:SetText(text)
	text = text or ""

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

function PANEL:SetBorderColor(col)
	self.BorderColor = col
end

function PANEL:GetBorderColor()
	return self.BorderColor
end

function PANEL:PaintOver(w, h)
	surface.SetDrawColor(self.BorderColor)
	surface.DrawOutlinedRect(0, 0, w, h)
end

function PANEL:OnTab() end
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

--test("TextEntryX", 200, 200)
--test("DTextEntry", 200, 300)