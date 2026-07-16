--!strict
-- End-of-round reveal: winner banner, the unmasked Patient Zero, survivor list,
-- your coin earnings.

local Theme = require(script.Parent.Theme)

local RevealScreen = {}

function RevealScreen.start(remotes: any)
	local Players = game:GetService("Players")
	local gui = Theme.screenGui("RevealScreen", 6)

	local overlay = Theme.frame(gui, {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Visible = false,
	})

	local panel = Theme.frame(overlay, {
		Size = UDim2.new(0, 520, 0, 320),
		Position = UDim2.new(0.5, -260, 0.5, -160),
		BackgroundTransparency = 0.05,
	})
	Theme.corner(panel, 16)

	local winnerLabel = Theme.label(panel, {
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.new(0, 0, 0, 18),
		Text = "",
		TextSize = 32,
	})
	local pzLabel = Theme.label(panel, {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 74),
		Text = "",
		TextSize = 18,
		TextColor3 = Theme.Colors.Infected,
	})
	local survivorsLabel = Theme.label(panel, {
		Size = UDim2.new(1, -60, 0, 120),
		Position = UDim2.new(0, 30, 0, 116),
		Text = "",
		TextSize = 15,
		Font = Theme.FontLight,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Theme.Colors.TextDim,
	})
	local earningsLabel = Theme.label(panel, {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 1, -46),
		Text = "",
		TextSize = 17,
		TextColor3 = Theme.Colors.Gold,
	})

	remotes.on("RevealScreen", function(payload)
		if payload.winner == "SURVIVORS" then
			winnerLabel.Text = "SURVIVORS WIN"
			winnerLabel.TextColor3 = Theme.Colors.Survivor
		elseif payload.winner == "INFECTED" then
			winnerLabel.Text = "THE INFECTION WINS"
			winnerLabel.TextColor3 = Theme.Colors.Infected
		else
			winnerLabel.Text = "ROUND OVER"
			winnerLabel.TextColor3 = Theme.Colors.Text
		end
		pzLabel.Text = ("Patient Zero was: %s"):format(payload.patientZeroName or "?")
		local survivors = payload.survivors or {}
		if #survivors > 0 then
			survivorsLabel.Text = "Survived: " .. table.concat(survivors, ", ")
		else
			survivorsLabel.Text = "Nobody survived."
		end
		local myEarnings = payload.earnings and payload.earnings[tostring(Players.LocalPlayer.UserId)]
		earningsLabel.Text = myEarnings and ("+%d coins this round"):format(myEarnings) or ""
		overlay.Visible = true
	end)

	remotes.on("RoundState", function(state)
		if state.state ~= "ROUND_END" then
			overlay.Visible = false
		end
	end)

	return {}
end

return RevealScreen
