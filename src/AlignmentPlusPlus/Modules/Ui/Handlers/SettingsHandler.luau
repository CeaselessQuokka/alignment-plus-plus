--!strict
-- Imports --
const SettingsService = require(script.Parent.Parent.Parent.Services.SettingsService)
const WidgetService = require(script.Parent.Parent.Parent.Services.WidgetService)

-- Types --
export type RadioGroup = string
type SettingName = SettingsService.SettingName

-- Settings Handler --
const SettingsHandler = {
	-- Boilerplate
	Initialized = false,
	Started = false,

	-- Handler Specific
	_radioButtons = {} :: { [RadioGroup]: { Default: SettingName?, Buttons: { SettingName } } },
	_widget = nil :: WidgetService.Widget,
}
const self = SettingsHandler

function SettingsHandler.Init()
	assert(not SettingsHandler.Initialized, `{script.Name} was already initialized`)

	self._widget = WidgetService.Widget :: WidgetService.Widget
	self.Initialized = true
end

function SettingsHandler.Start()
	assert(self.Initialized, `{script.Name} was not initialized`)
	assert(not self.Started, `{script.Name} was already started`)

	self.HideTooltip()
	self.Started = true
end

function SettingsHandler.Stop()
	assert(self.Started, `{script.Name} was not started`)

	self.Started = false
end

function SettingsHandler.RegisterRadioButton(name: SettingName, group: RadioGroup, isDefaultInGroup: boolean)
	local groupData = self._radioButtons[group]
	if not groupData then
		groupData = {
			Default = nil,
			Buttons = {},
		}
		self._radioButtons[group] = groupData
	end
	groupData.Default = if isDefaultInGroup then name else groupData.Default
	table.insert(groupData.Buttons, name)
end

-- Selects one button in a group and clears the rest. Selecting the button that is already active does nothing,
-- since a radio group always has to have exactly one thing chosen.
function SettingsHandler.UpdateRadioSelection(name: SettingName, group: RadioGroup)
	if SettingsService.Get(name) then
		return
	end

	const groupData = self._radioButtons[group]
	for _, buttonName: SettingName in groupData.Buttons do
		if buttonName ~= name then
			SettingsService.Set(buttonName, false)
		end
	end
	SettingsService.Set(name, true)
end

function SettingsHandler.ToggleTooltip(tip: string)
	if tip == self._widget.Main.Tooltip.Scroller.Tip.Text then
		self.HideTooltip()
	else
		self.ShowTooltip(tip)
	end
end

function SettingsHandler.ShowTooltip(tip: string)
	const tooltip = self._widget.Main.Tooltip
	tooltip.Visible = true
	tooltip.Scroller.Tip.Text = tip
end

function SettingsHandler.HideTooltip()
	const tooltip = self._widget.Main.Tooltip
	tooltip.Visible = false
	tooltip.Scroller.Tip.Text = ""
end

return SettingsHandler
