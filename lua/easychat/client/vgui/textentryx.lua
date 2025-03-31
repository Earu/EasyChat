local PANEL = {
	CurrentValue = "",
	ValueInProgress = "",
	History = {},
	HistoryPos = 0,
	CaretPos = 0,
}

local EC_PRESERVE_MESSAGE_IN_PROGRESS = GetConVar("easychat_preserve_message_in_progress")

cvars.AddChangeCallback("easychat_preserve_message_in_progress", function()
	if not EC_PRESERVE_MESSAGE_IN_PROGRESS:GetBool() then
		PANEL.ValueInProgress = ""
	end
end, "clear_value_in_progress_on_disable")

function PANEL:Init()
	self:SetFocusTopLevel(true)
	self:SetKeyboardInputEnabled(true)
	self:SetAllowLua(true)
	self:SetHTML([[<html>
		<body>
			<style>
				@import url('https://fonts.googleapis.com/css2?family=Roboto:wght@400&display=swap');

				html, body {
					padding: 0;
					margin: 0;
					border: none;
					overflow: hidden;
				}

				::selection {
					background-color: rgba(255, 0, 0, 0.5);
					color: gray;
				}

				::-webkit-scrollbar {
					display: none;
				}

				#text-entry {
					margin: 0;
					height: 100%;
					width: 100%;
					border: none;
					padding-left: 5px;
					padding-top: 4px;
					font-family: 'Roboto', sans-serif;
					resize: none;
					text-shadow: ]] .. (EasyChat.UseDermaSkin and "none;" or [[-1px 1px 2px #000,
						1px 1px 2px #000,
					   	1px -1px 2px #000;
						-1px -1px 2px #000;]])
					.. [[
				}
			</style>
			<textarea
				id="text-entry"
				autocomplete="off"
				autocorrect="off"
				autocapitalize="off"
				spellcheck="false" />
		</body>
	</html>]])

	self:AddInternalCallback("OnChange", function(value, caret_pos)
		self.CurrentValue = value
		self.CaretPos = caret_pos

		if EC_PRESERVE_MESSAGE_IN_PROGRESS:GetBool() then
			self.ValueInProgress = value
		end

		self:OnChange()
		self:OnValueChange(value)
	end)

	self:AddInternalCallback("OnArrowUp", function(caret_pos)
		self.CaretPos = caret_pos

		if EC_PRESERVE_MESSAGE_IN_PROGRESS:GetBool() and self.HistoryPos == 0 then
			local textInProgress = self:GetTextInProgress()

			if textInProgress ~= self:GetText() and textInProgress ~= self.History[#self.History] then
				-- bring back message in progress
				self:SetText(self:GetTextInProgress())
				self:OnChange()
				self:OnValueChange(self:GetTextInProgress())
				return
			end
		end

		self.HistoryPos = self.HistoryPos - 1
		self:UpdateFromHistory()
	end)

	self:AddInternalCallback("OnArrowDown", function(caret_pos)
		self.CaretPos = caret_pos
		self.HistoryPos = self.HistoryPos + 1
		self:UpdateFromHistory()
	end)

	self:AddInternalCallback("OnImagePaste", function(name, base64)
		self:OnImagePaste(name, base64)
	end)

	self:AddInternalCallback("OnEnter", function(caret_pos)
		self.CaretPos = caret_pos
		self:AddHistory(self:GetText())
		self.HistoryPos = 0

		self:OnEnter()
	end)

	self:AddInternalCallback("OnTab", function(caret_pos)
		self.CaretPos = caret_pos
		self:OnTab()
	end)

	self:AddInternalCallback("OnRightClick", function()
		local paste_menu = DermaMenu()
		paste_menu:AddOption("Paste", function()
			self:QueueJavascript([[{
				const ev = new ClipboardEvent("paste");
				TEXT_ENTRY.dispatchEvent(ev);
			}]])
		end)
		paste_menu:AddSpacer()
		paste_menu:AddOption("Cancel", function() paste_menu:Remove() end)
		paste_menu:Open()
	end)

	self:AddInternalCallback("GetCurrentValue", function()
		return self:GetText() or ""
	end)
	self:AddInternalCallback("GetPlaceholderText", function()
		return self.PlaceholderText or ""
	end)

	self:AddInternalCallback("Debug", print)

	self:QueueJavascript([[
		const TEXT_ENTRY = document.getElementById("text-entry");
		TEXT_ENTRY.addEventListener("contextmenu", (_) => TextEntryX.OnRightClick());
		TEXT_ENTRY.addEventListener("paste", (ev) => {
			if (!ev.clipboardData && !window.clipboardData) return;
			const items = (ev.clipboardData || window.clipboardData).items;
			if (!items) return;

			for (const item of items) {
				if (item.type.match("^image/")) {
					const file = item.getAsFile();
					const reader = new FileReader();
					reader.onload = () => {
						const b64 = btoa(reader.result);
						TextEntryX.OnImagePaste(file.name, b64);
					};

					reader.readAsBinaryString(file);
					break;
				}
			}
		});

		TEXT_ENTRY.addEventListener("input", (ev) => TextEntryX.OnChange(ev.target.value, ev.target.selectionStart));
		TEXT_ENTRY.addEventListener("keydown", (ev) => {
			switch (ev.which) {
				case 9:
					ev.preventDefault();
					TextEntryX.OnTab(TEXT_ENTRY.selectionStart);
					return false;
				case 13:
					TextEntryX.OnEnter(TEXT_ENTRY.selectionStart);
					if (!ev.shiftKey) {
						ev.preventDefault();
						return false;
					}
					break;
				case 38:
					ev.preventDefault();
					TextEntryX.OnArrowUp(TEXT_ENTRY.selectionStart);
					return false;
				case 40:
					ev.preventDefault();
					TextEntryX.OnArrowDown(TEXT_ENTRY.selectionStart);
					return false;
				default:
					break;
			}
		});
	]])

	local EC_NON_QWERTY = GetConVar("easychat_non_qwerty")
	cvars.RemoveChangeCallback("easychat_non_qwerty", "TextEntryX")
	cvars.AddChangeCallback("easychat_non_qwerty", function()
		self:QueueJavascript([[TEXT_ENTRY.NonQwertyKeyboard = ]] .. tostring(EC_NON_QWERTY:GetBool()) .. [[;]])
	end, "TextEntryX")

	self:QueueJavascript([[
		TEXT_ENTRY.NonQwertyKeyboard = ]] .. tostring(EC_NON_QWERTY:GetBool()) .. [[;

		function insertAtCursor(text) {
			const val = TEXT_ENTRY.value;
			TEXT_ENTRY.value = val + text;
			TextEntryX.OnChange(TEXT_ENTRY.value, TEXT_ENTRY.selectionStart);
		}

		TEXT_ENTRY.addEventListener("beforeinput", (ev) => {
			if (!TEXT_ENTRY.NonQwertyKeyboard) return;

			if (ev.data == "¨" || ev.data == "¨") {
				insertAtCursor("~");
				ev.preventDefault();
			}
		});

		TEXT_ENTRY.addEventListener("keyup", (ev) => {
			if (!TEXT_ENTRY.NonQwertyKeyboard) return;

			if (ev.key == "[") { insertAtCursor("[") }
			if (ev.key == "]") { insertAtCursor("]") }
			if (ev.key == "{") { insertAtCursor("{") }
			if (ev.key == "}") { insertAtCursor("}") }
			if (ev.key == "¨") {
				insertAtCursor("~");
				ev.preventDefault();
			}
		});

		TEXT_ENTRY.click();
		TEXT_ENTRY.focus();
	]])

	local skin = self:GetSkin()
	self:SetBackgroundColor(skin.colTextEntryBG)
	self:SetTextColor(skin.colTextEntryText)
	self:SetBorderColor(skin.colTextEntryBorder)
	self:SetPlaceholderColor(skin.control_color_dark)

	-- hack to clear the focus on the JS side
	local old_KillFocus = self.KillFocus
	self.KillFocus = function(self)
		old_KillFocus(self)
		self:QueueJavascript([[
			if (document.activeElement != document.body) {
				document.activeElement.blur();
			}
		]])
	end

	-- hack to proper re-gain focus on the JS side
	local old_RequestFocus = self.RequestFocus
	self.RequestFocus = function(self)
		old_RequestFocus(self)
		self:QueueJavascript([[
			TEXT_ENTRY.click();
			TEXT_ENTRY.focus();
		]])
	end
end

function PANEL:AddInternalCallback(name, callback)
	self:AddFunction("TextEntryX", name, callback)
end

function PANEL:UpdateFromHistory()
	local pos = self.HistoryPos
	-- is the Pos within bounds?
	if pos < 0 then pos = #self.History end
	if pos > #self.History then pos = 0 end

	local text = (EC_PRESERVE_MESSAGE_IN_PROGRESS:GetBool() and pos == 0) and self:GetTextInProgress() or self.History[pos]
	text = text or ""

	self:SetValue(text)
	self.HistoryPos = pos
end

function PANEL:AddHistory(text)
	if not text or text == "" then return end

	table.RemoveByValue(self.History, text)
	table.insert(self.History, text)
end

function PANEL:GetCaretPos()
	return self.CaretPos
end

function PANEL:SetCaretPos(offset)
	self:QueueJavascript(([[
		TEXT_ENTRY.selectionStart = %d;
		TEXT_ENTRY.selectionEnd = %d;
	]]):format(offset, offset))
	self.CaretPos = offset
end

function PANEL:GetText()
	return self.CurrentValue
end
PANEL.GetValue = PANEL.GetText

function PANEL:GetTextInProgress()
	return self.ValueInProgress
end
PANEL.GetValueInProgress = PANEL.GetTextInProgress

function PANEL:SetText(text)
	text = isstring(text) and text or ""

	self.CurrentValue = text

	self:QueueJavascript([[TextEntryX.GetCurrentValue(x => TEXT_ENTRY.value = x);]])
end

function PANEL:SetValue(text)
	self:SetText(text)
	self:OnChange()
	self:OnValueChange(text)
end

-- this cannot work due to the limitations of the lua -> js interop
function PANEL:AllowInput(last_char) end

local function color_to_css(col)
	return ("rgba(%d, %d, %d, %d)"):format(col.r, col.g, col.b, col.a / 255)
end

function PANEL:SetTextColor(col)
	self:QueueJavascript(([[TEXT_ENTRY.style.color = "%s";]]):format(color_to_css(col)))
	self.TextColor = col
end

function PANEL:SetPlaceholderText(text)
	self.PlaceholderText = text

	self:QueueJavascript([[TextEntryX.GetPlaceholderText(x => TEXT_ENTRY.placeholder = x);]])
end

function PANEL:SetPlaceholderColor(col)
	self.PlaceholderColor = col
	self:QueueJavascript([[{
		const style = document.createElement("style");
		style.type = "text/css";
		style.innerHTML = "#text-entry::placeholder { color: ]] .. color_to_css(col)  .. [[; }";
		document.getElementsByTagName("head")[0].appendChild(style);
	}]])
end

function PANEL:SetCompletionText(text)
	if not text or text:Trim() == "" then
		self.CompletionText = nil
	else
		self.CompletionText = text
	end
end

function PANEL:GetTextColor()
	return self.TextColor
end

function PANEL:SetBackgroundColor(col)
	self:QueueJavascript(([[TEXT_ENTRY.style.backgroundColor = "%s";]]):format(color_to_css(col)))
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

surface.CreateFont("EasyChatCompletionFont", {
	font = "Roboto",
	size = 16,
})

local surface_DisableClipping = _G.surface.DisableClipping
local surface_SetDrawColor = _G.surface.SetDrawColor
local surface_SetTextColor = _G.surface.SetTextColor
local surface_DrawOutlinedRect = _G.surface.DrawOutlinedRect
local surface_DrawRect = _G.surface.DrawRect
local surface_SetFont = _G.surface.SetFont
local surface_GetTextSize = _G.surface.GetTextSize
local surface_SetTextPos = _G.surface.SetTextPos
local surface_DrawText = _G.surface.DrawText
local string_format, string_find, string_sub = _G.string.format, _G.string.find, _G.string.sub

local should_blink = false -- so we dont trigger by default
local blink_text = nil
local color_white = color_white
local function blink(w, h)
	if not should_blink then return end

	local col_val = math.abs(math.sin(RealTime() * 10)) * 255
	surface_SetDrawColor(col_val, 0, 0, col_val)
	surface_DrawOutlinedRect(0, 0, w, h)

	if blink_text then
		surface_SetFont("EasyChatCompletionFont")
		local text_w, text_h = surface_GetTextSize(blink_text)
		local text_x, text_y = w / 2 - text_w / 2, - (text_h + 2)

		surface_DisableClipping(true)
			surface_DrawRect(text_x - 2, text_y - 2, text_w + 4, text_h + 4)

			surface_SetTextPos(text_x, text_y)
			surface_SetTextColor(color_white)
			surface_DrawText(blink_text)
		surface_DisableClipping(false)
	end
end

function PANEL:TriggerBlink(text)
	should_blink = true
	blink_text = text
	timer.Create("ECTextEntryBlink", 2, 1, function()
		should_blink = false
		blink_text = nil
	end)
end

function PANEL:PaintOver(w, h)
	if EasyChat.UseDermaskin then return end
	surface_SetDrawColor(self.BorderColor)
	surface_DrawOutlinedRect(0, 0, w, h)

	if self.CompletionText then
		surface_SetTextColor(self.PlaceholderColor)
		surface_SetFont("EasyChatCompletionFont")
		local cur_text_w = surface_GetTextSize(self.CurrentValue)
		local start_pos, end_pos = string_find(self.CompletionText, self.CurrentValue, 1, true)
		if start_pos == 1 then
			local sub_completion = string_sub(self.CompletionText, end_pos + 1)
			local _, completion_text_h = surface_GetTextSize(sub_completion)
			surface_SetTextPos(cur_text_w + 3, h / 2 - completion_text_h / 2)
			surface_DrawText(sub_completion)
		else
			local sub_completion = string_format("<< %s >>", self.CompletionText)
			local _, completion_text_h = surface_GetTextSize(sub_completion)
			surface_SetTextPos(cur_text_w + 15, h / 2 - completion_text_h / 2)
			surface_DrawText(sub_completion)
		end
	end

	blink(w, h)
end

function PANEL:OnTab() end
function PANEL:OnEnter() end
function PANEL:OnChange() end
function PANEL:OnValueChange(value) end
function PANEL:OnImagePaste(name, base64) end

vgui.Register("TextEntryX", PANEL, "DHTML")