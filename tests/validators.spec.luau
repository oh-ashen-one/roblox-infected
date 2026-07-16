-- Remote payload validator tests. Run with: lune run tests/run
-- Vector3 validators are exercised in Studio playtests (Lune lacks Roblox Vector3 globals);
-- everything else is covered here.
local Validators = require("../src/shared/Validators")

local tests = {}

function tests.number_rejects_nan_inf_and_bounds()
	local v = Validators.number(0, 10)
	assert(v(5) and v(0) and v(10))
	assert(not v(-1) and not v(11))
	assert(not v(0 / 0), "NaN must fail")
	assert(not v(math.huge) and not v(-math.huge))
	assert(not v("5") and not v(nil) and not v(true))
end

function tests.integer_rejects_fractions()
	local v = Validators.integer(1)
	assert(v(1) and v(42))
	assert(not v(1.5) and not v(0) and not v("3"))
end

function tests.str_enforces_max_len()
	local v = Validators.str(3)
	assert(v("abc") and v(""))
	assert(not v("abcd") and not v(3) and not v(nil))
end

function tests.oneOf_is_exact()
	local v = Validators.oneOf({ "a", "b" })
	assert(v("a") and v("b"))
	assert(not v("c") and not v("A") and not v(1) and not v(nil))
end

function tests.shape_rejects_missing_and_unknown_keys()
	local v = Validators.shape({ x = Validators.number(), name = Validators.str(10) })
	assert(v({ x = 1, name = "ok" }))
	assert(not v({ x = 1 }), "missing key must fail")
	assert(not v({ x = 1, name = "ok", extra = true }), "unknown key must fail")
	assert(not v("not a table") and not v(nil))
end

function tests.optional_allows_nil_inside_shape()
	local v = Validators.shape({ x = Validators.optional(Validators.number()) })
	assert(v({}), "optional field may be absent")
	assert(v({ x = 3 }))
	assert(not v({ x = "no" }))
end

return tests
