--!strict
-- Imports --
const SettingsService = require(script.Parent.Parent.Services.SettingsService)

const GeometryHelper = require(script.Parent.Parent.Helpers.GeometryHelper)
const ModelHelper = require(script.Parent.Parent.Helpers.ModelHelper)
const PickHelper = require(script.Parent.Parent.Helpers.PickHelper)

-- Types --
type Pick = PickHelper.Pick

-- Functions --
-- Half the distance across a subject's bounding box along a world direction.
const function GetHalfExtentAlong(subject: ModelHelper.Subject, direction: Vector3, respectPartPivot: boolean): number
	const reference = ModelHelper.GetReferenceCFrame(subject, respectPartPivot)
	return GeometryHelper.GetExtentAlong(ModelHelper.GetSize(subject), reference:VectorToObjectSpace(direction)) / 2
end

-- Attach To --
return function(target: Pick, anchor: Pick)
	const respectPartPivot = SettingsService.Get("RespectPartPivot")
	local destination = anchor.Point

	-- A whole object has no surface to meet the anchor with, so its center would end up buried inside whatever
	-- it was attached to. Backing it off by its own half extent makes the two sit flush instead, which is what
	-- attaching is supposed to look like.
	if target.Kind == "Part" then
		if anchor.Kind == "Part" then
			-- Neither side picked a surface, so the line joining the two centers is the only contact direction
			-- there is. Both back off along it rather than ending up sharing a center.
			const separation = target.Point - anchor.Point
			if separation.Magnitude > 1e-4 then
				const contact = separation.Unit
				const anchorReach = GetHalfExtentAlong(anchor.Subject, contact, respectPartPivot)
				const targetReach = GetHalfExtentAlong(target.Subject, contact, respectPartPivot)
				destination += contact * (anchorReach + targetReach)
			end
		else
			destination += anchor.Normal * GetHalfExtentAlong(target.Subject, anchor.Normal, respectPartPivot)
		end
	end

	ModelHelper.Translate(target.Subject, destination - target.Point)
end
