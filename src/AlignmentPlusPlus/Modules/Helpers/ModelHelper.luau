--!strict
-- Services --
const Selection = game:GetService("Selection")

-- Types --
-- Whatever a manipulation actually moves. Picks always land on a part, but the thing that moves may be a model
-- that part belongs to.
export type Subject = BasePart | Model

-- How far out from a picked part to reach when deciding what a manipulation moves.
export type SubjectScope = "Part" | "NearestModel" | "OutermostModel"

-- Functions --
-- Whether an instance is a model a manipulation could reasonably move.
--
-- IsA has to be used here rather than a ClassName comparison, because a procedural model is a Model without
-- being called one. FindFirstAncestorOfClass("Model") walks straight past it, which is what used to leave a
-- pick on a procedural model moving whichever ordinary model happened to be further up the tree, or else the
-- single generated part under the cursor. Workspace is a Model too, though, so the world roots have to be
-- ruled out by hand or every loose part in the place would resolve to the entire Workspace.
const function IsSubjectModel(instance: Instance): boolean
	return instance:IsA("Model") and not instance:IsA("WorldRoot")
end

-- Model Helper --
const ModelHelper = {}

-- The nearest model containing an instance.
function ModelHelper.GetNearestModel(instance: Instance): Model?
	local current: Instance? = instance.Parent
	while current and not current:IsA("WorldRoot") do
		if IsSubjectModel(current) then
			return current :: Model
		end
		current = current.Parent
	end
	return nil
end

-- Walks up to the outermost model containing an instance.
function ModelHelper.GetRootmostModel(instance: Instance): Model?
	local rootmost: Model? = nil
	local current: Instance? = instance.Parent
	while current and not current:IsA("WorldRoot") do
		if IsSubjectModel(current) then
			rootmost = current :: Model
		end
		current = current.Parent
	end
	return rootmost
end

-- Whether a subject's geometry is generated for it rather than authored.
--
-- This matters because that geometry is not editable in any lasting sense: the engine destroys and rebuilds it
-- every time the model regenerates, so anything written to one of those parts is thrown away. The model itself
-- is the only part of it worth manipulating.
function ModelHelper.IsProcedural(subject: Subject): boolean
	-- IsA answers false for a class this build has never heard of, so this stays safe on a Studio old enough to
	-- predate procedural models.
	return subject:IsA("ProceduralModel")
end

-- The procedural model an instance was generated for, if it was generated at all.
--
-- Generated output is kept under a GeneratedFolder, so crossing one on the way up means everything below it
-- belongs to the model above it. The walk carries on past the first one rather than stopping there, so that
-- what comes back is the outermost generated owner: an inner one would itself be output, and just as
-- disposable.
function ModelHelper.GetProceduralOwner(instance: Instance): Model?
	local owner: Model? = nil
	local current: Instance? = instance.Parent
	while current and not current:IsA("WorldRoot") do
		if current:IsA("GeneratedFolder") then
			const generator = current.Parent
			if generator and generator:IsA("ProceduralModel") then
				owner = generator :: Model
			end
		end
		current = current.Parent
	end
	return owner
end

-- A model explicitly selected in the Explorer wins over the ancestry rules, which is how a model that is
-- neither the direct parent nor the rootmost ancestor can still be manipulated.
function ModelHelper.GetExplicitlySelectedModel(part: BasePart): Model?
	const selected = Selection:Get()[1]
	if not selected or not IsSubjectModel(selected) or not part:IsDescendantOf(selected) then
		return nil
	end
	return selected :: Model
end

-- Decides what a pick on a part should actually manipulate.
function ModelHelper.ResolveSubject(part: BasePart, scope: SubjectScope): Subject
	-- Generated geometry can never be the subject, whatever the scope asks for. Moving or resizing one of those
	-- parts looks like it worked right up until the model next regenerates and the change vanishes with it, so
	-- asking for parts only on a procedural model is taken to mean the model rather than the part it threw up.
	const proceduralOwner = ModelHelper.GetProceduralOwner(part)
	if scope == "Part" then
		return proceduralOwner or part
	end

	-- A model chosen in the Explorer is an explicit instruction, so it outranks either ancestry rule.
	const explicitModel = ModelHelper.GetExplicitlySelectedModel(part)
	if explicitModel then
		return explicitModel
	end

	if scope == "OutermostModel" then
		return ModelHelper.GetRootmostModel(part) or proceduralOwner or part
	end
	return ModelHelper.GetNearestModel(part) or proceduralOwner or part
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

-- The size a subject owns in its own right, or nil for one that has none.
--
-- A part's is its Size. A procedural model's is also called Size, but it describes the footprint handed to the
-- generator rather than a measurement of what came out, which is exactly why it is the one size on a model
-- that can meaningfully be written: growing the footprint is what growing a procedural model means. An
-- ordinary model has no size of its own at all, only the extent of whatever is inside it, so there is nothing
-- there to set.
function ModelHelper.GetSettableSize(subject: Subject): Vector3?
	if subject:IsA("BasePart") then
		return subject.Size
	elseif ModelHelper.IsProcedural(subject) then
		return (subject :: any).Size
	end
	return nil
end

-- Writes a subject's own size, reporting back whether it had one to write. Callers with somewhere else to put a
-- size can act on a false return rather than having to ask what kind of subject they are holding.
function ModelHelper.SetSize(subject: Subject, size: Vector3): boolean
	if subject:IsA("BasePart") then
		subject.Size = size
		return true
	elseif not ModelHelper.IsProcedural(subject) then
		return false
	end

	-- Unlike a part's, this property is not clamped by the engine in the slightest and will take a negative
	-- size without complaint, which leaves the model inside out, so the floor is applied here instead. Zero is
	-- deliberately allowed through: a footprint that is flat along an axis is ordinary for a procedural model,
	-- and is how a flat piece of track describes itself.
	const procedural: any = subject
	procedural.Size = Vector3.new(math.max(size.X, 0), math.max(size.Y, 0), math.max(size.Z, 0))
	return true
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
