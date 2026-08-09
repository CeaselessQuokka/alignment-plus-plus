--!strict
-- Imports --
const SettingsService = require(script.Parent.Parent.Services.SettingsService)

const GeometryHelper = require(script.Parent.Parent.Helpers.GeometryHelper)
const ModelHelper = require(script.Parent.Parent.Helpers.ModelHelper)
const PickHelper = require(script.Parent.Parent.Helpers.PickHelper)

-- Types --
type Pick = PickHelper.Pick

export type Translations = {
	AlongNormal: Vector3, -- Slides until the target's selection is flush with the anchor's plane.
	NearestAxis: Vector3, -- Slides along whichever world axis the target's normal points down.
}

-- Variables --
-- Below this the target's selection is edge on to the anchor's plane, so sliding along the normal would either
-- never reach it or shoot off to somewhere absurd. The gap is simply closed instead.
const MINIMUM_PLANE_ALIGNMENT = 0.05

-- Functions --
const function Align(target: Pick, translation: Vector3)
	ModelHelper.Translate(target.Subject, translation)
end

-- The direction the target travels, and the point on it that has to land on the anchor.
--
-- Picking a face, edge or corner gives both directly: travel along that face's normal, measured from the point
-- that was picked. A whole object gives neither, since no face of it was chosen. Travelling along whichever
-- face the cursor happened to be over at the time is arbitrary and is what made aligning a model to a surface
-- slide it sideways. Instead it travels along the anchor's normal and lands the near side of its bounding box
-- on the anchor, so aligning a model to a floor sets it down on that floor.
const function GetTravel(target: Pick, anchor: Pick, respectPartPivot: boolean): (Vector3, Vector3)
	if target.Kind ~= "Part" then
		return target.Normal, target.Point
	end

	const reference = ModelHelper.GetReferenceCFrame(target.Subject, respectPartPivot)
	const localNormal = reference:VectorToObjectSpace(anchor.Normal)
	const reach = GeometryHelper.GetExtentAlong(ModelHelper.GetSize(target.Subject), localNormal) / 2
	return anchor.Normal, target.Point - (anchor.Normal * reach)
end

-- Align To --
const AlignTo = {}

function AlignTo.GetTranslations(target: Pick, anchor: Pick): Translations
	const direction, origin = GetTravel(target, anchor, SettingsService.Get("RespectPartPivot"))
	const delta = anchor.Point - origin

	-- How far along that direction the point has to travel to land on the anchor's plane.
	const alignment = direction:Dot(anchor.Normal)
	const distance = if math.abs(alignment) < MINIMUM_PLANE_ALIGNMENT
		then delta:Dot(direction)
		else delta:Dot(anchor.Normal) / alignment

	-- Constraining to a single world axis keeps a rotated part from drifting sideways, which is sometimes what
	-- is wanted even though it does not end up flush. The sign cancels out, so a signed axis is fine here.
	const dominantAxis = GeometryHelper.SnapToAxis(direction)
	return {
		AlongNormal = direction * distance,
		NearestAxis = dominantAxis * delta:Dot(dominantAxis),
	}
end

-- Runs the mode. When the viewport method picker is on and the two results actually differ, the translations
-- are handed back so the caller can let the user choose; otherwise the alignment is applied immediately.
function AlignTo.Run(target: Pick, anchor: Pick): Translations?
	const translations = AlignTo.GetTranslations(target, anchor)
	if
		SettingsService.Get("AlignChooseInViewport")
		and not translations.AlongNormal:FuzzyEq(translations.NearestAxis, 1e-4)
	then
		return translations
	end

	Align(
		target,
		if SettingsService.Get("AlignOnNearestAxis") then translations.NearestAxis else translations.AlongNormal
	)
	return nil
end

AlignTo.Align = Align
return table.freeze(AlignTo)
