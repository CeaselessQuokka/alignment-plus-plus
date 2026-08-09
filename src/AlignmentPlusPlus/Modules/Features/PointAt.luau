--!strict
-- Imports --
const SettingsService = require(script.Parent.Parent.Services.SettingsService)

const GeometryHelper = require(script.Parent.Parent.Helpers.GeometryHelper)
const ModelHelper = require(script.Parent.Parent.Helpers.ModelHelper)
const PickHelper = require(script.Parent.Parent.Helpers.PickHelper)

-- Types --
type Pick = PickHelper.Pick

-- Point At --
-- Rotates the target in place so that sliding it along the direction it was picked by would bring the picked
-- point onto the anchor's exactly.
--
-- Simply aiming the direction at the anchor is only correct when the picked point sits on that direction's own
-- line through the pivot, which is true of a face or a whole object but not of an edge or a corner. Those sit
-- off to one side, so aiming the direction alone leaves them pointing past the anchor.
--
-- Writing p for the picked point relative to the pivot, d for the direction and a for the anchor relative to
-- the pivot, a rotation R about the pivot has to satisfy R * (p + t * d) = a for some travel t. A rotation
-- cannot change length, so t is whatever makes |p + t * d| equal |a|, and R is then just the turn that takes
-- one onto the other.
return function(target: Pick, anchor: Pick)
	const respectPartPivot = SettingsService.Get("RespectPartPivot")
	const pivot = ModelHelper.GetReferenceCFrame(target.Subject, respectPartPivot).Position
	const toAnchor = anchor.Point - pivot
	if toAnchor.Magnitude < 1e-4 then
		-- The anchor sits on the pivot being rotated about, so there is no direction to aim along.
		return
	end

	const direction = PickHelper.GetAimDirection(target, respectPartPivot)
	const offset = target.Point - pivot
	const alongDirection = offset:Dot(direction)
	const discriminant = (alongDirection * alongDirection) - offset:Dot(offset) + toAnchor:Dot(toAnchor)

	local from
	if discriminant >= 0 then
		-- The far root is the one that travels forwards along the direction rather than backwards through the
		-- target.
		from = offset + (direction * (math.sqrt(discriminant) - alongDirection))
	else
		-- The anchor is nearer the pivot than the picked point's line of travel ever gets, so no rotation can
		-- line the two up. Aim the direction straight at it instead, which is the best available answer.
		from = direction
	end

	ModelHelper.RotateAbout(target.Subject, pivot, GeometryHelper.GetRotationBetween(from.Unit, toAnchor.Unit))
end
