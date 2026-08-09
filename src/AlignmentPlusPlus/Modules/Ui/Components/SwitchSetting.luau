--!strict
-- Services --
const TweenService = game:GetService("TweenService")

-- Imports --
const Component = require(script.Parent.Parent.Parent.Packages.Component)
const Trove = require(script.Parent.Parent.Parent.Packages.Trove)
const t = require(script.Parent.Parent.Parent.Packages.t)

const SettingsService = require(script.Parent.Parent.Parent.Services.SettingsService)
const WidgetService = require(script.Parent.Parent.Parent.Services.WidgetService)

const SettingsHandler = require(script.Parent.Parent.Handlers.SettingsHandler)

const AttributeHelper = require(script.Parent.Parent.Parent.Helpers.AttributeHelper)
const ThemeHelper = require(script.Parent.Parent.Parent.Helpers.ThemeHelper)

const HierarchyIs = require(script.Parent.Parent.Parent.ComponentExtensions.HierarchyIs)

-- Types --
export type ComponentInstance = GuiButton & {
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
	_isAnimating: boolean,

	_Toggle: (self: Component) -> (),
	_Update: (self: Component, useAnimation: boolean) -> (),
}

type Properties = {
	AnchorPoint: Vector2,
	Position: UDim2,
	Color: () -> Color3,
}

type SettingName = SettingsService.SettingName

-- Variables --
const ENABLED_PROPERTIES: Properties = {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(1, 0.5),
	Color = function(): Color3
		return Color3.fromRGB(76, 150, 164)
	end,
}

const DISABLED_PROPERTIES: Properties = {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Color = function(): Color3
		return ThemeHelper.GetColor(Enum.StudioStyleGuideColor.MainText)
	end,
}

-- Switch Setting Component --
const SwitchSetting = Component.new({
	Tag = "SwitchSetting",
	Ancestors = { (WidgetService.Widget :: any) :: Instance },
	Extensions = {
		HierarchyIs({
			IsA = "GuiButton",
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

const tSettingName = t.keyOf(SettingsService._settings)
function SwitchSetting.Construct(self: Component)
	self._trove = Trove.new()
	self._isAnimating = false

	assert(tSettingName(self.Instance.Name), `Invalid Setting name, got "{self.Instance.Name}"`)
	self._settingName = self.Instance.Name :: SettingName
	self._settingDescription = AttributeHelper.Get(self.Instance, "SettingDescription", t.string) :: string
end

function SwitchSetting.Start(self: Component)
	-- Handle updating colors based off theme change (only applicable if the switch is disabled).
	self._trove:Add(ThemeHelper.OnThemeChanged:Connect(function()
		if not SettingsService.Get(self._settingName) then
			self:_Update(false)
		end
	end))

	-- Handle tooltip functionality.
	self._trove:Add(self.Instance.HelpButton.Activated:Connect(function()
		SettingsHandler.ToggleTooltip(self._settingDescription)
	end))

	-- Handle switch functionality. The row itself is a button as well as the switch, so anywhere along it is a
	-- much bigger and more forgiving target than the switch alone.
	self._trove:Add(self.Instance.SwitchButton.Activated:Connect(function()
		self:_Toggle()
	end))
	self._trove:Add(self.Instance.Activated:Connect(function()
		self:_Toggle()
	end))

	-- Keep the switch in step with changes made anywhere else. A change this component made itself is already
	-- being animated, so snapping it into place here would cut that animation short.
	self._trove:Add(SettingsService.OnSettingChanged:Connect(function(settingName)
		if settingName == self._settingName and not self._isAnimating then
			self:_Update(false)
		end
	end))
	task.defer(self._Update, self, false)
end

function SwitchSetting.Stop(self: Component)
	self._trove:Destroy()
end

function SwitchSetting._Toggle(self: Component)
	SettingsService.Toggle(self._settingName)
	self:_Update(true)
	WidgetService.PlaySound("SwitchToggleSound")
end

function SwitchSetting._Update(self: Component, useAnimation: boolean)
	const isEnabled = SettingsService.Get(self._settingName)
	const switch = self.Instance.SwitchButton.Switch
	const properties = if isEnabled then ENABLED_PROPERTIES else DISABLED_PROPERTIES
	if not useAnimation then
		switch.AnchorPoint = properties.AnchorPoint
		switch.Position = properties.Position
		self.Instance.SwitchButton.BackgroundColor3 = properties.Color()
		return
	end

	const tweenInfo = TweenInfo.new(0.125, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	const tween = TweenService:Create(switch, tweenInfo, {
		AnchorPoint = properties.AnchorPoint,
		Position = properties.Position,
	})
	const cleanup = self._trove:Add(function()
		tween:Cancel()
		pcall(game.Destroy, tween)
	end)
	self._isAnimating = true
	tween:Play()
	tween.Completed:Wait()
	self._isAnimating = false
	self.Instance.SwitchButton.BackgroundColor3 = properties.Color()
	self._trove:Remove(cleanup)
end

return SwitchSetting
