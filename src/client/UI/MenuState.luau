--!strict
-- Tracks whether any full-screen menu panel (shop, settings, quests, season, leaderboard)
-- is open, so the camera knows when to release the locked mouse and let you click things.
--
-- Panels register once with `track(panel)`; visibility is observed rather than pushed, so a
-- module never has to remember to tell us it closed.

local MenuState = {}

local openPanels: { [Instance]: true } = {}
local listeners: { (boolean) -> () } = {}

local function anyOpen(): boolean
	return next(openPanels) ~= nil
end

local function notify()
	local open = anyOpen()
	for _, fn in listeners do
		task.spawn(fn, open)
	end
end

-- Watch a panel's Visible property for as long as it exists.
function MenuState.track(panel: GuiObject)
	local function sync()
		if panel.Visible then
			openPanels[panel] = true
		else
			openPanels[panel] = nil
		end
		notify()
	end
	panel:GetPropertyChangedSignal("Visible"):Connect(sync)
	panel.Destroying:Connect(function()
		openPanels[panel] = nil
		notify()
	end)
	sync()
end

function MenuState.isOpen(): boolean
	return anyOpen()
end

function MenuState.onChanged(fn: (boolean) -> ())
	table.insert(listeners, fn)
	task.spawn(fn, anyOpen())
end

return MenuState
