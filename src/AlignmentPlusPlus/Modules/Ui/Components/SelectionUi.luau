--!strict
-- Imports --
const Component = require(script.Parent.Parent.Parent.Packages.Component)
const Trove = require(script.Parent.Parent.Parent.Packages.Trove)

const InputService = require(script.Parent.Parent.Parent.Services.InputService)
const SelectionService = require(script.Parent.Parent.Parent.Services.SelectionService)
const WidgetService = require(script.Parent.Parent.Parent.Services.WidgetService)

const GeometryHelper = require(script.Parent.Parent.Parent.Helpers.GeometryHelper)
const ModeHelper = require(script.Parent.Parent.Parent.Helpers.ModeHelper)
const PickHelper = require(script.Parent.Parent.Parent.Helpers.PickHelper)

-- Types --
type ComponentInstance = GuiObject & {
	Prompt: TextLabel,
	Slot1: TextLabel,
	Slot2: TextLabel,
	Slot3: TextLabel,
	Hint: TextLabel,
}

type Component = {
	Instance: ComponentInstance,
	_trove: Trove.Trove,

	_Update: (self: Component) -> (),
}

-- Variables --
const KIND_COLOR = "#B9BDC4"
const PENDING_COLOR = "#8A8F98"

-- Selection UI Component --
const SelectionUi = Component.new({
	Tag = "SelectionUi",
	Ancestors = { (WidgetService.Widget :: any) :: Instance },
})

function SelectionUi.Construct(self: Component)
	self._trove = Trove.new()
end

function SelectionUi.Start(self: Component)
	self._trove:Add(SelectionService.OnSelectionChanged:Connect(function()
		self:_Update()
	end))

	-- Holding a modifier changes what the next click will grab, so the readout has to follow it live.
	self._trove:Add(InputService.OnModifiersChanged:Connect(function()
		self:_Update()
	end))
	task.defer(self._Update, self)
end

function SelectionUi.Stop(self: Component)
	self._trove:Destroy()
end

function SelectionUi._Update(self: Component)
	const mode = ModeHelper.GetActiveMode()
	const picks = SelectionService.Picks
	const currentSlotIndex = #picks + 1
	const labels = { self.Instance.Slot1, self.Instance.Slot2, self.Instance.Slot3 }

	for index, label in labels do
		const slot = mode.Slots[index]
		if not slot then
			label.Visible = false
			continue
		end

		label.Visible = true
		const pick = picks[index]
		if pick then
			-- Already chosen; show exactly what was taken.
			label.Text = `<font color="{slot.Color}">{slot.Name}</font>: {pick.Subject.Name}`
				.. ` <font color="{KIND_COLOR}">({PickHelper.DescribePick(pick)})</font>`
		elseif index == currentSlotIndex then
			-- Up next; mirror whatever is under the cursor so it is obvious what a click would take.
			const subject = SelectionService.HoverSubject
			const kind: GeometryHelper.PickKind? = SelectionService.HoverKind
			label.Text = if subject and kind
				then `<font color="{slot.Color}">{slot.Name}</font>: {subject.Name}`
					.. ` <font color="{KIND_COLOR}">({PickHelper.Describe(subject, kind)})</font>`
				else `<font color="{slot.Color}">{slot.Name}</font>: <font color="{PENDING_COLOR}">hover to pick</font>`
		else
			label.Text = `<font color="{PENDING_COLOR}">{slot.Name}</font>`
		end
	end

	-- Prompt. Naming the mode here saves scrolling the list below to remember which one is running.
	if SelectionService.IsChoosingAlignment() then
		self.Instance.Prompt.Text = "<b>Choose</b> the placement you want to keep."
	else
		self.Instance.Prompt.Text = `<b>{mode.DisplayName}</b>  {mode.Summary}`
	end

	-- Modifier hints, only mentioning the ones that would actually do something right now.
	const hints: { string } = {}
	const currentSlot = SelectionService.GetCurrentSlot()
	if currentSlot then
		const modifierHint = ModeHelper.GetModifierHint(currentSlot, InputService.WholePartHeld)
		if modifierHint then
			table.insert(hints, `<b>Alt</b> {modifierHint}`)
		end

		if mode.PartsOnly then
			-- Nothing to scope in a parts only mode, so the same key carries the resize variant instead.
			table.insert(hints, "<b>Shift</b> extend past")
		else
			table.insert(hints, "<b>Ctrl</b> part  ·  <b>Shift</b> outermost")
		end
	end

	-- The line truncates on a narrow widget, so the keys most likely to be wanted are listed first.
	if #picks > 0 or SelectionService.IsChoosingAlignment() then
		table.insert(hints, "<b>Esc</b> cancel")
	end
	if #picks > 0 and not SelectionService.IsChoosingAlignment() then
		table.insert(hints, "<b>⌫</b> undo pick")
	end
	self.Instance.Hint.Text = table.concat(hints, "  ·  ")
	self.Instance.Hint.Visible = #hints > 0
end

return SelectionUi
