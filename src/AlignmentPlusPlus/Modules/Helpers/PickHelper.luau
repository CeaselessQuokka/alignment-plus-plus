--!strict
-- Imports --
const GeometryHelper = require(script.Parent.GeometryHelper)
const ModelHelper = require(script.Parent.ModelHelper)

-- Types --
-- One completed selection. Every mode reads the same record, which is what lets a face, an edge, a corner and
-- a whole part all be used interchangeably wherever a selection is asked for.
export type Pick = {
	Part: BasePart, -- The part that was actually under the cursor.
	Subject: ModelHelper.Subject, -- What a manipulation will move; either that part or a model containing it.
	Kind: GeometryHelper.PickKind,
	Point: Vector3, -- World space reference point.
	Normal: Vector3, -- World space outward direction.
	Element: GeometryHelper.Element, -- The object space element this was built from.
	FaceNormal: Vector3, -- Object space normal of the face the element belongs to.
	Index: number?, -- Which edge or corner of that face, so the pick can be rebuilt after a resize.
}

-- Functions --
-- What a manipulation will actually move. This is not the same thing as what was clicked: clicking a wall may
-- well move the house it belongs to, and that has to be said out loud rather than left to be discovered.
const function GetSubjectLabel(subject: ModelHelper.Subject): string
	return if subject:IsA("Model") then "Model" else "Part"
end

-- Pick Helper --
const PickHelper = {}

-- Builds a pick from a resolved element. Whole part picks measure from the subject's own center so that
-- centering a model does not accidentally center just the part that happened to be clicked.
function PickHelper.Create(
	part: BasePart,
	subject: ModelHelper.Subject,
	faceNormal: Vector3,
	element: GeometryHelper.Element,
	index: number?,
	respectPartPivot: boolean
): Pick
	const partCFrame = part.CFrame
	const point = if element.Kind == "Part"
		then ModelHelper.GetCenter(subject, respectPartPivot)
		else partCFrame * element.Position
	return {
		Part = part,
		Subject = subject,
		Kind = element.Kind,
		Point = point,
		Normal = partCFrame:VectorToWorldSpace(element.Normal).Unit,
		Element = element,
		FaceNormal = faceNormal,
		Index = index,
	}
end

-- Rebuilds a pick against the part's current state. Used to carry a target across an action that may have
-- changed the part's size, where the original object space element would no longer describe the same place.
function PickHelper.Refresh(pick: Pick, respectPartPivot: boolean): Pick
	const element = GeometryHelper.BuildElement(pick.Part.Size, pick.FaceNormal, pick.Kind, pick.Index)
	return PickHelper.Create(pick.Part, pick.Subject, pick.FaceNormal, element, pick.Index, respectPartPivot)
end

-- The direction a Point At target aims along. A whole part has no picked face to speak of, so it falls back to
-- the subject's own forward direction, which is what LookVector means for a part or a model.
function PickHelper.GetAimDirection(pick: Pick, respectPartPivot: boolean): Vector3
	if pick.Kind == "Part" then
		return -ModelHelper.GetReferenceCFrame(pick.Subject, respectPartPivot).LookVector
	end
	return pick.Normal
end

-- A short description of a selection, naming what moves and, when it is not the whole thing, which piece of it
-- was picked. "Model" alone means the whole model; "Model, Face" means a face was picked but the model moves.
function PickHelper.Describe(subject: ModelHelper.Subject, kind: GeometryHelper.PickKind): string
	const subjectLabel = GetSubjectLabel(subject)
	if kind == "Part" then
		return subjectLabel
	end
	return `{subjectLabel}, {kind}`
end

function PickHelper.DescribePick(pick: Pick): string
	return PickHelper.Describe(pick.Subject, pick.Kind)
end

-- Whether two picks refer to the same thing, used to stop a mode consuming the same selection twice.
function PickHelper.IsSameSubject(a: Pick, b: Pick): boolean
	return a.Subject == b.Subject
end

return table.freeze(PickHelper)
