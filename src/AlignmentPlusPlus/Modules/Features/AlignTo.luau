--!strict
--- Imports ---
local SettingsService = require(script.Parent.Parent.Services.SettingsService)

local ModelHelper = require(script.Parent.Parent.Helpers.ModelHelper)

--- Functions ---
local function Align(target: BasePart, translation: Vector3)
	-- Align selected model (or parent/rootmost model), unless PartOnly is enabled.
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

--- Align To ---
local AlignTo = {}
function AlignTo.AttemptAlign(
	target: BasePart,
	anchor: BasePart,
	targetObjectNormal: Vector3,
	anchorObjectNormal: Vector3,
	targetAlignmentCFrame: CFrame?, -- Used if an edge or corner was selected.
	anchorAlignmentCFrame: CFrame? -- Used if an edge or corner was selected.
): { Method1: Vector3, Method2: Vector3 }?
	-- Calculate alignment points.
	local absTargetObjectNormal = targetObjectNormal:Abs()
	local targetAlignmentPoint = targetAlignmentCFrame
		or target.CFrame * CFrame.new(targetObjectNormal * (target.Size:Dot(absTargetObjectNormal) / 2))
	local anchorAlignmentPoint = anchorAlignmentCFrame
		or anchor.CFrame * CFrame.new(anchorObjectNormal * (anchor.Size:Dot(anchorObjectNormal:Abs()) / 2))

	-- Method 1: Project the attachment point onto the target's world normal to find the point along the normal.
	local targetWorldNormal = target.CFrame:VectorToWorldSpace(targetObjectNormal)
	local vectorToAnchorSurface = anchorAlignmentPoint.Position - targetAlignmentPoint.Position
	local length = targetWorldNormal:Dot(vectorToAnchorSurface)
	local method1Translation = targetWorldNormal * length

	-- Method 2: Find the closest world normal to targetWorldNormal.
	local closestNormal = nil :: Vector3?
	local closestProjection = -1
	for _, axis in { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis } do
		local projection = axis:Dot(target.CFrame:VectorToWorldSpace(absTargetObjectNormal):Abs())
		if projection > closestProjection then
			closestNormal = axis
			closestProjection = projection
		elseif math.abs(closestProjection - projection) < 1e-7 then
			-- If two axes are equally close, then use the target's object normal. This only happens with 45-degree rotations.
			closestNormal = absTargetObjectNormal
		end
	end
	local method2Translation = (closestNormal :: Vector3) * vectorToAnchorSurface

	-- Return translation vectors for both methods if select method setting is enabled.
	if
		SettingsService.Get("SelectMethodAfterAlignment")
		and not method1Translation:FuzzyEq(method2Translation, 1e-5)
	then
		return { Method1 = method1Translation, Method2 = method2Translation }
	end

	-- Apply alignment.
	Align(target, if SettingsService.Get("AlignInMultipleAxes") then method1Translation else method2Translation)
	return nil
end

AlignTo.Align = Align
return AlignTo
