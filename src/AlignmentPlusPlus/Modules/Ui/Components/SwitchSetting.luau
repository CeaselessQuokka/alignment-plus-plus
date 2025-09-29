--!strict
--- Services ---
local TweenService = game:GetService("TweenService")

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
	SwitchButton: ImageButton & {
		Switch: Frame,
	},
	SettingName: TextLabel,
}

export type Component = {
	Instance: ComponentInstance,
	_trove: Trove.Trove,

	_settingName: SettingName,
	_settingDescription: string,
	_dimIfEnabled: { [SettingName]: boolean },
	_dimIfDisabled: { [SettingName]: boolean },

	_Update: (self: Component, useAnimation: boolean) -> (),
	_UpdateDimming: (self: Component) -> (),
}

type Properties = {
	AnchorPoint: Vector2,
	Position: UDim2,
	Color: () -> Color3,
}

type SettingName = SettingsService.SettingName

--- Variables ---
local ENABLED_PROPERTIES: Properties = {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(1, 0.5),
	Color = function(): Color3
		return Color3.fromRGB(76, 150, 164)
	end,
}

local DISABLED_PROPERTIES: Properties = {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Color = function(): Color3
		return ThemeHelper.GetColor(Enum.StudioStyleGuideColor.MainText)
	end,
}

--- Switch Setting Component ---
local SwitchSetting = Component.new({
	Tag = "SwitchSetting",
	Ancestors = { (WidgetService.Widget :: any) :: Instance },
	Extensions = {
		HierarchyIs({
			IsA = "GuiObject",
			Children = {
				HelpButton = {
					IsA = "GuiButton",
				},
				SwitchButton = {
					IsA = "GuiButton",
					Children = {
						Switch = {
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
function SwitchSetting.Construct(self: Component)
	self._trove = Trove.new()

	assert(tSettingName(self.Instance.Name), `Invalid Setting name, got "{self.Instance.Name}"`)
	self._settingName = self.Instance.Name :: SettingName
	self._settingDescription = AttributeHelper.Get(self.Instance, "SettingDescription", t.string) :: string
	self._dimIfEnabled =
		AttributeHelper.GetAsSet(self.Instance, "DimIfEnabled", tSettingName) :: { [SettingName]: boolean }
	self._dimIfDisabled =
		AttributeHelper.GetAsSet(self.Instance, "DimIfDisabled", tSettingName) :: { [SettingName]: boolean }
end

function SwitchSetting.Start(self: Component)
	-- Handle updating colors based off theme change (only applicable if the switch is disabled).
	self._trove:Add(ThemeHelper.OnThemeChanged:Connect(function()
		self:_UpdateDimming()
		if not SettingsService.Get(self._settingName) then
			return
		end

		self:_Update(false)
	end))

	-- Handle tooltip functionality.
	self._trove:Add(self.Instance.HelpButton.Activated:Connect(function()
		SettingsHandler.ToggleTooltip(self._settingDescription)
	end))

	-- Handle switch functionality.
	self._trove:Add(self.Instance.SwitchButton.Activated:Connect(function()
		SettingsService.Toggle(self._settingName)
		self:_Update(true)
		WidgetService.PlaySound("SwitchToggleSound")
	end))
	task.defer(self._Update, self, false)

	-- Handle dimming functionality.
	self._trove:Add(SettingsService.OnSettingChanged:Connect(function(settingName)
		if self._dimIfEnabled[settingName] or self._dimIfDisabled[settingName] then
			self:_UpdateDimming()
		end
	end))
	task.defer(self._UpdateDimming, self)
end

function SwitchSetting.Stop(self: Component)
	self._trove:Destroy()
end

function SwitchSetting._Update(self: Component, useAnimation: boolean)
	local isEnabled = SettingsService.Get(self._settingName)
	local switch = self.Instance.SwitchButton.Switch
	local properties = if isEnabled then ENABLED_PROPERTIES else DISABLED_PROPERTIES
	if useAnimation then
		local tweenInfo = TweenInfo.new(0.125, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		local tween = TweenService:Create(switch, tweenInfo, {
			AnchorPoint = properties.AnchorPoint,
			Position = properties.Position,
		})
		local cleanup = self._trove:Add(function()
			tween:Cancel()
			pcall(game.Destroy, tween)
		end)
		tween:Play()
		tween.Completed:Wait()
		self.Instance.SwitchButton.BackgroundColor3 = properties.Color()
		self._trove:Remove(cleanup)
	else
		switch.AnchorPoint = properties.AnchorPoint
		switch.Position = properties.Position
		self.Instance.SwitchButton.BackgroundColor3 = properties.Color()
	end
end

function SwitchSetting._UpdateDimming(self: Component)
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

return SwitchSetting
