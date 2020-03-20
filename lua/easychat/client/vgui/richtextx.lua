local PANEL = {
	CurrentColor = Color(255, 255, 255),
}

function PANEL:Init()
	self:SetAllowLua(true)
	self:SetHTML([[<html>
		<body>
			<style>
				@import url('https://fonts.googleapis.com/css?family=Roboto&display=swap');

				html, body, span {
					padding: 0;
					margin: 0;
				}

				::-webkit-scrollbar {
					height: 16px;
					width: 16px;
					background: rgba(0, 0, 0, 0);
				}

				::-webkit-scrollbar-thumb {
					background: rgb(180, 180, 180);
				}

				::-webkit-scrollbar-corner {
					background: rgb(180, 180, 180);
					height: 16px;
				}

				body {
					background: rgba(0, 0, 0, 0);
					color: white;
					font-family: Roboto, sans-serif;
					font-size: 16;
					overflow-x: hidden;
				}

				pre {
					white-space: pre-line;
					width: 100%;
					height: 95%;
				}
			</style>
			<pre id="main"></pre>
		</body>
	</html>]])

	self:AddFunction("RichTextX", "OnClick", function(signal_value)
		self:ActionSignal("TextClicked", signal_value)
	end)

	self:AddFunction("RichTextX", "OnRightClick", function(selected_text)
		local copy_menu = DermaMenu()
		copy_menu:AddOption("copy", function() SetClipboardText(selected_text) end)
		copy_menu:AddSpacer()
		-- setting the textContent node of the richtext clears all the children and replaces it
		-- with a single text node, it also doesnt invoke chromium HTML parser which is relatively fast
		copy_menu:AddOption("clear chatlog", function() self:QueueJavascript([[RICHTEXT.textContent = "";]]) end)
		copy_menu:Open()
	end)

	self:AddFunction("RichTextX", "Print", print)

	self:QueueJavascript([[
		const BODY = document.getElementsByTagName("body")[0];
		const RICHTEXT = document.getElementById("main");

		window.addEventListener("contextmenu", (ev) => {
			ev.preventDefault();

			if (ev.target.nodeName == "IMG") {
				RichTextX.OnRightClick(ev.target.src);
				return;
			}

			if (ev.target.nodeName == "SPAN" && ev.target.clickableText) {
				RichTextX.OnRightClick(ev.target.textContent);
				return;
			}

			let selection = window.getSelection();
			RichTextX.OnRightClick(selection.toString());
		});

		let span = null;
		let img = null;
		let isAtBottom = false;

		function atBottom() {
			if (BODY.scrollTop === 0) return true;

			return BODY.scrollTop + window.innerHeight >= BODY.scrollHeight;
		}
	]])
end

function PANEL:SetFGColor(r, g, b)
	local color = istable(r) and r or Color(r, g, b)
	self.CurrentColor = color
end

function PANEL:SetBGColor(r, g, b)
	local color = istable(r) and r or Color(r, g, b)
	local css_color = ("rgb(%d,%d,%d)"):format(color:Unpack())
	self:QueueJavascript(("RICHTEXT.style.background = `%s`;"):format(css_color))
end

-- this sadly relies on surface.GetLuaFonts
function PANEL:SetFontInternal(lua_font)
	if not surface.GetLuaFonts then return end
	local fonts_data, _ = surface.GetLuaFonts()
	local font_data = fonts_data[lua_font:lower()]
	if not font_data then return end

	self:SetFontData(font_data)
end

-- for overrides
function PANEL:ActionSignal(signal_name, signal_value)
end

function PANEL:AppendText(text)
	text = text:JavascriptSafe()
	local css_color = ("rgb(%d,%d,%d)"):format(self.CurrentColor:Unpack())
	local js = (self.ClickableTextValue and [[
		span = document.createElement("span");
		span.onclick = () => RichTextX.OnClick(`]] .. self.ClickableTextValue .. [[`);
		span.clickableText = true;
		span.style.cursor = "pointer";
		span.style.color = "4497CE";
	]] or [[
		span = document.createElement("span");
		span.style.color = `]] .. css_color .. [[`;
	]]) .. [[
		span.textContent = `]] .. text .. [[`;
		isAtBottom = atBottom();
		RICHTEXT.appendChild(span);
		if (isAtBottom) {
			window.scrollTo(0, BODY.scrollHeight);
		}
	]]

	self:QueueJavascript(js)
end

function PANEL:AppendImageURL(url)
	url = url:JavascriptSafe()
	self:QueueJavascript([[
		img = document.createElement("img");
		img.onclick = () => RichTextX.OnClick(`]] .. url .. [[`);
		img.style.cursor = "pointer";
		img.src = `]] .. url .. [[`;
		img.style.maxWidth = `80%`;
		img.style.maxHeight = `300px`;

		RICHTEXT.appendChild(document.createElement("br"));
		RICHTEXT.appendChild(img);
		RICHTEXT.appendChild(document.createElement("br"));
	]])
end

function PANEL:InsertColorChange(r, g, b)
	local color = istable(r) and r or Color(r, g, b)
	self.CurrentColor = color
end

function PANEL:InsertClickableTextStart(signal_value)
	self.ClickableTextValue = signal_value
end

function PANEL:InsertClickableTextEnd()
	self.ClickableTextValue = nil
end

function PANEL:GotoTextEnd()
	self:QueueJavascript([[window.scrollTo(0, BODY.scrollHeight);]])
end

function PANEL:GotoTextStart()
	self:QueueJavascript([[window.scrollTo(0, 0);]])
end

function PANEL:SetFontData(font_data)
	local font_size = (font_data.size or 16) - 3
	self:QueueJavascript([[
		RICHTEXT.style.fontFamily = `]] .. (font_data.font or "Roboto") .. [[, sans-serif`;
		RICHTEXT.style.fontSize = `]] .. font_size .. [[`;
		RICHTEXT.style.fontWeight = `]] .. (font_data.weight or 500) .. [[`;
	]])
end

vgui.Register("RichTextX", PANEL, "DHTML")

function TestRichTextX()
	local r = vgui.Create("RichTextX")
	r:SetSize(400, 400)
	r:SetPos(400, 400)
	r.ActionSignal = function(_, name, value)
		print(name, value)
	end

	r:InsertColorChange(color_white)
	r:AppendText("lololol\n")

	r:InsertColorChange(Color(255, 0, 0))
	r:AppendText("Im red!")

	r:InsertColorChange(color_white)
	r:InsertClickableTextStart("epic signal")
	r:AppendText("clickable text")
	r:InsertClickableTextEnd()

	local long_text = [[how could one man have slipped through your forces fingers time and time again how is it possible this is not some
	agent provocateur or highly trained assassin we are discussing gordon freeman is a theoretical physicist who had hardly earned the distinction
	of his ph d at the time of the black mesa incident i have good reason to believe that in the intervening years he was in a state that precluded
	further development of covert skills the man you have consistently failed to slow let alone capture is by all standards simply that an ordinary
	man how can you have failed to apprehend him\n]]
	for _ = 1, 5 do
		r:AppendText(long_text)
	end

	r:AppendImageURL("https://cdn.discordapp.com/attachments/289906269278568448/686970306770108455/unknown.png")

	timer.Simple(4, function() r:GotoTextEnd() end)
	timer.Simple(6, function() r:GotoTextStart() end)
	timer.Simple(10, function() r:Remove() end)
end