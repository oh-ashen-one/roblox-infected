--!strict
-- Shared UI construction helpers + palette. One consistent visual language.

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = {
	Bg = Color3.fromRGB(18, 18, 22),
	Panel = Color3.fromRGB(28, 28, 34),
	PanelLight = Color3.fromRGB(40, 40, 48),
	Text = Color3.fromRGB(235, 235, 240),
	TextDim = Color3.fromRGB(160, 160, 170),
	Infected = Color3.fromRGB(110, 220, 80),
	Survivor = Color3.fromRGB(90, 170, 255),
	Danger = Color3.fromRGB(230, 70, 70),
	Gold = Color3.fromRGB(245, 195, 70),
}

Theme.Font = Enum.Font.GothamBold
Theme.FontLight = Enum.Font.Gotham

function Theme.frame(parent: Instance, props: { [string]: any }): Frame
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Theme.Colors.Panel
	for k, v in props do
		(frame :: any)[k] = v
	end
	frame.Parent = parent
	return frame
end

function Theme.corner(instance: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = instance
end

function Theme.label(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BorderSizePixel = 0
	label.BackgroundTransparency = 1
	label.Font = Theme.Font
	label.TextColor3 = Theme.Colors.Text
	label.TextScaled = false
	label.TextSize = 16
	for k, v in props do
		(label :: any)[k] = v
	end
	label.Parent = parent
	return label
end

function Theme.button(parent: Instance, props: { [string]: any }): TextButton
	local button = Instance.new("TextButton")
	button.BorderSizePixel = 0
	button.BackgroundColor3 = Theme.Colors.PanelLight
	button.Font = Theme.Font
	button.TextColor3 = Theme.Colors.Text
	button.TextSize = 16
	button.AutoButtonColor = true
	for k, v in props do
		(button :: any)[k] = v
	end
	button.Parent = parent
	Theme.corner(button)
	return button
end

function Theme.fadeIn(instance: GuiObject, duration: number?)
	instance.Visible = true
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = instance.BackgroundTransparency }
	)
	tween:Play()
end

function Theme.screenGui(name: string, displayOrder: number?): ScreenGui
	local Players = game:GetService("Players")
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = displayOrder or 1
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

return Theme
