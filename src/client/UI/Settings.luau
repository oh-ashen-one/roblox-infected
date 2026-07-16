--!strict
-- Settings panel: FOV, music/SFX volume, gore (conversion VFX) toggle.
-- Persists locally via player attributes for the session.

local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local Theme = require(script.Parent.Theme)

local Settings = {}

function Settings.start()
	local gui = Theme.screenGui("Settings", 4)

	local toggle = Theme.button(gui, {
		Size = UDim2.new(0, 90, 0, 36),
		Position = UDim2.new(0, 12, 0, 108),
		Text = "SETTINGS",
		TextSize = 13,
	})

	local panel = Theme.frame(gui, {
		Size = UDim2.new(0, 300, 0, 230),
		Position = UDim2.new(0.5, -150, 0.5, -115),
		BackgroundTransparency = 0.05,
		Visible = false,
	})
	Theme.corner(panel, 14)
	Theme.label(panel, {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 8),
		Text = "SETTINGS",
		TextSize = 18,
	})

	local function sliderRow(
		order: number,
		labelText: string,
		initial: number,
		onChange: (value: number) -> ()
	)
		local y = 44 + (order - 1) * 56
		Theme.label(panel, {
			Size = UDim2.new(1, -32, 0, 18),
			Position = UDim2.new(0, 16, 0, y),
			Text = labelText,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.Colors.TextDim,
		})
		local bar = Theme.frame(panel, {
			Size = UDim2.new(1, -32, 0, 10),
			Position = UDim2.new(0, 16, 0, y + 24),
			BackgroundColor3 = Theme.Colors.PanelLight,
		})
		Theme.corner(bar, 5)
		local fill = Theme.frame(bar, {
			Size = UDim2.new(initial, 0, 1, 0),
			BackgroundColor3 = Theme.Colors.Survivor,
		})
		Theme.corner(fill, 5)
		local dragging = false
		local function setFromX(x: number)
			local fraction = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
			fill.Size = UDim2.new(fraction, 0, 1, 0)
			onChange(fraction)
		end
		bar.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = true
				setFromX(input.Position.X)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = false
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				setFromX(input.Position.X)
			end
		end)
	end

	sliderRow(1, "FIELD OF VIEW", 0.5, function(fraction)
		local camera = workspace.CurrentCamera
		if camera then
			camera.FieldOfView = 60 + fraction * 40 -- 60..100
		end
	end)
	sliderRow(2, "VOLUME", 0.5, function(fraction)
		SoundService:SetAttribute("MasterVolume", fraction)
		for _, sound in SoundService:GetDescendants() do
			if sound:IsA("Sound") then
				sound.Volume = fraction
			end
		end
	end)

	local goreButton = Theme.button(panel, {
		Size = UDim2.new(1, -32, 0, 34),
		Position = UDim2.new(0, 16, 0, 158),
		Text = "INFECTION VFX: ON",
		TextSize = 13,
	})
	local goreOn = true
	goreButton.MouseButton1Click:Connect(function()
		goreOn = not goreOn
		goreButton.Text = goreOn and "INFECTION VFX: ON" or "INFECTION VFX: OFF"
		game:GetService("Players").LocalPlayer:SetAttribute("GoreEnabled", goreOn)
	end)

	local close = Theme.button(panel, {
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(1, -40, 0, 8),
		Text = "X",
	})
	toggle.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
	end)
	close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	return {}
end

return Settings
