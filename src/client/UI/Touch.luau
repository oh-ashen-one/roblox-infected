--!strict
-- Mobile touch controls: FIRE / THROW / SPRINT / RELOAD buttons, shown only on
-- touch devices without a mouse. Role-aware (throw only shows for Patient Zero).

local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

local Touch = {}

function Touch.start(
	remotes: any,
	actions: {
		fire: () -> (),
		throwKnife: () -> (),
		melee: () -> (),
		reload: () -> (),
		setSprint: (on: boolean) -> (),
	}
)
	if not (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then
		return {}
	end

	local gui = Theme.screenGui("TouchControls", 3)
	local role = "NONE"

	local function makeButton(text: string, position: UDim2, size: number?): TextButton
		local button = Theme.button(gui, {
			Size = UDim2.new(0, size or 72, 0, size or 72),
			Position = position,
			Text = text,
			TextSize = 13,
			BackgroundTransparency = 0.35,
		})
		Theme.corner(button, (size or 72) // 2)
		return button
	end

	local fire = makeButton("FIRE", UDim2.new(1, -100, 1, -190), 84)
	local throwBtn = makeButton("THROW", UDim2.new(1, -196, 1, -150))
	local reload = makeButton("RELOAD", UDim2.new(1, -100, 1, -290))
	local sprint = makeButton("SPRINT", UDim2.new(0, 24, 1, -160))

	fire.MouseButton1Click:Connect(function()
		if role == "ZOMBIE" then
			actions.melee()
		else
			actions.fire()
		end
	end)
	throwBtn.MouseButton1Click:Connect(function()
		if role == "PATIENT_ZERO" then
			actions.throwKnife()
		else
			actions.melee()
		end
	end)
	reload.MouseButton1Click:Connect(actions.reload)

	local sprinting = false
	sprint.MouseButton1Click:Connect(function()
		sprinting = not sprinting
		actions.setSprint(sprinting)
		sprint.BackgroundColor3 = sprinting and Theme.Colors.Survivor or Theme.Colors.PanelLight
	end)

	remotes.on("RoleAssigned", function(payload)
		role = payload.role
		throwBtn.Visible = role == "PATIENT_ZERO" or role == "ZOMBIE"
		fire.Text = if role == "ZOMBIE" then "CLAW" else "FIRE"
		reload.Visible = role == "SURVIVOR" or role == "PATIENT_ZERO"
	end)

	return {}
end

return Touch
