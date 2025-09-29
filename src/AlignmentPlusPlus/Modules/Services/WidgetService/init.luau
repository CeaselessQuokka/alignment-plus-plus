--!strict
--- Imports ---
local Trove = require(script.Parent.Parent.Packages.Trove)

local ThemeHelper = require(script.Parent.Parent.Helpers.ThemeHelper)

local WidgetTypes = require(script.WidgetTypes)

--- Types ---
export type Widget = DockWidgetPluginGui & {
	Sounds: Folder,
	Main: WidgetTypes.Ui,
}

--- Widget Service ---
local WidgetService = {
	--- Boilerplate
	Initialized = false,
	Started = false,
	_trove = Trove.new(),
	_plugin = nil :: Plugin?,

	--- Service Specific
	Widget = nil :: Widget?,
}
local self = WidgetService

function WidgetService.Init(plugin: Plugin)
	assert(not self.Initialized, `{script.Name} was already initialized`)

	-- Create widget.
	local widget = plugin:CreateDockWidgetPluginGui(
		"QDT_AlignmentPlusPlus",
		DockWidgetPluginGuiInfo.new(
			Enum.InitialDockState.Float, -- Initial dock state
			false, -- Initial enabled state
			true, -- Override initial enabled state
			350, -- Initial width
			300, -- Initial height
			200, -- Minimum width
			125 -- Minimum height
		)
	) :: Widget
	widget.Name = "AlignmentPlusPlus"
	widget.Title = "Alignment++ (Part/Model Aligner w/ Resize)"
	widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	script.Parent.Parent.Parent.Assets.Ui.Main.Parent = widget
	ThemeHelper.ApplyCurrentTheme(widget.Main)

	-- Update theme on change.
	self._trove:Add(ThemeHelper.OnThemeChanged:Connect(function()
		ThemeHelper.ApplyCurrentTheme(widget.Main)
	end))

	-- Move sounds to widget so they are playable.
	script.Parent.Parent.Parent.Assets.Sounds.Parent = widget

	-- Close tooltip.
	self._trove:Add(widget.Main.Tooltip.Close.Activated:Connect(function()
		widget.Main.Tooltip.Visible = false
		widget.Main.Tooltip.Scroller.Tip.Text = ""
	end))

	-- Update service state.
	self.Widget = widget
	self._plugin = plugin
	self.Initialized = true
end

function WidgetService.Start()
	assert(self.Initialized, `{script.Name} was not initialized`)
	assert(not self.Started, `{script.Name} was already started`)

	-- Update service state.
	self.Started = true
end

function WidgetService.Stop()
	assert(self.Started, `{script.Name} was not started`)

	self._trove:Clean()
	self.Started = false
end

function WidgetService.Unload()
	pcall(self.Stop)
	if self.Widget then
		self.Widget:ClearAllChildren()
		self.Widget = nil
	end
end

function WidgetService.Show()
	(self.Widget :: Widget).Enabled = true
end

function WidgetService.Hide()
	(self.Widget :: Widget).Enabled = false
end

function WidgetService.PlaySound(soundName: string)
	local sound = (self.Widget :: Widget).Sounds:FindFirstChild(soundName) :: Sound?
	assert(sound, `Sound '{soundName}' does not exist`)

	sound:Play()
end

return WidgetService
