--!strict
--- Imports ---
local Component = require(script.Parent.Parent.Parent.Packages.Component)
local Trove = require(script.Parent.Parent.Parent.Packages.Trove)
local t = require(script.Parent.Parent.Parent.Packages.t)

local SettingsService = require(script.Parent.Parent.Parent.Services.SettingsService)
local WidgetService = require(script.Parent.Parent.Parent.Services.WidgetService)

local SettingsHandler = require(script.Parent.Parent.Handlers.SettingsHandler)

local AttributeHelper = require(script.Parent.Parent.Parent.Helpers.AttributeHelper)
local ThemeHelper = require(script.Parent.Parent.Parent.Helpers.ThemeHelper)

local HierarchyIs = require(script.Parent.Parent.Parent.ComponentExtensions.HierarchyIs)

--- Types ---
export type ComponentInstance = GuiObject & {
	HelpButton: ImageButton,
	RadioButton: ImageButton & {
		Tick: Frame,
	},
	SettingName: TextLabel,
}

export type Component = {
	Instance: ComponentInstance,
	_trove: Trove.Trove,

	_settingName: SettingName,
	_settingDescription: string,
	_radioGroup: SettingsHandler.RadioGroup,
	_isDefaultInRadioGroup: boolean?,
	_dimIfEnabled: { [SettingName]: boolean },
	_dimIfDisabled: { [SettingName]: boolean },

	_Update: (self: Component) -> (),
	_UpdateDimming: (self: Component) -> (),
}

type SettingName = SettingsService.SettingName

--- Radio Button Component ---
local RadioButtonSetting = Component.new({
	Tag = "RadioButtonSetting",
	Ancestors = { (WidgetService.Widget :: any) :: Instance },
	Extensions = {
		HierarchyIs({
			IsA = "GuiObject",
			Children = {
				HelpButton = {
					IsA = "GuiButton",
				},
				RadioButton = {
					IsA = "GuiButton",
					Children = {
						Tick = {
							IsA = "GuiObject",
						},
					},
				},
				SettingName = {
					Class = "TextLabel",
				},
			},
		}),
	} :: any,
})

local tSettingName = t.keyOf(SettingsService._settings)
function RadioButtonSetting.Construct(self: Component)
	self._trove = Trove.new()

	assert(tSettingName(self.Instance.Name), `Invalid Setting name, got "{self.Instance.Name}"`)
	self._settingName = self.Instance.Name :: SettingName
	self._settingDescription = AttributeHelper.Get(self.Instance, "SettingDescription", t.string) :: string
	self._radioGroup = AttributeHelper.Get(self.Instance, "RadioGroup", t.string) :: SettingsHandler.RadioGroup
	self._isDefaultInRadioGroup =
		AttributeHelper.Get(self.Instance, "IsDefaultInRadioGroup", t.optional(t.boolean)) :: boolean?
	self._dimIfEnabled =
		AttributeHelper.GetAsSet(self.Instance, "DimIfEnabled", tSettingName) :: { [SettingName]: boolean }
	self._dimIfDisabled =
		AttributeHelper.GetAsSet(self.Instance, "DimIfDisabled", tSettingName) :: { [SettingName]: boolean }
end

function RadioButtonSetting.Start(self: Component)
	-- Handle updating colors based off theme change.
	self._trove:Add(ThemeHelper.OnThemeChanged:Connect(function()
		self:_UpdateDimming()
	end))

	-- Handle tooltip functionality.
	self._trove:Add(self.Instance.HelpButton.Activated:Connect(function()
		SettingsHandler.ToggleTooltip(self._settingDescription)
	end))

	-- Handle radio button functionality.
	self._trove:Add(self.Instance.RadioButton.Activated:Connect(function()
		local settingValue = not SettingsService.Get(self._settingName)
		SettingsHandler.UpdateRadioSelection(self._settingName, settingValue, self._radioGroup)
		WidgetService.PlaySound("RadioButtonToggleSound")
	end))
	task.defer(self._Update, self)

	-- Handle dimming functionality and radio button visual.
	self._trove:Add(SettingsService.OnSettingChanged:Connect(function(settingName)
		if self._dimIfEnabled[settingName] or self._dimIfDisabled[settingName] then
			self:_UpdateDimming()
		end

		if settingName == self._settingName then
			self:_Update()
		end
	end))
	task.defer(self._UpdateDimming, self)

	-- Register with SettingsHandler to facilitate radio group functionality.
	SettingsHandler.RegisterRadioButton(self._settingName, self._radioGroup, self._isDefaultInRadioGroup == true)
end

function RadioButtonSetting.Stop(self: Component)
	self._trove:Destroy()
end

function RadioButtonSetting._Update(self: Component)
	self.Instance.RadioButton.Tick.Visible = SettingsService.Get(self._settingName) :: boolean
end

function RadioButtonSetting._UpdateDimming(self: Component)
	for settingName: SettingName in self._dimIfEnabled do
		if SettingsService.Get(settingName) then
			self.Instance.SettingName.TextColor3 = ThemeHelper.GetColor(Enum.StudioStyleGuideColor.DimmedText)
			return
		end
	end

	for settingName: SettingName in self._dimIfDisabled do
		if not SettingsService.Get(settingName) then
			self.Instance.SettingName.TextColor3 = ThemeHelper.GetColor(Enum.StudioStyleGuideColor.DimmedText)
			return
		end
	end

	self.Instance.SettingName.TextColor3 = ThemeHelper.GetColor(Enum.StudioStyleGuideColor.MainText)
end

return RadioButtonSetting
