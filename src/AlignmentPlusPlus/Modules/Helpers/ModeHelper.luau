--!strict
-- Imports --
const SettingsService = require(script.Parent.Parent.Services.SettingsService)

-- Types --
type SettingName = SettingsService.SettingName

-- One selection a mode asks for, in the order it is asked for.
export type Slot = {
	Name: string, -- Shown in the selection panel.
	Color: string, -- Hex color used for that name, matching the viewport highlight language.
	WholePartByDefault: boolean, -- Whether this slot means the whole object before any modifier is held.
	AllowWholePart: boolean,
	AllowSubElements: boolean,
}

export type Mode = {
	Name: SettingName,
	DisplayName: string,
	Summary: string, -- One line of guidance shown while the mode is active.
	Slots: { Slot },
	FiltersSubjectModel: boolean, -- Whether later picks skip the model the first pick resolved to.
	PartsOnly: boolean, -- Whether the mode refuses to operate on models.
}

-- Variables --
-- Used while settings are mid-reconcile and no mode is marked active yet.
const DEFAULT_MODE_NAME: SettingName = "AlignTo"

const TARGET_COLOR = "#50A4F2"
const ANCHOR_COLOR = "#F250A4"
const SECOND_ANCHOR_COLOR = "#69F250"

const function Target(wholePartByDefault: boolean, allowWholePart: boolean?): Slot
	return {
		Name = "Target",
		Color = TARGET_COLOR,
		WholePartByDefault = wholePartByDefault,
		AllowWholePart = allowWholePart ~= false,
		AllowSubElements = true,
	}
end

const function Anchor(name: string, color: string, wholePartByDefault: boolean): Slot
	return {
		Name = name,
		Color = color,
		WholePartByDefault = wholePartByDefault,
		AllowWholePart = true,
		AllowSubElements = true,
	}
end

-- Every mode, described declaratively so that selection flow, highlighting and the UI all read from one place
-- instead of each branching on the active mode themselves.
-- Keyed by plain string rather than SettingName: iterating or carrying a setting name around widens it
-- back to a string, and every mode's own Name field is what actually ties it to a setting.
const MODES: { [string]: Mode } = {
	AlignTo = {
		Name = "AlignTo",
		DisplayName = "Align To",
		Summary = "Slides the target so its selection sits flush with the anchor's.",
		Slots = { Target(false), Anchor("Anchor", ANCHOR_COLOR, false) },
		FiltersSubjectModel = true,
		PartsOnly = false,
	},
	AttachTo = {
		Name = "AttachTo",
		DisplayName = "Attach To",
		Summary = "Moves the target so its selection meets the anchor's exactly.",
		Slots = { Target(false), Anchor("Anchor", ANCHOR_COLOR, false) },
		FiltersSubjectModel = true,
		PartsOnly = false,
	},
	PointAt = {
		Name = "PointAt",
		DisplayName = "Point At",
		-- Aiming a whole object is by far the common case, so that leads and Alt reaches for a specific face,
		-- edge or corner to aim instead.
		Summary = "Rotates the target so its selection aims at the anchor's.",
		Slots = { Target(true), Anchor("Anchor", ANCHOR_COLOR, true) },
		FiltersSubjectModel = true,
		PartsOnly = false,
	},
	ResizeTo = {
		Name = "ResizeTo",
		DisplayName = "Resize To",
		-- The target slot has no whole part option; there is nothing sensible to resize from a part's center.
		Summary = "Grows or shrinks the target's face, edge or corner onto the anchor's.",
		Slots = { Target(false, false), Anchor("Anchor", ANCHOR_COLOR, false) },
		FiltersSubjectModel = false,
		PartsOnly = true,
	},
	SetTo = {
		Name = "SetTo",
		DisplayName = "Set To",
		Summary = "Copies the anchor's position, orientation and/or size onto the target.",
		Slots = { Target(true), Anchor("Anchor", ANCHOR_COLOR, true) },
		FiltersSubjectModel = true,
		PartsOnly = false,
	},
	PlaceBetween = {
		Name = "PlaceBetween",
		DisplayName = "Place Between",
		-- Both anchors are very often parts of the same model, so this mode never filters by model.
		Summary = "Centers the target between the two anchor selections.",
		Slots = {
			Target(true),
			Anchor("Anchor A", ANCHOR_COLOR, true),
			Anchor("Anchor B", SECOND_ANCHOR_COLOR, true),
		},
		FiltersSubjectModel = false,
		PartsOnly = false,
	},
}

-- Mode Helper --
const ModeHelper = {
	MODES = table.freeze(MODES),
}

function ModeHelper.GetActiveMode(): Mode
	const modeName = SettingsService.GetActiveMode() or DEFAULT_MODE_NAME
	const mode = MODES[modeName] or MODES[DEFAULT_MODE_NAME]
	assert(mode, `No mode is registered under "{modeName}"`)

	return mode
end

function ModeHelper.GetSlot(mode: Mode, index: number): Slot?
	return mode.Slots[index]
end

-- Whether a slot should be resolving faces, edges and corners right now. Holding the whole part modifier flips
-- a slot into (or out of) whole object picking, so one key covers both directions without ever being a no-op.
function ModeHelper.IsSubElementPick(slot: Slot, wholePartModifierHeld: boolean): boolean
	if not slot.AllowSubElements then
		return false
	elseif not slot.AllowWholePart then
		return true
	end
	return slot.WholePartByDefault == wholePartModifierHeld
end

-- What holding the whole part modifier would switch this slot to, for the on screen hint.
function ModeHelper.GetModifierHint(slot: Slot, wholePartModifierHeld: boolean): string?
	if not slot.AllowSubElements or not slot.AllowWholePart then
		return nil
	end
	-- "Object" rather than "part", since a whole pick may well resolve to the model around it.
	return if ModeHelper.IsSubElementPick(slot, wholePartModifierHeld) then "whole object" else "face, edge or corner"
end

return table.freeze(ModeHelper)
