--!strict
-- Sound playback driven by remotes. Every id lives in GameConfig.Sounds; an id of 0
-- means "not configured yet" and is skipped, so this is safe before the audio pass.

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)

local Sounds = {}

local function play(name: string, looped: boolean?): Sound?
	local id = (GameConfig.Sounds :: any)[name]
	if id == nil or id == 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = `rbxassetid://{id}`
	sound.Volume = SoundService:GetAttribute("MasterVolume") :: number? or 0.5
	sound.Looped = looped == true
	sound.Parent = SoundService
	sound:Play()
	if not sound.Looped then
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
	return sound
end

function Sounds.start(remotes: any)
	local heartbeat: Sound? = nil
	local lobbyMusic: Sound? = nil

	remotes.on("ShotFired", function()
		play("GunShot")
	end)
	remotes.on("KnifeThrown", function()
		play("KnifeThrow")
	end)
	remotes.on("ConversionAlert", function()
		play("Conversion")
	end)
	remotes.on("SurvivorPing", function()
		if heartbeat == nil then
			heartbeat = play("Heartbeat", true)
			task.delay(20, function()
				if heartbeat then
					heartbeat:Destroy()
					heartbeat = nil
				end
			end)
		end
	end)
	remotes.on("RevealScreen", function(payload)
		if heartbeat then
			heartbeat:Destroy()
			heartbeat = nil
		end
		play(payload.winner == "SURVIVORS" and "SurvivorsWin" or "InfectedWin")
	end)
	remotes.on("RoundState", function(state)
		if state.state == "ACTIVE" then
			if lobbyMusic then
				lobbyMusic:Destroy()
				lobbyMusic = nil
			end
			play("RoundStart")
		elseif state.state == "INTERMISSION" and lobbyMusic == nil then
			lobbyMusic = play("LobbyMusic", true)
		end
	end)

	return {}
end

return Sounds
