--!strict
--- Imports ---
local SettingsService = require(script.Parent.Parent.Services.SettingsService)

local ModelHelper = require(script.Parent.Parent.Helpers.ModelHelper)

--- Functions ---
local function Attach(target: BasePart, translation: Vector3)
	-- Attach selected model (or parent/rootmost model), unless PartOnly is enabled.
	local model = ModelHelper.GetPartModel(target)
	if model and not SettingsService.Get("PartOnly") then
		ModelHelper.TranslateModel(target, model, translation)
	else
		if SettingsService.Get("RespectPartPivot") then
			target:PivotTo(target:GetPivot() + translation)
		else
			target.Position += translation
		end
	end
end

--- Attach To ---
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

	-- Apply attachment.
	Attach(target, vectorToAnchorSurface)
end
