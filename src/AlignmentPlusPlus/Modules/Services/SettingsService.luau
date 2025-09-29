--!strict
--- Imports ---
local Signal = require(script.Parent.Parent.Packages.Signal)

--- Types ---
export type SettingName =
	"AlignTo"
	| "AttachTo"
	| "ResizeTo"
	| "SetTo"
	| "PlaceBetween"
	| "ConstrainAligningToOneAxis"
	| "SelectMethodAfterAlignment"
	| "AlignInMultipleAxes"
	| "PartOnly"
	| "AlignRootmostModel"
	| "SetPositionOrientationAndSize"
	| "SetPositionAndOrientation"
	| "SetPositionOnly"
	| "SetOrientationOnly"
	| "SetSizeOnly"
	| "LockedTargetPartsSelectable"
	| "LockedAnchorPartsSelectable"
	| "NoCanCollideQueryTargetSelectable"
	| "NoCanCollideQueryAnchorSelectable"
	| "RespectPartPivot"
	| "ContrastPartHighlighting"
export type SettingValue = boolean

export type Settings = {
	AlignTo: SettingValue,
	AttachTo: SettingValue,
	ResizeTo: SettingValue,
	SetTo: SettingValue,
	PlaceBetween: SettingValue,
	SelectMethodAfterAlignment: SettingValue,
	ConstrainAligningToOneAxis: SettingValue,
	AlignInMultipleAxes: SettingValue,
	PartOnly: SettingValue,
	AlignRootmostModel: SettingValue,
	SetPositionOrientationAndSize: SettingValue,
	SetPositionAndOrientation: SettingValue,
	SetPositionOnly: SettingValue,
	SetOrientationOnly: SettingValue,
	SetSizeOnly: SettingValue,
	LockedTargetPartsSelectable: SettingValue,
	LockedAnchorPartsSelectable: SettingValue,
	NoCanCollideQueryTargetSelectable: SettingValue,
	NoCanCollideQueryAnchorSelectable: SettingValue,
	RespectPartPivot: SettingValue,
	ContrastPartHighlighting: SettingValue,
}

--- Variables ---
local SETTINGS_KEY = "QDT_AlignmentPlusPlus"

--- Settings Service ---
local SettingsService = {
	--- Boilerplate
	Initialized = false,
	Started = false,
	_plugin = nil :: Plugin?,

	--- Service Specific
	OnSettingChanged = Signal.new() :: Signal.Signal<SettingName, SettingValue>,
	OnSettingsSaved = Signal.new() :: Signal.Signal<>,

	_settings = {
		-- Setting States
		AlignTo = true,
		AttachTo = false,
		ResizeTo = false,
		SetTo = false,
		PlaceBetween = false,
		SelectMethodAfterAlignment = true,
		ConstrainAligningToOneAxis = false,
		AlignInMultipleAxes = false,
		PartOnly = false,
		AlignRootmostModel = false,
		SetPositionOrientationAndSize = false,
		SetPositionAndOrientation = true,
		SetPositionOnly = false,
		SetOrientationOnly = false,
		SetSizeOnly = false,
		LockedTargetPartsSelectable = false,
		LockedAnchorPartsSelectable = true,
		NoCanCollideQueryTargetSelectable = true,
		NoCanCollideQueryAnchorSelectable = true,
		RespectPartPivot = false,
		ContrastPartHighlighting = true,

		-- Category Expansion States
		AlignToOptions = true,
		AlignAttachSetToOptions = true,
		AlignmentMode = true,
		GeneralOptions = true,
		AccessibilityOptions = true,
		SetToOptions = true,
	} :: Settings,
}
local self = SettingsService

function SettingsService.Init(plugin: Plugin)
	assert(not SettingsService.Initialized, `{script.Name} was already initialized`)

	self._plugin = plugin
	self.Initialized = true
end

function SettingsService.Start()
	assert(self.Initialized, `{script.Name} was not initialized`)
	assert(not self.Started, `{script.Name} was already started`)

	-- Reconcile settings.
	local savedSettings = (self._plugin :: Plugin):GetSetting(SETTINGS_KEY)
	if savedSettings ~= nil then
		for defaultSettingName, defaultSettingValue in self._settings do
			if savedSettings[defaultSettingName] == nil then
				savedSettings[defaultSettingName] = defaultSettingValue
			end
		end

		-- Remove old settings.
		for savedSettingName in savedSettings do
			if self._settings[savedSettingName] == nil then
				savedSettings[savedSettingName] = nil
			end
		end
	end

	-- Update service state.
	local pluginSettings = savedSettings or self._settings
	self._settings = pluginSettings
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
end

function SettingsService.Toggle(name: SettingName)
	assert(self._settings[name] ~= nil, `"{name}" ({typeof(name)}) is not a valid setting`)

	self._settings[name] = not self._settings[name]
	self.OnSettingChanged:FireDeferred(name, self._settings[name])
end

function SettingsService.Save()
	(self._plugin :: Plugin):SetSetting(SETTINGS_KEY, self._settings)
	self.OnSettingsSaved:FireDeferred()
end

return SettingsService
