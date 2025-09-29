--!strict
--- Imports ---
local SettingsService = require(script.Parent.Parent.Services.SettingsService)

local ModelHelper = require(script.Parent.Parent.Helpers.ModelHelper)

--- Functions ---
local function PlaceBetween(target: BasePart, newOrigin: Vector3)
	local targetCFrame = target.CFrame
	if SettingsService.Get("RespectPartPivot") then
		targetCFrame = target:GetPivot()
	end

	-- Move selected model (or parent/rootmost model), unless PartOnly is enabled.
	local model = ModelHelper.GetPartModel(target)
	if model and not SettingsService.Get("PartOnly") then
		ModelHelper.SetModel(target, model, targetCFrame.Rotation + newOrigin)
	else
		if SettingsService.Get("RespectPartPivot") then
			target:PivotTo(target:GetPivot().Rotation + newOrigin)
		else
			target.Position = newOrigin
		end
	end
end

--- Place Between ---
return function(
	target: BasePart,
	anchor1: BasePart,
	anchor2: BasePart,
	targetObjectNormal: Vector3,
	anchor1ObjectNormal: Vector3,
	anchor2ObjectNormal: Vector3,
	targetAttachmentCFrame: CFrame?, -- Used if an edge or corner was selected.
	anchor1AttachmentCFrame: CFrame?, -- Used if an edge or corner was selected.
	anchor2AttachmentCFrame: CFrame? -- Used if an edge or corner was selected.
)
	-- Calculate placement points.
	local anchor1AttachmentPoint = anchor1AttachmentCFrame
		or anchor1.CFrame * CFrame.new(anchor1ObjectNormal * (anchor1.Size:Dot(anchor1ObjectNormal:Abs()) / 2))
	local anchor2AttachmentPoint = anchor2AttachmentCFrame
		or anchor2.CFrame * CFrame.new(anchor2ObjectNormal * (anchor2.Size:Dot(anchor2ObjectNormal:Abs()) / 2))

	-- Get the midpoint between the anchors.
	local midpoint = (anchor1AttachmentPoint.Position + anchor2AttachmentPoint.Position) / 2

	-- Apply placement.
	PlaceBetween(target, midpoint)
end
