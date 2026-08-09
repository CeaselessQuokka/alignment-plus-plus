--!strict
-- Imports --
const Signal = require(script.Parent.Parent.Packages.Signal)

-- Types --
-- Listed in the same grouping DEFAULT_SETTINGS uses below: modes, Align To options, Set To options, what a
-- manipulation moves, selectability, general, and finally the category expansion states.
export type SettingName =
	"AlignTo"
	| "AttachTo"
	| "PointAt"
	| "ResizeTo"
	| "SetTo"
	| "PlaceBetween"
	| "AlignAlongNormal"
	| "AlignOnNearestAxis"
	| "AlignChooseInViewport"
	| "SetPositionAndOrientation"
	| "SetPositionOrientationAndSize"
	| "SetPositionOnly"
	| "SetOrientationOnly"
	| "SetSizeOnly"
	| "SubjectAutoModel"
	| "SubjectRootmostModel"
	| "SubjectPartOnly"
	| "LockedTargetPartsSelectable"
	| "LockedAnchorPartsSelectable"
	| "NoCanCollideQueryTargetSelectable"
	| "NoCanCollideQueryAnchorSelectable"
	| "AdvancedMode"
	| "RespectPartPivot"
	| "ContrastPartHighlighting"
	| "PlaySounds"
	| "KeepTargetAfterAction"
	| "ScaleAttachmentsOnResize"
	| "ModeOptions"
	| "AlignToOptions"
	| "SetToOptions"
	| "SubjectOptions"
	| "SelectionOptions"
	| "GeneralOptions"
export type SettingValue = boolean

-- An indexer rather than a record: settings are almost always reached through a SettingName variable, and
-- a record type widens that key back to a plain string on the way out.
export type Settings = { [SettingName]: SettingValue }

-- Variables --
const SETTINGS_KEY = "QDT_AlignmentPlusPlus"

-- Every mode, in the order they are offered. Kept here so that other modules never have to ask about each mode
-- one at a time just to find out which is active.
const MODE_NAMES: { SettingName } = table.freeze({
	"AlignTo",
	"AttachTo",
	"PointAt",
	"ResizeTo",
	"SetTo",
	"PlaceBetween",
} :: { SettingName })

const DEFAULT_SETTINGS = {
	-- Modes.
	AlignTo = true,
	AttachTo = false,
	PointAt = false,
	ResizeTo = false,
	SetTo = false,
	PlaceBetween = false,

	-- Align To options. Sliding along the picked normal is what the original plugin did, and is what almost
	-- everyone expects, so it leads.
	AlignAlongNormal = true,
	AlignOnNearestAxis = false,
	AlignChooseInViewport = false,

	-- Set To options.
	SetPositionAndOrientation = true,
	SetPositionOrientationAndSize = false,
	SetPositionOnly = false,
	SetOrientationOnly = false,
	SetSizeOnly = false,

	-- What a manipulation moves.
	SubjectAutoModel = true,
	SubjectRootmostModel = false,
	SubjectPartOnly = false,

	-- Selectability.
	LockedTargetPartsSelectable = false,
	LockedAnchorPartsSelectable = true,
	NoCanCollideQueryTargetSelectable = true,
	NoCanCollideQueryAnchorSelectable = true,

	-- General.
	AdvancedMode = false,
	RespectPartPivot = false,
	ContrastPartHighlighting = true,
	PlaySounds = true,
	KeepTargetAfterAction = false,
	ScaleAttachmentsOnResize = true,

	-- Category expansion states.
	ModeOptions = true,
	AlignToOptions = true,
	SetToOptions = true,
	SubjectOptions = true,
	SelectionOptions = true,
	GeneralOptions = true,
} :: Settings

-- Settings Service --
const SettingsService = {
	-- Boilerplate
	Initialized = false,
	Started = false,
	_plugin = nil :: Plugin?,

	-- Service Specific
	OnSettingChanged = Signal.new() :: Signal.Signal<SettingName, SettingValue>,
	OnSettingsSaved = Signal.new() :: Signal.Signal<>,

	MODE_NAMES = MODE_NAMES,
	_settings = table.clone(DEFAULT_SETTINGS),
}
const self = SettingsService

function SettingsService.Init(plugin: Plugin)
	assert(not self.Initialized, `{script.Name} was already initialized`)

	self._plugin = plugin
	self.Initialized = true
end

function SettingsService.Start()
	assert(self.Initialized, `{script.Name} was not initialized`)
	assert(not self.Started, `{script.Name} was already started`)

	-- Reconcile settings. Building a fresh table from the defaults rather than patching the saved one means
	-- settings that no longer exist are dropped for free, and anything saved as the wrong type is replaced.
	const savedSettings = (self._plugin :: Plugin):GetSetting(SETTINGS_KEY)
	if typeof(savedSettings) == "table" then
		const saved = savedSettings :: { [string]: unknown }
		const reconciled: { [string]: SettingValue } = {}
		const defaults = (DEFAULT_SETTINGS :: any) :: { [string]: SettingValue }
		for settingName, defaultValue in defaults do
			const savedValue = saved[settingName]
			reconciled[settingName] = if typeof(savedValue) == "boolean" then savedValue else defaultValue
		end
		self._settings = reconciled :: any
	end

	-- A save from an older version could leave every mode off, which would strand the plugin with no mode at
	-- all, so fall back to the default mode when nothing is selected.
	if not SettingsService.GetActiveMode() then
		self._settings["AlignTo" :: SettingName] = true
	end

	-- Update service state.
	self.Started = true
end

function SettingsService.Stop()
	assert(self.Started, `{script.Name} was not started`)

	self.Started = false
end

function SettingsService.Unload()
	self.Save()
	pcall(self.Stop)
	self.OnSettingChanged:DisconnectAll()
	self.OnSettingsSaved:DisconnectAll()
end

function SettingsService.Get(name: SettingName): SettingValue
	assert(self._settings[name] ~= nil, `"{name}" ({typeof(name)}) is not a valid setting`)

	return self._settings[name]
end

function SettingsService.Set(name: SettingName, value: SettingValue)
	assert(self._settings[name] ~= nil, `"{name}" ({typeof(name)}) is not a valid setting`)
	if self._settings[name] == value then
		return
	end

	self._settings[name] = value
	self.OnSettingChanged:FireDeferred(name, value)
	self.Save()
end

function SettingsService.Toggle(name: SettingName)
	assert(self._settings[name] ~= nil, `"{name}" ({typeof(name)}) is not a valid setting`)

	self.Set(name, not self._settings[name])
end

-- The mode currently in use. Returns nil only while settings are mid-reconcile.
function SettingsService.GetActiveMode(): SettingName?
	for _, modeName: SettingName in MODE_NAMES do
		if self._settings[modeName] then
			return modeName
		end
	end
	return nil
end

function SettingsService.Save()
	(self._plugin :: Plugin):SetSetting(SETTINGS_KEY, self._settings)
	self.OnSettingsSaved:FireDeferred()
end

return SettingsService
