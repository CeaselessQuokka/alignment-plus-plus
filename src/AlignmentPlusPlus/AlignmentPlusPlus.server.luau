--!strict
-- Services --
const Selection = game:GetService("Selection")
const Workspace = game:GetService("Workspace")

-- Imports --
const Trove = require(script.Parent.Modules.Packages.Trove)

const InputService = require(script.Parent.Modules.Services.InputService)
const SelectionService = require(script.Parent.Modules.Services.SelectionService)
const SettingsService = require(script.Parent.Modules.Services.SettingsService)
const WidgetService = require(script.Parent.Modules.Services.WidgetService)

const SettingsHandler = require(script.Parent.Modules.Ui.Handlers.SettingsHandler)

-- Variables --
local TOOLBAR_NAME = "Alignment++"
if plugin.Name:find("rbxmx") then -- Plugins installed by roblox are rbxm, whereas locally saved plugins are rbxmx (as of at least 9/9/2025).
	TOOLBAR_NAME = `{TOOLBAR_NAME} (DEV)`
end

const toolbar = plugin:CreateToolbar(TOOLBAR_NAME)
const pluginButton = toolbar:CreateButton(
	"", -- Button ID
	"", -- Tooltip
	"rbxassetid://6230678365", -- Icon
	"" -- Button name
)

local activated = false
local transitioningState = false
local lastSelectedTool: Enum.RibbonTool = Enum.RibbonTool.None
const unloadTrove = Trove.new()

-- Functions --
const function RestoreRibbonTool()
	-- Necessary hack: https://create.roblox.com/docs/reference/engine/classes/Plugin#SelectRibbonTool
	const lastSelection = Selection:Get()
	Selection:Set({ Workspace })
	plugin:SelectRibbonTool(lastSelectedTool, UDim2.new(0, 0, 0, 0))
	Selection:Set(lastSelection)
end

-- Activation follows the widget rather than being tracked alongside it.
--
-- Studio can enable or disable a DockWidgetPluginGui on its own, restoring layout at startup or when the user
-- closes it, and the plugin can be deactivated out from under us when another one takes the mouse. Keeping a
-- separate flag in step with all of that is what made the panel sometimes need the toolbar button pressed
-- three times: the flag said it was open while the widget disagreed, so the next press closed it again.
const function Activate()
	if activated or transitioningState then
		return
	end

	transitioningState = true
	lastSelectedTool = plugin:GetSelectedRibbonTool()
	pluginButton:SetActive(true)
	plugin:Activate(true)
	InputService.Start()
	SelectionService.Start()
	activated = true
	transitioningState = false
end

const function Deactivate()
	if not activated or transitioningState then
		return
	end

	transitioningState = true
	pluginButton:SetActive(false)
	plugin:Activate(false)
	SelectionService.Stop()
	InputService.Stop()
	activated = false
	transitioningState = false
end

const function Unload()
	SettingsService.Unload()
	SelectionService.Unload()
	InputService.Unload()
	WidgetService.Unload()
	unloadTrove:Destroy()
	RestoreRibbonTool()
end

-- Alignment++ Plugin --
do -- Load services.
	-- Initialize synchronously.
	SettingsService.Init(plugin)
	WidgetService.Init(plugin)
	InputService.Init()
	SelectionService.Init(plugin)

	-- Start synchronously.
	SettingsService.Start()
	WidgetService.Start()
end

do -- Load handlers.
	-- Initialize synchronously.
	SettingsHandler.Init()

	-- Start synchronously.
	SettingsHandler.Start()
end

do -- Load components.
	require(script.Parent.Modules.Ui.Components.RadioButtonSetting)
	require(script.Parent.Modules.Ui.Components.SwitchSetting)
	require(script.Parent.Modules.Ui.Components.CategoryUi)
	require(script.Parent.Modules.Ui.Components.SelectionUi)
end

const widget = WidgetService.Widget :: WidgetService.Widget

-- The widget's own enabled state is the single source of truth for whether the plugin is running.
unloadTrove:Add(widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	if widget.Enabled then
		Activate()
	else
		Deactivate()
		RestoreRibbonTool()
	end
end))

widget:BindToClose(function()
	WidgetService.Hide()
end)

-- Losing the mouse to another plugin closes the panel, which then runs the deactivation above.
unloadTrove:Add(plugin.Deactivation:Connect(function()
	WidgetService.Hide()
end))
plugin.Unloading:Once(Unload)

-- The button only ever toggles the widget; everything else follows from that.
unloadTrove:Add(pluginButton.Click:Connect(function()
	WidgetService.SetShown(not widget.Enabled)
end))
