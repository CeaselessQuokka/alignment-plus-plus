--!strict
--- Imports ---
local SettingsService = require(script.Parent.Parent.Services.SettingsService)

--- Functions ---
local function Resize(target: BasePart, sizeTranslation: Vector3, positionTranslation: Vector3)
	target.Size += sizeTranslation
	if SettingsService.Get("RespectPartPivot") then
		target:PivotTo(target:GetPivot() * CFrame.new(positionTranslation / 2))
	else
		local translation = CFrame.new(positionTranslation / 2)
		target.CFrame *= translation
		for _, attachment in target:GetChildren() do
			if attachment:IsA("Attachment") then
				attachment.CFrame *= translation
			end
		end
	end
end

--- Resize To ---
return function(
	target: BasePart,
	anchor: BasePart,
	targetObjectNormal: Vector3,
	anchorObjectNormal: Vector3,
	targetAttachmentCFrame: CFrame?, -- Used if an edge or corner was selected.
	anchorAttachmentCFrame: CFrame? -- Used if an edge or corner was selected.
)
	-- Calculate attachment points.
	local absTargetObjectNormal = targetObjectNormal:Abs()
	local targetAttachmentPoint = targetAttachmentCFrame
		or target.CFrame * CFrame.new(targetObjectNormal * (target.Size:Dot(absTargetObjectNormal) / 2))
	local anchorAttachmentPoint = anchorAttachmentCFrame
		or anchor.CFrame * CFrame.new(anchorObjectNormal * (anchor.Size:Dot(anchorObjectNormal:Abs()) / 2))

	-- The vector to add to the target's position to get to the anchor attachment point.
	local vectorToAnchorSurface = anchorAttachmentPoint.Position - targetAttachmentPoint.Position

	-- Calculate resize.
	local targetWorldNormal = targetAttachmentPoint:VectorToWorldSpace(targetObjectNormal)
	local length = targetWorldNormal:Dot(vectorToAnchorSurface)
	local sizeTranslation = absTargetObjectNormal * length
	local positionTranslation = targetObjectNormal * length

	-- Apply resize.
	Resize(target, sizeTranslation, positionTranslation)
end
