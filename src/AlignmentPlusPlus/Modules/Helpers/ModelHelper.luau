--!strict
--- Services ---
local Selection = game:GetService("Selection")

--- Imports ---
local SettingsService = require(script.Parent.Parent.Services.SettingsService)

--- Model Helper ---
local ModelHelper = {}

function ModelHelper.GetPartModel(target: BasePart): Model?
	local model = ModelHelper.GetSelectedModel(target)
	if not model then
		if SettingsService.Get("AlignRootmostModel") then
			return ModelHelper.ResolveRootmostModel(target)
		end
		model = target:FindFirstAncestorOfClass("Model")
	end
	return model
end

function ModelHelper.GetSelectedModel(target: BasePart): Model?
	local model: Model? = Selection:Get()[1]
	if not model or model.ClassName ~= "Model" or not target:IsDescendantOf(model) then
		return nil
	end

	return model
end

function ModelHelper.ResolveRootmostModel(target: BasePart): Model?
	local currentModel: Model? = target:FindFirstAncestorOfClass("Model")
	while currentModel do
		local model = currentModel:FindFirstAncestorOfClass("Model")
		if not model then
			break
		end

		currentModel = model
	end
	return currentModel
end

function ModelHelper.TranslateModel(
	target: BasePart,
	model: Model,
	translation: Vector3,
	anchorAttachmentPoint: CFrame?
)
	local originalPrimaryPart = model.PrimaryPart
	model.PrimaryPart = target
	model:PivotTo(model:GetPivot() + translation)
	model.PrimaryPart = originalPrimaryPart
end

function ModelHelper.SetModel(target: BasePart, model: Model, cframe: CFrame)
	local originalPrimaryPart = model.PrimaryPart
	model.PrimaryPart = target
	model:PivotTo(cframe)
	model.PrimaryPart = originalPrimaryPart
end

return table.freeze(ModelHelper)
