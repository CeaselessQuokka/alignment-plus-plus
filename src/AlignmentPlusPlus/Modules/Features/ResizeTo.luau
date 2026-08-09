--!strict
-- Imports --
const SettingsService = require(script.Parent.Parent.Services.SettingsService)

const PickHelper = require(script.Parent.Parent.Helpers.PickHelper)

-- Types --
type Pick = PickHelper.Pick

-- Variables --
-- The engine's own limits. Clamping here rather than letting the assignment be silently rejected keeps the
-- part's opposite face from drifting when a resize is asked to go too far.
const MINIMUM_PART_SIZE = 0.05
const MAXIMUM_PART_SIZE = 2048

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

-- Resize To --
return function(target: Pick, anchor: Pick, extendPast: boolean?)
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
			GetDistanceAlongAxis(target, anchor, direction, extendPast == true),
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
