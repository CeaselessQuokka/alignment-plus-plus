--!strict
-- Imports --
const SettingsService = require(script.Parent.Parent.Services.SettingsService)

const ModelHelper = require(script.Parent.Parent.Helpers.ModelHelper)
const PickHelper = require(script.Parent.Parent.Helpers.PickHelper)

-- Types --
type Pick = PickHelper.Pick

-- Set To --
return function(target: Pick, anchor: Pick)
	const respectPartPivot = SettingsService.Get("RespectPartPivot")
	const targetReference = ModelHelper.GetReferenceCFrame(target.Subject, respectPartPivot)
	const anchorReference = ModelHelper.GetReferenceCFrame(anchor.Subject, respectPartPivot)

	-- Position comes from the anchor's selection, so setting to a face, edge or corner puts the target exactly
	-- there. Orientation comes from the anchor object itself, since a single face has no meaningful roll.
	local destination = target.Point
	local rotation = targetReference.Rotation
	local size: Vector3? = nil
	if SettingsService.Get("SetPositionOrientationAndSize") then
		destination = anchor.Point
		rotation = anchorReference.Rotation
		size = ModelHelper.GetSize(anchor.Subject)
	elseif SettingsService.Get("SetPositionAndOrientation") then
		destination = anchor.Point
		rotation = anchorReference.Rotation
	elseif SettingsService.Get("SetPositionOnly") then
		destination = anchor.Point
	elseif SettingsService.Get("SetOrientationOnly") then
		rotation = anchorReference.Rotation
	elseif SettingsService.Get("SetSizeOnly") then
		size = ModelHelper.GetSize(anchor.Subject)
	end

	-- A part owns its size, and so does a procedural model, whose footprint is what there is to set. An
	-- ordinary model owns none, so for that the part that was picked takes it, as it always has.
	if size and not ModelHelper.SetSize(target.Subject, size) then
		target.Part.Size = size
	end

	-- Rebuild the target's frame so that whichever point was picked lands on the destination under the new
	-- rotation. With a whole object pick that point is its center, which is the historical behaviour.
	const localPoint = targetReference:PointToObjectSpace(target.Point)
	ModelHelper.SetReferenceCFrame(
		target.Subject,
		CFrame.new(destination) * rotation * CFrame.new(-localPoint),
		respectPartPivot
	)
end
