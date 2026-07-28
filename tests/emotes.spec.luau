-- Emote catalog tests. Run with: lune run tests/run
local Emotes = require("../src/shared/Emotes")

local tests = {}

function tests.catalog_is_well_formed()
	assert(#Emotes.Catalog > 0)
	local seenIds, seenAnimations = {}, {}
	for _, emote in Emotes.Catalog do
		assert(type(emote.id) == "string" and #emote.id > 0, "emote needs an id")
		assert(type(emote.label) == "string" and #emote.label > 0, emote.id .. " needs a label")
		assert(emote.animationId > 0, emote.id .. " needs an animation id")
		assert(emote.duration > 0, emote.id .. " needs a duration")
		assert(seenIds[emote.id] == nil, "duplicate emote id " .. emote.id)
		assert(seenAnimations[emote.animationId] == nil, "duplicate animation id for " .. emote.id)
		seenIds[emote.id] = true
		seenAnimations[emote.animationId] = true
	end
end

function tests.lookup_finds_every_catalog_entry()
	for _, emote in Emotes.Catalog do
		local found = Emotes.byId(emote.id)
		assert(found ~= nil, emote.id .. " is not findable")
		assert((found :: any).animationId == emote.animationId)
	end
end

function tests.lookup_rejects_unknown_ids()
	assert(Emotes.byId("nonsense") == nil)
	assert(Emotes.byId("") == nil)
end

function tests.ids_matches_the_catalog()
	local ids = Emotes.ids()
	assert(#ids == #Emotes.Catalog)
	for _, id in ids do
		assert(Emotes.byId(id) ~= nil)
	end
end

function tests.the_hidden_patient_zero_can_emote()
	-- The whole point: blending in means doing what survivors do.
	assert(Emotes.canPlay("PATIENT_ZERO"), "the hidden PZ must be able to bluff")
	assert(Emotes.canPlay("SURVIVOR"))
end

function tests.revealed_zombies_cannot_emote()
	assert(not Emotes.canPlay("ZOMBIE"))
	assert(not Emotes.canPlay("NONE"))
	assert(not Emotes.canPlay("SPECTATOR"))
end

return tests
