--!strict
-- Imports --
const t = require(script.Parent.Parent.Packages.t)

const SettingsService = require(script.Parent.Parent.Services.SettingsService)

const AttributeHelper = require(script.Parent.AttributeHelper)

-- Types --
type SettingName = SettingsService.SettingName

-- Variables --
const tSettingName = t.keyOf(SettingsService._settings)

-- Visibility Helper --
-- Options that do not apply right now are hidden outright rather than dimmed. Dimming still left the panel
-- crowded with things that could not be used, which is most of what made the old layout feel heavy.
const VisibilityHelper = {}

-- Reads the visibility rules an instance declares through its attributes:
--   Advanced       -- only shown while Advanced Mode is on.
--   ShowIfEnabled  -- shown when any of the listed settings is enabled.
--   ShowIfDisabled -- hidden as soon as any of the listed settings is enabled.
function VisibilityHelper.ShouldShow(instance: Instance): boolean
	if AttributeHelper.Get(instance, "Advanced", t.optional(t.boolean)) == true then
		if not SettingsService.Get("AdvancedMode") then
			return false
		end
	end

	const showIfEnabled = AttributeHelper.GetAsArray(instance, "ShowIfEnabled", true, tSettingName) :: { SettingName }
	if #showIfEnabled > 0 then
		local isAnyEnabled = false
		for _, settingName: SettingName in showIfEnabled do
			if SettingsService.Get(settingName) then
				isAnyEnabled = true
				break
			end
		end
		if not isAnyEnabled then
			return false
		end
	end

	const showIfDisabled = AttributeHelper.GetAsArray(instance, "ShowIfDisabled", true, tSettingName) :: { SettingName }
	for _, settingName: SettingName in showIfDisabled do
		if SettingsService.Get(settingName) then
			return false
		end
	end
	return true
end

return table.freeze(VisibilityHelper)
