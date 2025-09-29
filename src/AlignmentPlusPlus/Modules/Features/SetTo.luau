--!strict
--- Imports ---
local SettingsService = require(script.Parent.Parent.Services.SettingsService)

local ModelHelper = require(script.Parent.Parent.Helpers.ModelHelper)

--- Functions ---
local function Set(target: BasePart, cframe: CFrame, size: Vector3)
	-- Set selected model (or parent/rootmost model), unless PartOnly is enabled.
	local model = ModelHelper.GetPartModel(target)
	if model and not SettingsService.Get("PartOnly") then
		ModelHelper.SetModel(target, model, cframe)
	else
		if SettingsService.Get("RespectPartPivot") then
			target:PivotTo(cframe)
		else
			target.CFrame = cframe
		end
	end
	target.Size = size
end

--- Set To ---
return function(target: BasePart, anchor: BasePart)
	local setCFrame, size = target.CFrame, target.Size
	if SettingsService.Get("SetPositionOrientationAndSize") then
		setCFrame = anchor.CFrame
		size = anchor.Size
	elseif SettingsService.Get("SetPositionAndOrientation") then
		setCFrame = anchor.CFrame
	elseif SettingsService.Get("SetPositionOnly") then
		setCFrame = CFrame.new(anchor.Position) * target.CFrame.Rotation
	elseif SettingsService.Get("SetOrientationOnly") then
		setCFrame = CFrame.new(target.Position) * anchor.CFrame.Rotation
	elseif SettingsService.Get("SetSizeOnly") then
		size = anchor.Size
	end

	-- Apply set.
	Set(target, setCFrame, size)
end
