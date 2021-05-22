local expr_env = {
	PI = math.pi,
	pi = math.pi,
	rand = math.random,
	random = math.random,
	randx = function(a,b)
		a = a or -1
		b = b or 1
		return math.Rand(a, b)
	end,

	abs = math.abs,
	sgn = function (x)
		if x < 0 then return -1 end
		if x > 0 then return  1 end
		return 0
	end,

	pwm = function(offset, w)
		w = w or 0.5
		return offset % 1 > w and 1 or 0
	end,

	square = function(x)
		x = math.sin(x)

		if x < 0 then return -1 end
		if x > 0 then return  1 end

		return 0
	end,

	acos = math.acos,
	asin = math.asin,
	atan = math.atan,
	atan2 = math.atan2,
	ceil = math.ceil,
	cos = math.cos,
	cosh = math.cosh,
	deg = math.deg,
	exp = math.exp,
	floor = math.floor,
	frexp = math.frexp,
	ldexp = math.ldexp,
	log = math.log,
	log10 = math.log10,
	max = math.max,
	min = math.min,
	rad = math.rad,
	sin = math.sin,
	sinc = function (x)
		if x == 0 then return 1 end
		return math.sin(x) / x
	end,
	sinh = math.sinh,
	sqrt = math.sqrt,
	tanh = math.tanh,
	tan = math.tan,

	clamp = math.Clamp,
	pow = math.pow,
}

local blacklist = { "repeat", "until", "function", "end", "\"", "\'", "%[=*%[", "%]=*%]", ":" }

local function compile_expression(str)
	if not str or str:Trim() == "" then return false, "nil or empty expression" end

	for _, word in pairs(blacklist) do
		if str:find("[%p%s]" .. word) or str:find(word .. "[%p%s]") then
			return false, ("illegal characters used %q"):format(word)
		end
	end

	local functions = {}

	for k,v in pairs(expr_env) do functions[k] = v end

	functions.select = select

	local start_time = os.clock()
	functions.t = function() return os.clock() - start_time end
	functions.time = function() return os.clock() - start_time end

	str = "local IN = select(1, ...) return " .. str

	local func = CompileString(str, "easychat_expression", false)
	if isstring(func) then
		return false, func
	end

	setfenv(func, functions)
	return true, func
end

return { Compile = compile_expression }