--!strict
--- Services ---
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")

--- Imports ---
local Trove = require(script.Parent.Modules.Packages.Trove)

local SelectionService = require(script.Parent.Modules.Services.SelectionService)
local SettingsService = require(script.Parent.Modules.Services.SettingsService)
local WidgetService = require(script.Parent.Modules.Services.WidgetService)

local SettingsHandler = require(script.Parent.Modules.Ui.Handlers.SettingsHandler)

--- Variables ---
local TOOLBAR_NAME = "Alignment++"
if plugin.Name:find("rbxmx") then -- Plugins installed by roblox are rbxm, whereas locally saved plugins are rbxmx (as of at least 9/9/2025).
	TOOLBAR_NAME = `{TOOLBAR_NAME} (DEV)`
end

local toolbar = plugin:CreateToolbar(TOOLBAR_NAME)
local pluginButton = toolbar:CreateButton(
	"", -- Button ID
	"", -- Tooltip
	"rbxassetid://6230678365", -- Icon
	"" -- Button name
)

local activated = false
local transitioningState = false
local lastSelectedTool: Enum.RibbonTool = Enum.RibbonTool.None
local unloadTrove = Trove.new()

--- Functions ---
local function RestoreRibbonTool()
	-- Necessary hack: https://create.roblox.com/docs/reference/engine/classes/Plugin#SelectRibbonTool
	local lastSelection = Selection:Get()
	Selection:Set({ Workspace })
	plugin:SelectRibbonTool(lastSelectedTool, UDim2.new(0, 0, 0, 0))
	Selection:Set(lastSelection)
end

local function Activate()
	if activated or transitioningState then
		return
	end

	transitioningState = true
	lastSelectedTool = plugin:GetSelectedRibbonTool()
	pluginButton:SetActive(true)
	plugin:Activate(true)
	WidgetService.Show()
	SelectionService.Start()
	activated = true
	transitioningState = false
end

local function Deactivate()
	if not activated or transitioningState then
		return
	end

	transitioningState = true
	pluginButton:SetActive(false)
	plugin:Activate(false)
	WidgetService.Hide()
	SelectionService.Stop()
	activated = false
	transitioningState = false
end

local function Unload()
	SettingsService.Unload()
	SelectionService.Unload()
	WidgetService.Unload()
	unloadTrove:Destroy()
	RestoreRibbonTool()
end

--- Alignment++ Plugin ---
do -- Load services.
	-- Initialize synchronously.
	SettingsService.Init(plugin)
	WidgetService.Init(plugin)
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

(WidgetService.Widget :: WidgetService.Widget):BindToClose(function()
	WidgetService.Hide()
	Deactivate()
	RestoreRibbonTool()
end)
unloadTrove:Add(plugin.Deactivation:Connect(Deactivate))
plugin.Unloading:Once(Unload)

unloadTrove:Add(pluginButton.Click:Connect(function()
	if activated then
		plugin:Deactivate()
		task.defer(RestoreRibbonTool)
	else
		Activate()
	end
end))

-- Enable and disable widget so it actually loads on first button click.
task.delay(1, function()
	WidgetService.Show()
	task.wait()
	WidgetService.Hide()
end)
