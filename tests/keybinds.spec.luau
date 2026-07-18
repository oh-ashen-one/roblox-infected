-- Keybind resolution tests (pure part). Run with: lune run tests/run
local Keybinds = require("../src/shared/Keybinds")

local tests = {}

function tests.defaults_exist_for_every_ordered_action()
	for _, action in Keybinds.Order do
		assert(Keybinds.Defaults[action] ~= nil, action .. " has a default")
		assert(Keybinds.Labels[action] ~= nil, action .. " has a label")
	end
end

function tests.resolve_falls_back_to_default()
	assert(Keybinds.resolve("sprint", nil) == "LeftShift")
	assert(Keybinds.resolve("reload", {}) == "R")
end

function tests.resolve_prefers_override()
	assert(Keybinds.resolve("sprint", { sprint = "C" }) == "C")
	-- an override for one action doesn't affect another
	assert(Keybinds.resolve("reload", { sprint = "C" }) == "R")
end

function tests.unknown_action_resolves_nil()
	assert(Keybinds.resolve("nonsense", nil) == nil)
end

return tests
