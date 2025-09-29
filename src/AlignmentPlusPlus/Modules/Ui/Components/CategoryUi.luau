--!strict
--- Imports ---
local Component = require(script.Parent.Parent.Parent.Packages.Component)
local Trove = require(script.Parent.Parent.Parent.Packages.Trove)
local t = require(script.Parent.Parent.Parent.Packages.t)

local SettingsService = require(script.Parent.Parent.Parent.Services.SettingsService)
local WidgetService = require(script.Parent.Parent.Parent.Services.WidgetService)

local AttributeHelper = require(script.Parent.Parent.Parent.Helpers.AttributeHelper)
local ThemeHelper = require(script.Parent.Parent.Parent.Helpers.ThemeHelper)

local HierarchyIs = require(script.Parent.Parent.Parent.ComponentExtensions.HierarchyIs)

--- Types ---
type ComponentInstance = GuiObject & {
	Break: Frame,
	ToggleExpansion: TextButton,
	Title: TextLabel,
}

type Component = {
	Instance: ComponentInstance,
	_trove: Trove.Trove,

	_categoryName: SettingName,
	_settingsInCategory: { SettingName },
	_dimIfEnabled: { [SettingName]: boolean },
	_dimIfDisabled: { [SettingName]: boolean },

	_Update: (self: Component) -> (),
	_UpdateDimming: (self: Component) -> (),
}

type SettingName = SettingsService.SettingName

--- Category UI Component ---
local CategoryUi = Component.new({
	Tag = "CategoryUi",
	Ancestors = { (WidgetService.Widget :: any) :: Instance },
	Extensions = {
		HierarchyIs({
			IsA = "GuiObject",
			Children = {
				Break = {
					IsA = "GuiObject",
				},
				ToggleExpansion = {
					IsA = "GuiButton",
				},
				Title = {
					Class = "TextLabel",
				},
			},
		}),
	} :: any,
})

local tSettingName = t.keyOf(SettingsService._settings)
function CategoryUi.Construct(self: Component)
	self._trove = Trove.new()

	assert(tSettingName(self.Instance.Name), `Invalid Category name, got "{self.Instance.Name}"`)
	self._categoryName = self.Instance.Name :: SettingName
	self._settingsInCategory = AttributeHelper.GetAsArray(self.Instance, "Settings", tSettingName) :: { SettingName }
	self._dimIfEnabled =
		AttributeHelper.GetAsSet(self.Instance, "DimIfEnabled", tSettingName) :: { [SettingName]: boolean }
	self._dimIfDisabled =
		AttributeHelper.GetAsSet(self.Instance, "DimIfDisabled", tSettingName) :: { [SettingName]: boolean }
end

function CategoryUi.Start(self: Component)
	-- Handle updating colors based off theme change.
	self._trove:Add(ThemeHelper.OnThemeChanged:Connect(function()
		self:_Update()
	end))

	-- Handle expansion toggle functionality.
	self._trove:Add(self.Instance.ToggleExpansion.Activated:Connect(function()
		SettingsService.Toggle(self._categoryName)
		self:_Update()
		WidgetService.PlaySound("CategoryExpansionToggleSound")
	end))
	task.defer(self._Update, self)

	-- Handle dimming functionality.
	self._trove:Add(SettingsService.OnSettingChanged:Connect(function(settingName)
		if self._dimIfEnabled[settingName] or self._dimIfDisabled[settingName] then
			self:_UpdateDimming()
		end
	end))
end

function CategoryUi.Stop(self: Component)
	self._trove:Destroy()
end

function CategoryUi._Update(self: Component)
	-- Update expansion visuals.
	local isExpanded = SettingsService.Get(self._categoryName) :: boolean
	self.Instance.ToggleExpansion.Text = if isExpanded then "↑" else "↓"
	self.Instance.Break.Visible = isExpanded
	self:_UpdateDimming()

	-- Update visibility of settings in this category.
	local widget = WidgetService.Widget :: WidgetService.Widget
	for _, settingName in self._settingsInCategory do
		(widget.Main.Settings:FindFirstChild(settingName) :: GuiObject).Visible = isExpanded
	end
end

function CategoryUi._UpdateDimming(self: Component)
	local isExpanded = SettingsService.Get(self._categoryName)
	if not isExpanded then
		self.Instance.Title.TextColor3 = ThemeHelper.GetColor(Enum.StudioStyleGuideColor.DimmedText)
		return
	end

	for settingName: SettingName in self._dimIfEnabled do
		if SettingsService.Get(settingName) then
			self.Instance.Title.TextColor3 = ThemeHelper.GetColor(Enum.StudioStyleGuideColor.DimmedText)
			return
		end
	end

	for settingName: SettingName in self._dimIfDisabled do
		if not SettingsService.Get(settingName) then
			self.Instance.Title.TextColor3 = ThemeHelper.GetColor(Enum.StudioStyleGuideColor.DimmedText)
			return
		end
	end

	self.Instance.Title.TextColor3 = ThemeHelper.GetColor(Enum.StudioStyleGuideColor.MainText)
end

return CategoryUi
