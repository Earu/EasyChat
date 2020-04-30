local cached_translations = {}

local translator = {
	OnGoing = {},
	CurrentID = 1
}

local red_col = Color(255, 0, 0)
local function create_translation_panel(self)
	local tr_panel = vgui.Create("DHTML")
	tr_panel:SetHTML("<html><head></head><body></body></html>")
	tr_panel:SetAllowLua(true)
	tr_panel:AddFunction("Translate", "Print", print)
	tr_panel:AddFunction("Translate", "Callback", function(id, status, json, target_lang)
		local callback = self.OnGoing[id]
		if not callback then return end

		if status ~= 200 then
			if status == 429 then
				chat.AddText(red_col, "[WARN] It seems that you have been blocked from using the translation service for a while.")
				chat.AddText(red_col, "This is most likely the result of spam. Disabling translation to prevent a longer waiting time.")
				self.Disabled = true
			end

			callback(false)
			self.OnGoing[id] = nil
			return
		end

		local data = util.JSONToTable(json)
		if not data then
			callback(false)
			self.OnGoing[id] = nil
			return
		end

		local translation, source = data[1][1][1], data[1][1][2]

		cached_translations[source] = cached_translations[source] or {}
		cached_translations[source][target_lang] = translation

		callback(true, source, translation)
		self.OnGoing[id] = nil
	end)

	tr_panel:QueueJavascript([[
	function TranslateRequest(url, id, targetLang) {
		var request = new XMLHttpRequest();
		request.open("GET", url);
		request.send();

		request.onerror = function() {
			Translate.Callback(id, 0);
		};

		request.onreadystatechange = function() {
			if (this.readyState == 4) {
				Translate.Callback(id, this.status, request.responseText, targetLang);
			}
		};
	}]])

	return tr_panel
end

function translator:Initialize()
	self.Panel = create_translation_panel(self)
	self.OnGoing = {}
	self.CurrentID = 1
end

function translator:Destroy()
	if IsValid(self.Panel) then
		self.Panel:Remove()
	end

	for id, callback in pairs(self.OnGoing) do
		callback(false)
		self.OnGoing[id] = nil
	end

	self.CurrentID = 1
end

function translator:Translate(text, source_lang, target_lang, on_finish)
	if cached_translations[text] and cached_translations[text][target_lang] then
		on_finish(true, text, cached_translations[text][target_lang])
		return
	end

	if self.Disabled then
		on_finish(false)
		return
	end

	if not IsValid(self.Panel) then
		self.Panel = create_translation_panel(self)
	end

	self.OnGoing[self.CurrentID] = on_finish

	local url = ("https://translate.googleapis.com/translate_a/single?client=gtx&sl=%s&tl=%s&dt=t&q=%s")
		:format(source_lang, target_lang, text)
	self.Panel:QueueJavascript(("TranslateRequest(%q,%d,%q);"):format(url, self.CurrentID, target_lang))

	self.CurrentID = self.CurrentID + 1
end

return translator