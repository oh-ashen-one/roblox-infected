-- Tiny test runner for Lune: requires every *.spec.luau sibling and runs each function.
-- Usage: lune run tests/run
local fs = require("@lune/fs")
local process = require("@lune/process")

local specs = {}
for _, entry in fs.readDir("tests") do
	local name = entry:match("^(.*)%.spec%.luau$")
	if name then
		table.insert(specs, name)
	end
end
table.sort(specs)

local passed, failed = 0, 0
for _, name in specs do
	local suite = require("./" .. name .. ".spec")
	local keys = {}
	for testName in suite do
		table.insert(keys, testName)
	end
	table.sort(keys)
	for _, testName in keys do
		local ok, err = pcall(suite[testName])
		if ok then
			passed += 1
		else
			failed += 1
			print(("FAIL %s/%s: %s"):format(name, testName, tostring(err)))
		end
	end
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	process.exit(1)
end
