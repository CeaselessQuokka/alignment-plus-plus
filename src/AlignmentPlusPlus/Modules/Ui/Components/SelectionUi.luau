--!strict
--- Imports ---
local Component = require(script.Parent.Parent.Parent.Packages.Component)
local Trove = require(script.Parent.Parent.Parent.Packages.Trove)

local SelectionService = require(script.Parent.Parent.Parent.Services.SelectionService)
local WidgetService = require(script.Parent.Parent.Parent.Services.WidgetService)

--- Types ---
type ComponentInstance = GuiObject & {
	Anchor: TextLabel,
	NoSelections: TextLabel,
	Target: TextLabel,
}

type Component = {
	Instance: ComponentInstance,
	_trove: Trove.Trove,
}

--- Selection UI Component ---
local SelectionUi = Component.new({
	Tag = "SelectionUi",
	Ancestors = { (WidgetService.Widget :: any) :: Instance },
})

function SelectionUi.Construct(self: Component)
	self._trove = Trove.new()
end

function SelectionUi.Start(self: Component)
	self._trove:Add(SelectionService.OnSelectionChanged:Connect(function()
		-- Update visibility.
		local isAnchorSelected = SelectionService.Anchor ~= nil
		local isTargetSelected = SelectionService.Target ~= nil
		self.Instance.Anchor.Visible = isAnchorSelected
		self.Instance.NoSelections.Visible = not isAnchorSelected and not isTargetSelected
		self.Instance.Target.Visible = isTargetSelected

		-- Update text.
		local anchor = if isAnchorSelected then SelectionService.Anchor else nil
		local target = if isTargetSelected then SelectionService.Target else nil
		self.Instance.Anchor.Text = `<font color="#F250A4">Anchor</font>: {if anchor then anchor.Name else ""}`
		self.Instance.Target.Text = `<font color="#50A4F2">Target</font>: {if target then target.Name else ""}`
	end))
end

function SelectionUi.Stop(self: Component)
	self._trove:Destroy()
end

return SelectionUi
