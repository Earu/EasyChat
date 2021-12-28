-- this module is a hack for fixing the following issue:
-- https://github.com/Earu/EasyChat/issues/79
-- https://github.com/thegrb93/StarfallEx/issues/1232
-- thanks for nothing thegrb93

local TAG = "EasyChatModuleSFCompat"

local function is_starfall()
	return _G.SF ~= nil and _G.SF.runningOps ~= nil and _G.SF.SafeStringLib ~= nil
end

local previous_ops_state = false
hook.Add("ECPreAddText", TAG, function()
	if not is_starfall() then return end
	previous_ops_state = _G.SF.runningOps
	_G.SF.runningOps = false
end)

hook.Add("ECPostAddText", TAG, function()
	if not is_starfall() then return end
	_G.SF.runningOps = previous_ops_state
end)

return "SF Compat"