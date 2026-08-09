--!strict
-- Imports --
const Component = require(script.Parent.Parent.Parent.Packages.Component)
const Trove = require(script.Parent.Parent.Parent.Packages.Trove)
const t = require(script.Parent.Parent.Parent.Packages.t)

const SettingsService = require(script.Parent.Parent.Parent.Services.SettingsService)
const WidgetService = require(script.Parent.Parent.Parent.Services.WidgetService)

const SettingsHandler = require(script.Parent.Parent.Handlers.SettingsHandler)

const AttributeHelper = require(script.Parent.Parent.Parent.Helpers.AttributeHelper)

const HierarchyIs = require(script.Parent.Parent.Parent.ComponentExtensions.HierarchyIs)

-- Types --
export type ComponentInstance = GuiButton & {
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

	_Select: (self: Component) -> (),
	_Update: (self: Component) -> (),
}

type SettingName = SettingsService.SettingName

-- Radio Button Component --
const RadioButtonSetting = Component.new({
	Tag = "RadioButtonSetting",
	Ancestors = { (WidgetService.Widget :: any) :: Instance },
	Extensions = {
		HierarchyIs({
			IsA = "GuiButton",
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

const tSettingName = t.keyOf(SettingsService._settings)
function RadioButtonSetting.Construct(self: Component)
	self._trove = Trove.new()

	assert(tSettingName(self.Instance.Name), `Invalid Setting name, got "{self.Instance.Name}"`)
	self._settingName = self.Instance.Name :: SettingName
	self._settingDescription = AttributeHelper.Get(self.Instance, "SettingDescription", t.string) :: string
	self._radioGroup = AttributeHelper.Get(self.Instance, "RadioGroup", t.string) :: SettingsHandler.RadioGroup
	self._isDefaultInRadioGroup =
		AttributeHelper.Get(self.Instance, "IsDefaultInRadioGroup", t.optional(t.boolean)) :: boolean?
end

function RadioButtonSetting.Start(self: Component)
	-- Handle tooltip functionality.
	self._trove:Add(self.Instance.HelpButton.Activated:Connect(function()
		SettingsHandler.ToggleTooltip(self._settingDescription)
	end))

	-- Handle radio button functionality. The whole row selects, not just the small circle.
	self._trove:Add(self.Instance.RadioButton.Activated:Connect(function()
		self:_Select()
	end))
	self._trove:Add(self.Instance.Activated:Connect(function()
		self:_Select()
	end))
	task.defer(self._Update, self)

	-- Keep the tick in step with changes made anywhere else in the group.
	self._trove:Add(SettingsService.OnSettingChanged:Connect(function(settingName)
		if settingName == self._settingName then
			self:_Update()
		end
	end))

	-- Register with SettingsHandler to facilitate radio group functionality.
	SettingsHandler.RegisterRadioButton(self._settingName, self._radioGroup, self._isDefaultInRadioGroup == true)
end

function RadioButtonSetting.Stop(self: Component)
	self._trove:Destroy()
end

function RadioButtonSetting._Select(self: Component)
	if SettingsService.Get(self._settingName) then
		return
	end

	SettingsHandler.UpdateRadioSelection(self._settingName, self._radioGroup)
	WidgetService.PlaySound("RadioButtonToggleSound")
end

function RadioButtonSetting._Update(self: Component)
	self.Instance.RadioButton.Tick.Visible = SettingsService.Get(self._settingName) :: boolean
end

return RadioButtonSetting
