--!strict
-- Imports --
const SettingsService = require(script.Parent.Parent.Services.SettingsService)

const GeometryHelper = require(script.Parent.Parent.Helpers.GeometryHelper)
const ModelHelper = require(script.Parent.Parent.Helpers.ModelHelper)
const PickHelper = require(script.Parent.Parent.Helpers.PickHelper)

-- Types --
type Pick = PickHelper.Pick

-- Variables --
-- The engine's own limits. Clamping here rather than letting the assignment be silently rejected keeps the
-- part's opposite face from drifting when a resize is asked to go too far.
const MINIMUM_PART_SIZE = 0.05
const MAXIMUM_PART_SIZE = 2048

-- A procedural model's footprint is not a part and the engine puts no limits on it at all, so these are the
-- plugin's own. Zero is allowed where a part's size is not, because a footprint that is flat along an axis is
-- ordinary for a procedural model rather than a degenerate part; the ceiling is only a sanity bound, matching
-- the one parts are held to.
const MINIMUM_PROCEDURAL_SIZE = 0
const MAXIMUM_PROCEDURAL_SIZE = MAXIMUM_PART_SIZE

-- Below this the face being moved is edge on to the anchor's plane and would never meet it, so extending past
-- is abandoned and the two selections are simply brought together.
const MINIMUM_PLANE_ALIGNMENT = 0.05

-- Functions --
-- How far the target's selection has to travel along one of its own axes.
--
-- By default the gap is measured along that axis, which stops the moment the two selections meet. That is the
-- behaviour to expect: drag the target's face out and it lands on the point that was picked.
--
-- Extending past instead runs the face on until it reaches the plane the anchor's face lies in, which for two
-- parts at an angle keeps going well beyond where they met. It is occasionally what is wanted, so it lives on
-- a modifier rather than being the default.
const function GetDistanceAlongAxis(target: Pick, anchor: Pick, direction: Vector3, extendPast: boolean): number
	const delta = anchor.Point - target.Point
	if extendPast and anchor.Kind == "Face" then
		const alignment = direction:Dot(anchor.Normal)
		if math.abs(alignment) >= MINIMUM_PLANE_ALIGNMENT then
			return delta:Dot(anchor.Normal) / alignment
		end
	end
	return delta:Dot(direction)
end

-- Which of three unsigned axes a snapped axis vector names. Only used to tell two of them apart, so the order
-- matters no more than that it is consistent.
const function GetAxisIndex(unsignedAxis: Vector3): number
	if unsignedAxis.X ~= 0 then
		return 1
	elseif unsignedAxis.Y ~= 0 then
		return 2
	end
	return 3
end

-- Resizes a part, carrying its attachments.
const function ResizePart(target: Pick, anchor: Pick, extendPast: boolean)
	const part = target.Part
	const partCFrame = part.CFrame
	const originalSize = part.Size

	-- Attachments are positioned relative to the part's center, and a resize moves that center. Recording them
	-- up front leaves both ways of restoring them open once the new size is known.
	const attachmentCFrames: { [Attachment]: CFrame } = {}
	for _, child in part:GetChildren() do
		if child:IsA("Attachment") then
			attachmentCFrames[child] = child.CFrame
		end
	end

	local size = originalSize
	local translation = Vector3.zero
	for _, localAxis in target.Element.Axes do
		const direction = partCFrame:VectorToWorldSpace(localAxis)
		const axis = localAxis:Abs()
		const currentExtent = size:Dot(axis)
		const distance = math.clamp(
			GetDistanceAlongAxis(target, anchor, direction, extendPast),
			MINIMUM_PART_SIZE - currentExtent,
			MAXIMUM_PART_SIZE - currentExtent
		)

		-- Growing by the full distance while moving the center by half of it leaves the opposite face exactly
		-- where it was, so only the selected face, edge or corner appears to move.
		size += axis * distance
		translation += direction * (distance / 2)
	end

	part.Size = size
	part.CFrame = partCFrame + translation

	-- Attachments either ride the resize, holding the same relative place on the part so that one sitting on a
	-- face stays on that face, or hold the world position they started at the way Studio's own resize does.
	const scaleWithPart = SettingsService.Get("ScaleAttachmentsOnResize")
	const scale = Vector3.new(size.X / originalSize.X, size.Y / originalSize.Y, size.Z / originalSize.Z)
	for attachment, originalCFrame in attachmentCFrames do
		if scaleWithPart then
			attachment.CFrame = CFrame.new(originalCFrame.Position * scale) * originalCFrame.Rotation
		else
			attachment.CFrame = part.CFrame:Inverse() * (partCFrame * originalCFrame)
		end
	end
end

-- Resizes a procedural model by its footprint.
--
-- There is nothing down in the geometry to resize: it is generated output, thrown away and rebuilt on every
-- regeneration, so a part resize there would be undone the moment anything touched the model. The model's own
-- Size is the footprint its generator fills, and growing that is what growing a procedural model means.
--
-- The element still describes the generated part that was under the cursor, so each axis it drives has to be
-- carried into the model's own frame before the footprint can be changed along it. The arithmetic is otherwise
-- the part's: grow by the full distance, move by half of it, and the far side of the model stays put.
const function ResizeProcedural(target: Pick, anchor: Pick, extendPast: boolean)
	const subject = target.Subject :: Model
	const partCFrame = target.Part.CFrame
	const pivot = subject:GetPivot()

	local size = ModelHelper.GetSettableSize(subject) or Vector3.zero
	local translation = Vector3.zero
	const driven = { false, false, false }
	for _, localAxis in target.Element.Axes do
		const direction = partCFrame:VectorToWorldSpace(localAxis)

		-- A corner drives all three axes of the part it was picked on, and on a generated part sitting at an
		-- angle to the model two of those can round to the same model axis. The first one wins, rather than
		-- both being applied and counting the same distance twice.
		const axis = GeometryHelper.SnapToAxis(pivot:VectorToObjectSpace(direction)):Abs()
		const axisIndex = GetAxisIndex(axis)
		if driven[axisIndex] then
			continue
		end
		driven[axisIndex] = true

		const currentExtent = size:Dot(axis)
		const distance = math.clamp(
			GetDistanceAlongAxis(target, anchor, direction, extendPast),
			MINIMUM_PROCEDURAL_SIZE - currentExtent,
			MAXIMUM_PROCEDURAL_SIZE - currentExtent
		)
		size += axis * distance
		translation += direction * (distance / 2)
	end

	ModelHelper.SetSize(subject, size)
	subject:PivotTo(pivot + translation)
end

-- Resize To --
return function(target: Pick, anchor: Pick, extendPast: boolean?)
	if ModelHelper.IsProcedural(target.Subject) then
		ResizeProcedural(target, anchor, extendPast == true)
		return
	end
	ResizePart(target, anchor, extendPast == true)
end
