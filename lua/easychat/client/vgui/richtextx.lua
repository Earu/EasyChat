local color_white = color_white
local AVERAGE_AMOUNT_OF_ELEMENTS_PER_LINE = 5

local function css_rgba(col)
	col = col or color_white
	return ("rgba(%d, %d, %d, %s)"):format(col.r, col.g, col.b, (col.a or 255) / 255)
end

local function open_image_viewer(url)
	if IsValid(EasyChat.ImageViewer) then EasyChat.ImageViewer:Remove() end

	local frame = EasyChat.CreateFrame()
	EasyChat.ImageViewer = frame
	frame:SetTitle("Image")
	frame:SetSize(math.floor(ScrW() * 0.4), math.floor(ScrH() * 0.4))
	frame:Center()
	frame:MakePopup()
	frame.btnClose.DoClick = function() frame:Remove() end

	local html = vgui.Create("DHTML", frame)
	html:Dock(FILL)
	html:SetAllowLua(false)

	html:AddFunction("viewer", "Resize", function(w, h)
		if not IsValid(frame) then return end
		w, h = tonumber(w) or 0, tonumber(h) or 0
		if w <= 0 or h <= 0 then return end

		local scale = math.min(1, ScrW() * 0.8 / w, ScrH() * 0.8 / h)
		frame:SetSize(math.max(math.floor(w * scale), 128), math.max(math.floor(h * scale), 96) + 25)
		frame:Center()
	end)

	html:AddFunction("viewer", "Close", function()
		if IsValid(frame) then frame:Remove() end
	end)

	html:SetHTML([[<html><head></head>
		<body style="margin:0;padding:0;background:rgba(0,0,0,0);height:100vh;display:flex;align-items:center;justify-content:center;overflow:hidden;">
			<img src="]] .. url .. [[" style="max-width:100%;max-height:100%;object-fit:contain;cursor:pointer;"
				onload="viewer.Resize(this.naturalWidth, this.naturalHeight);" onclick="viewer.Close();"/>
		</body></html>]])

	return frame
end

local PANEL = {
	CurrentColor = Color(255, 255, 255),
	RichTextXBackgroundColor = Color(0, 0, 0, 0), -- stupid name or it overrides other stuff (?)
}

