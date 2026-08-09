--!strict
-- Imports --
const Component = require(script.Parent.Parent.Parent.Packages.Component)
const Trove = require(script.Parent.Parent.Parent.Packages.Trove)
const t = require(script.Parent.Parent.Parent.Packages.t)

const SettingsService = require(script.Parent.Parent.Parent.Services.SettingsService)
const WidgetService = require(script.Parent.Parent.Parent.Services.WidgetService)

const AttributeHelper = require(script.Parent.Parent.Parent.Helpers.AttributeHelper)
const ThemeHelper = require(script.Parent.Parent.Parent.Helpers.ThemeHelper)
const VisibilityHelper = require(script.Parent.Parent.Parent.Helpers.VisibilityHelper)

const HierarchyIs = require(script.Parent.Parent.Parent.ComponentExtensions.HierarchyIs)

-- Types --
type ComponentInstance = GuiButton & {
	Break: Frame,
	ToggleExpansion: TextButton,
	Title: TextLabel,
}

type Component = {
	Instance: ComponentInstance,
	_trove: Trove.Trove,

	_categoryName: SettingName,
	_settingsInCategory: { SettingName },

	_Toggle: (self: Component) -> (),
	_Update: (self: Component) -> (),
}

type SettingName = SettingsService.SettingName

-- Category UI Component --
const CategoryUi = Component.new({
	Tag = "CategoryUi",
	Ancestors = { (WidgetService.Widget :: any) :: Instance },
	Extensions = {
		HierarchyIs({
			IsA = "GuiButton",
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

const tSettingName = t.keyOf(SettingsService._settings)
function CategoryUi.Construct(self: Component)
	self._trove = Trove.new()

	assert(tSettingName(self.Instance.Name), `Invalid Category name, got "{self.Instance.Name}"`)
	self._categoryName = self.Instance.Name :: SettingName
	self._settingsInCategory =
		AttributeHelper.GetAsArray(self.Instance, "Settings", true, tSettingName) :: { SettingName }
end

function CategoryUi.Start(self: Component)
	-- Handle updating colors based off theme change.
	self._trove:Add(ThemeHelper.OnThemeChanged:Connect(function()
		self:_Update()
	end))

	-- Handle expansion toggle functionality, from the arrow or from anywhere along the header.
	self._trove:Add(self.Instance.ToggleExpansion.Activated:Connect(function()
		self:_Toggle()
	end))
	self._trove:Add(self.Instance.Activated:Connect(function()
		self:_Toggle()
	end))

	-- The category owns the visibility of every row inside it, and a row's rules can depend on any setting, so
	-- every change is re-evaluated rather than trying to track which settings matter to which row.
	self._trove:Add(SettingsService.OnSettingChanged:Connect(function()
		self:_Update()
	end))
	task.defer(self._Update, self)
end

function CategoryUi.Stop(self: Component)
	self._trove:Destroy()
end

function CategoryUi._Toggle(self: Component)
	SettingsService.Toggle(self._categoryName)
	self:_Update()
	WidgetService.PlaySound("CategoryExpansionToggleSound")
end

function CategoryUi._Update(self: Component)
	const widget = WidgetService.Widget :: WidgetService.Widget
	const isCategoryVisible = VisibilityHelper.ShouldShow(self.Instance)
	const isExpanded = SettingsService.Get(self._categoryName)

	-- Update visibility of the settings in this category.
	local visibleSettings = 0
	for _, settingName in self._settingsInCategory do
		const row = widget.Main.Settings:FindFirstChild(settingName) :: GuiObject?
		if not row then
			continue
		end

		const isRowRelevant = isCategoryVisible and VisibilityHelper.ShouldShow(row)
		if isRowRelevant then
			visibleSettings += 1
		end
		row.Visible = isRowRelevant and isExpanded
	end

	-- A header with nothing left under it is just noise, so it goes away with its contents.
	self.Instance.Visible = isCategoryVisible and visibleSettings > 0

	-- Update expansion visuals.
	self.Instance.ToggleExpansion.Text = if isExpanded then "↑" else "↓"
	self.Instance.Break.Visible = isExpanded
	self.Instance.Title.TextColor3 = ThemeHelper.GetColor(
		if isExpanded then Enum.StudioStyleGuideColor.MainText else Enum.StudioStyleGuideColor.DimmedText
	)
end

return CategoryUi
