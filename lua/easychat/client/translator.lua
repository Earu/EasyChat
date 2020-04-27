local translator = {
	OnGoing = {},
	CurrentID = 1
}

local function create_translation_panel()
	local tr_panel = vgui.Create("DHTML")
	tr_panel:SetHTML("<html><head></head><body></body></html>")
	tr_panel:SetAllowLua(true)
	tr_panel:AddFunction("Translate", "Print", print)
	tr_panel:AddFunction("Translate", "Callback", function(id, success, json)
		local callback = self.OnGoing[id]
		if not callback then return end

		if not success then
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
		callback(true, source, translation)
		self.OnGoing[id] = nil
	end)

	tr_panel:QueueJavascript([[
	function TranslateRequest(url, id) {
		var request = new XMLHttpRequest();
		request.open("GET", url);
		request.send();

		request.onreadystatechange = function() {
			if (this.readyState == 4) {
				Translate.Callback(id, this.status == 200, request.responseText);
			}
		}
	}]])

	return tr_panel
end

function translator:Initialize()
	self.Panel = create_translation_panel()
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
	if not IsValid(self.Panel) then
		self.Panel = create_translation_panel()
	end

	self.OnGoing[self.CurrentID] = on_finish

	local url = ("https://translate.googleapis.com/translate_a/single?client=gtx&sl=%s&tl=%s&dt=t&q=%s")
		:format(source_lang, target_lang, text)
	self.Panel:QueueJavascript(("TranslateRequest(%q,%d);"):format(url, self.CurrentID))

	self.CurrentID = self.CurrentID + 1
end

return translator