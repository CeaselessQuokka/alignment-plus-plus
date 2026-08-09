--!strict
-- Services --
const Selection = game:GetService("Selection")

-- Types --
-- Whatever a manipulation actually moves. Picks always land on a part, but the thing that moves may be a model
-- that part belongs to.
export type Subject = BasePart | Model

-- How far out from a picked part to reach when deciding what a manipulation moves.
export type SubjectScope = "Part" | "NearestModel" | "OutermostModel"

-- Model Helper --
const ModelHelper = {}

-- Walks up to the outermost model containing a part.
function ModelHelper.GetRootmostModel(part: BasePart): Model?
	local rootmost: Model? = part:FindFirstAncestorOfClass("Model")
	while rootmost do
		const parent = rootmost:FindFirstAncestorOfClass("Model")
		if not parent then
			break
		end
		rootmost = parent
	end
	return rootmost
end

-- A model explicitly selected in the Explorer wins over the ancestry rules, which is how a model that is
-- neither the direct parent nor the rootmost ancestor can still be manipulated.
function ModelHelper.GetExplicitlySelectedModel(part: BasePart): Model?
	const selected = Selection:Get()[1]
	if not selected or not selected:IsA("Model") or not part:IsDescendantOf(selected) then
		return nil
	end
	return selected
end

-- Decides what a pick on a part should actually manipulate.
function ModelHelper.ResolveSubject(part: BasePart, scope: SubjectScope): Subject
	if scope == "Part" then
		return part
	end

	-- A model chosen in the Explorer is an explicit instruction, so it outranks either ancestry rule.
	const explicitModel = ModelHelper.GetExplicitlySelectedModel(part)
	if explicitModel then
		return explicitModel
	end

	if scope == "OutermostModel" then
		return ModelHelper.GetRootmostModel(part) or part
	end
	return part:FindFirstAncestorOfClass("Model") or part
end

-- The frame a subject is measured from. Parts fall back to their raw CFrame unless pivots are being respected,
-- which keeps the historical behaviour of ignoring a part's pivot offset by default.
function ModelHelper.GetReferenceCFrame(subject: Subject, respectPartPivot: boolean): CFrame
	if subject:IsA("Model") then
		return subject:GetPivot()
	end
	return if respectPartPivot then subject:GetPivot() else (subject :: BasePart).CFrame
end

-- The point a whole subject pick refers to.
function ModelHelper.GetCenter(subject: Subject, respectPartPivot: boolean): Vector3
	return ModelHelper.GetReferenceCFrame(subject, respectPartPivot).Position
end

function ModelHelper.GetSize(subject: Subject): Vector3
	if subject:IsA("Model") then
		const _, size = subject:GetBoundingBox()
		return size
	end
	return (subject :: BasePart).Size
end

-- Moves a subject by a world space offset.
--
-- Note that this deliberately never reassigns a model's PrimaryPart. Both PivotTo and a direct CFrame write
-- displace by the same amount for a pure translation, so nothing is gained by rooting the model to the picked
-- part first, and leaving PrimaryPart alone means a model whose PrimaryPart is the part being moved cannot end
-- up in a half-modified state if anything throws partway through.
function ModelHelper.Translate(subject: Subject, translation: Vector3)
	if translation.Magnitude < 1e-9 then
		return
	end

	if subject:IsA("Model") then
		subject:PivotTo(subject:GetPivot() + translation)
	else
		const part = subject :: BasePart
		part.CFrame = part.CFrame + translation
	end
end

-- Rotates a subject about a world space point, leaving that point where it is.
function ModelHelper.RotateAbout(subject: Subject, point: Vector3, rotation: CFrame)
	const pivotAboutPoint = CFrame.new(point) * rotation * CFrame.new(-point)
	if subject:IsA("Model") then
		subject:PivotTo(pivotAboutPoint * subject:GetPivot())
	else
		const part = subject :: BasePart
		part.CFrame = pivotAboutPoint * part.CFrame
	end
end

-- Moves a subject so that its own reference frame lands on a CFrame. Callers work in this frame throughout, so
-- a model is placed by its pivot and never needs its PrimaryPart touched.
function ModelHelper.SetReferenceCFrame(subject: Subject, cframe: CFrame, respectPartPivot: boolean)
	if subject:IsA("Model") then
		subject:PivotTo(cframe)
		return
	end

	const part = subject :: BasePart
	if respectPartPivot then
		part:PivotTo(cframe)
	else
		part.CFrame = cframe
	end
end

return table.freeze(ModelHelper)