function PANEL:Init()
	self:SetAllowLua(false)
	self:SetHTML([[<html>
		<body>
			<style>
				@import url('https://fonts.googleapis.com/css2?family=Roboto:wght@400&display=swap');

				html, body, span {
					padding: 0;
					margin: 0;
					text-shadow: ]] .. (EasyChat.UseDermaSkin and "none;" or [[-1px 1px 2px #000,
						1px 1px 2px #000,
				   		1px -1px 2px #000;
						-1px -1px 2px #000;]])
					.. [[
				}

				::selection {
					background-color: rgba(255, 0, 0, 0.5);
					color: gray;
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
					font-family: 'Roboto', sans-serif;
					font-size: 16px;
					overflow-x: hidden;
				}

				pre {
					white-space: pre-line;
					width: 100%;
					height: 95%;
				}

				.blur {
					filter: blur(20px);
				}

				img {

					overflow: hidden;
				}
			</style>
			<pre id="main"></pre>
		</body>
	</html>]])

	self:AddInternalCallback("OnClick", function(signal_value)
		self:ActionSignal("TextClicked", signal_value)
	end)

	self.FindText = nil
	self:AddInternalCallback("GetFindText", function() return self.FindText end)

	local function find_text()
		EasyChat.AskForInput("Find", function(input)
			self.FindText = input
			self:QueueJavascript("RichTextX.GetFindText(window.find);")
		end, false)
	end
	self:AddInternalCallback("Find", find_text)

	self:AddInternalCallback("OnRightClick", function(selected_text)
		local copy_menu = DermaMenu()
		copy_menu:AddOption("Copy", function() SetClipboardText(selected_text) end)
		copy_menu:AddOption("Find", find_text)
		copy_menu:AddSpacer()
		-- setting the textContent node of the richtext clears all the children and replaces it
		-- with a single text node, it also doesnt invoke chromium HTML parser which is relatively fast
		copy_menu:AddOption("Clear Chatlog", function() self:QueueJavascript([[RICHTEXT.textContent = "";]]) end)
		copy_menu:AddSpacer()
		copy_menu:AddOption("Cancel", function() copy_menu:Remove() end)
		copy_menu:Open()
	end)

	self:AddInternalCallback("OnImageClick", function(url)
		open_image_viewer(url)
	end)

	self:AddInternalCallback("OnImageRightClick", function(url)
		local image_menu = DermaMenu()
		image_menu:AddOption("Open in browser", function() EasyChat.OpenURL(url) end)
		image_menu:AddOption("Copy", function() SetClipboardText(url) end)
		image_menu:AddSpacer()
		image_menu:AddOption("Cancel", function() image_menu:Remove() end)
		image_menu:Open()
	end)

	self:AddInternalCallback("OnTextHover", function(text_value, is_hover)
		self:OnTextHover(text_value, is_hover)
	end)

	self.TextToAppend = {}
	self:AddInternalCallback("GetTextToAppend", function()
		local limit = GetConVar("easychat_modern_text_history_limit"):GetInt() * AVERAGE_AMOUNT_OF_ELEMENTS_PER_LINE

		local data = self.TextToAppend[1] or ""
		table.remove(self.TextToAppend, 1)

		local text, clickable_text_value, css_color = data[1], data[2], data[3]
		return text, clickable_text_value, css_color, limit
	end)
	self.ImageURLToAppend = {}
	self:AddInternalCallback("GetImageURLToAppend", function()
		local limit = GetConVar("easychat_modern_text_history_limit"):GetInt() * AVERAGE_AMOUNT_OF_ELEMENTS_PER_LINE

		local url = self.ImageURLToAppend[1] or ""
		table.remove(self.ImageURLToAppend, 1)
		return url, limit, false
	end)

	self.MarkToAppend = {}
	self:AddInternalCallback("GetMarkToAppend", function()
		local id = self.MarkToAppend[1] or 0
		table.remove(self.MarkToAppend, 1)
		return id
	end)

	self.EmbedToAppend = {}
	self:AddInternalCallback("GetEmbedToAppend", function()
		local limit = GetConVar("easychat_modern_text_history_limit"):GetInt() * AVERAGE_AMOUNT_OF_ELEMENTS_PER_LINE

		local embed = self.EmbedToAppend[1] or {}
		table.remove(self.EmbedToAppend, 1)

		-- the classifier verdict drives blurring now: "blur" = unsure (blur it), "hide" = confident
		return embed.msg_id or 0, embed.kind or "link", embed.url or "",
			embed.page_url or "", embed.title or "", embed.description or "",
			embed.site_name or "", embed.favicon or "", embed.nsfw == "blur", limit,
			css_rgba(EasyChat.TabColor), css_rgba(EasyChat.TabOutlineColor),
			css_rgba(EasyChat.LinkColor), css_rgba(EasyChat.TextColor), embed.nsfw == "hide"
	end)

	self:AddInternalCallback("Debug", print)

	self:QueueJavascript([[
		const BODY = document.getElementsByTagName("body")[0];
		const RICHTEXT = document.getElementById("main");

		window.addEventListener("contextmenu", (ev) => {
			ev.preventDefault();

			if (ev.target.nodeName == "IMG" && ev.target.classList.contains("ec-image")) {
				RichTextX.OnImageRightClick(ev.target.src);
				return;
			}

			if (ev.target.nodeName == "SPAN" && ev.target.clickableText) {
				// copy the full value (the displayed text may be a shortened url)
				RichTextX.OnRightClick(ev.target.clickableValue || ev.target.textContent);
				return;
			}

			const selection = window.getSelection();
			RichTextX.OnRightClick(selection.toString());
		});

		window.addEventListener("keydown", (ev) => {
			if (ev.which === 70 && ev.ctrlKey) {
				RichTextX.Find();
				ev.preventDefault();
				return false;
			}
		});

		function atBottom() {
			if (BODY.scrollTop === 0) return true;

			return BODY.scrollTop + window.innerHeight >= BODY.scrollHeight;
		}
	]])

	local last_color = self:GetFGColor()
	local old_insert_color_change = self.InsertColorChange
	self.InsertColorChange = function(_, r, g, b, a)
		last_color = istable(r) and Color(r.r, r.g, r.b) or Color(r, g, b)
		old_insert_color_change(self, last_color.r, last_color.g, last_color.b, last_color.a)
	end

	self.GetLastColorChange = function(_) return last_color end
end

function PANEL:AddInternalCallback(name, callback)
	self:AddFunction("RichTextX", name, callback)
end

function PANEL:SetFGColor(r, g, b)
	local color = istable(r) and r or Color(r, g, b)
	self.CurrentColor = color
end

function PANEL:GetFGColor()
	return self.CurrentColor
end

function PANEL:SetBGColor(r, g, b)
	local color = istable(r) and r or Color(r, g, b)
	local css_color = ("rgb(%d,%d,%d)"):format(color.r, color.g, color.b)
	self:QueueJavascript(("RICHTEXT.style.background = `%s`;"):format(css_color))
	self.RichTextXBackgroundColor = color
end

function PANEL:GetBGColor()
	return self.RichTextXBackgroundColor
end

-- this sadly relies on surface.GetLuaFonts
function PANEL:SetFontInternal(lua_font)
	if not surface.GetLuaFonts then return end
	local fonts_data, _ = surface.GetLuaFonts()
	local font_data = fonts_data[lua_font:lower()]
	if not font_data then return end

	self:SetFontData(font_data)
end

-- compat placeholder
function PANEL:SetUnderlineFont(lua_font)
end

-- for overrides
function PANEL:ActionSignal(signal_name, signal_value)
end

-- for overrides
function PANEL:OnTextHover(text_value, is_hover)
end

function PANEL:AppendText(text)
	local css_color = ("rgb(%d,%d,%d)"):format(self.CurrentColor.r, self.CurrentColor.g, self.CurrentColor.b)
	self.TextToAppend[#self.TextToAppend + 1] = { text, self.ClickableTextValue, css_color }

	self:QueueJavascript([[
		RichTextX.GetTextToAppend((text, clickableTextValue, cssColor, limit) => {
			const span = document.createElement("span");
			if (clickableTextValue) {
				span.onclick = () => RichTextX.OnClick(clickableTextValue);
				span.onmouseenter = () => RichTextX.OnTextHover(clickableTextValue, true);
				span.onmouseleave = () => RichTextX.OnTextHover(clickableTextValue, false);
				span.clickableText = true;
				span.clickableValue = clickableTextValue; // full value (display text may be shortened)
				span.style.cursor = "pointer";
			}
			span.style.color = cssColor;
			span.textContent = text;
			isAtBottom = atBottom();
			RICHTEXT.appendChild(span);

			if (limit > 0 && limit <= RICHTEXT.childElementCount && RICHTEXT.children[0]) {
				RICHTEXT.children[0].remove();
			}

			if (isAtBottom) {
				window.scrollTo(0, BODY.scrollHeight);
			}
		});
	]])
end

function PANEL:AppendImageURL(url)
	self.ImageURLToAppend[#self.ImageURLToAppend + 1] = url

	self:QueueJavascript([[
		RichTextX.GetImageURLToAppend((url, limit, blur) => {
			const imgContainer = document.createElement("div");
			imgContainer.style.overflow = "hidden";
			imgContainer.style.display = "inline-block";

			const img = document.createElement("img");
			img.classList.add("ec-image");
			img.onclick = () => RichTextX.OnImageClick(img.src);
			img.style.cursor = "pointer";
			img.src = url;
			img.style.maxWidth = `80%`;
			img.style.maxHeight = `300px`;
			if (blur) {
				img.classList.add('blur');
				img.onmouseover = () => img.classList.remove('blur');
				img.onmouseout = () => img.classList.add('blur');
			}

			isAtBottom = atBottom();
			RICHTEXT.appendChild(document.createElement("br"));
			imgContainer.appendChild(img);
			RICHTEXT.appendChild(imgContainer);
			RICHTEXT.appendChild(document.createElement("br"));

			if (limit > 0 && limit <= RICHTEXT.childElementCount && RICHTEXT.children[0]) {
				RICHTEXT.children[0].remove();
			}

			if (isAtBottom) {
				window.scrollTo(0, BODY.scrollHeight);
			}
		});
	]])
end

function PANEL:MarkMessage(msg_id)
	self.MarkToAppend[#self.MarkToAppend + 1] = msg_id
	self:QueueJavascript([[
		RichTextX.GetMarkToAppend((msgId) => {
			const anchor = document.createElement("span");
			anchor.id = "ecmsg-" + msgId;
			RICHTEXT.appendChild(anchor);
		});
	]])
end

function PANEL:AppendEmbed(msg_id, embed)
	embed = embed or {}
	embed.msg_id = msg_id
	self.EmbedToAppend[#self.EmbedToAppend + 1] = embed

	self:QueueJavascript([[
		RichTextX.GetEmbedToAppend((msgId, kind, url, pageUrl, title, description, siteName, favicon, blur, limit, bgColor, outlineColor, titleColor, textColor, nsfw) => {
			const container = document.createElement("div");
			container.style.margin = "4px 0";
			container.style.maxWidth = "80%";

			const makeImage = () => {
				const img = document.createElement("img");
				img.classList.add("ec-image");
				img.src = url;
				img.style.cursor = "pointer";
				img.style.maxWidth = "100%";
				img.style.maxHeight = "300px";
				img.style.border = "1px solid " + outlineColor;
				img.onclick = () => RichTextX.OnImageClick(img.src);
				if (blur) {
					img.classList.add("blur");
					img.onmouseover = () => img.classList.remove("blur");
					img.onmouseout = () => img.classList.add("blur");
				}
				return img;
			};

			if (kind === "image" && nsfw) {
				// flagged nsfw/gore: show a placeholder that reveals the image only on click
				const ph = document.createElement("div");
				ph.textContent = "⚠ hidden nsfw/gore image — click to show";
				ph.style.background = bgColor;
				ph.style.border = "1px solid " + outlineColor;
				ph.style.padding = "8px 10px";
				ph.style.color = textColor;
				ph.style.cursor = "pointer";
				ph.style.fontStyle = "italic";
				ph.onclick = () => { ph.replaceWith(makeImage()); };
				container.appendChild(ph);
			} else if (kind === "image") {
				container.appendChild(makeImage());
			} else {
				container.style.background = bgColor;
				container.style.border = "1px solid " + outlineColor;
				container.style.padding = "8px 10px";
				container.style.cursor = "pointer";
				container.onclick = () => RichTextX.OnClick(pageUrl || url);

				if (siteName || favicon) {
					const head = document.createElement("div");
					head.style.display = "flex";
					head.style.alignItems = "center";
					head.style.marginBottom = "3px";

					if (favicon) {
						const ic = document.createElement("img");
						ic.src = favicon;
						ic.style.width = "16px";
						ic.style.height = "16px";
						ic.style.marginRight = "6px";
						ic.style.flexShrink = "0";
						ic.style.objectFit = "contain";
						ic.onerror = () => ic.remove();
						head.appendChild(ic);
					}

					if (siteName) {
						const site = document.createElement("div");
						site.textContent = siteName;
						site.style.fontSize = "11px";
						site.style.color = textColor;
						site.style.opacity = "0.6";
						head.appendChild(site);
					}

					container.appendChild(head);
				}

				const t = document.createElement("div");
				t.textContent = title || (pageUrl || url);
				t.style.fontWeight = "bold";
				t.style.color = titleColor;
				container.appendChild(t);

				if (description) {
					const d = document.createElement("div");
					d.textContent = description;
					d.style.fontSize = "13px";
					d.style.color = textColor;
					d.style.opacity = "0.85";
					d.style.marginTop = "2px";
					container.appendChild(d);
				}
			}

			const isAtBottom = atBottom();

			const anchor = document.getElementById("ecmsg-" + msgId);
			if (anchor) {
				anchor.after(container);
				container.after(anchor); // keep the anchor below this embed so multiple embeds stay ordered
			} else {
				RICHTEXT.appendChild(container); // message scrolled off / not found: fall back to the bottom
			}

			if (limit > 0 && limit <= RICHTEXT.childElementCount && RICHTEXT.children[0]) {
				RICHTEXT.children[0].remove();
			}

			if (isAtBottom) {
				window.scrollTo(0, BODY.scrollHeight);
			}
		});
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
		RICHTEXT.style.fontSize = `]] .. font_size .. [[px`;
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