--!strict
-- Pure XP/level curve. Level N requires cumulative XP of 100 * N^1.6 (rounded),
-- a gentle early ramp that stretches at high levels. Unit-tested.

local LevelMath = {}

function LevelMath.xpForLevel(level: number): number
	if level <= 1 then
		return 0
	end
	return math.floor(100 * (level - 1) ^ 1.6 + 0.5)
end

function LevelMath.levelForXp(xp: number): number
	if xp < 0 then
		return 1
	end
	local level = 1
	while LevelMath.xpForLevel(level + 1) <= xp do
		level += 1
	end
	return level
end

function LevelMath.progress(xp: number): (number, number, number)
	-- returns (currentLevel, xpIntoLevel, xpNeededForNext)
	local level = LevelMath.levelForXp(xp)
	local base = LevelMath.xpForLevel(level)
	local next_ = LevelMath.xpForLevel(level + 1)
	return level, xp - base, next_ - base
end

return LevelMath
