--[[

	If you're viewing this script, I'd like to apologize in advance. This is the messiest script in the entire plugin.
	I just really wanted to get this plugin out, and I plan to hopefully rewrite this in the future, but for now, it's functional.

--]]

--!strict
--- Services ---
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

--- Imports ---
local Signal = require(script.Parent.Parent.Packages.Signal)
local Trove = require(script.Parent.Parent.Packages.Trove)

local SettingsService = require(script.Parent.SettingsService)

local ColorHelper = require(script.Parent.Parent.Helpers.ColorHelper)
local HighlightHelper = require(script.Parent.Parent.Helpers.HighlightHelper)
local ModelHelper = require(script.Parent.Parent.Helpers.ModelHelper)

local AlignTo = require(script.Parent.Parent.Features.AlignTo)
local AttachTo = require(script.Parent.Parent.Features.AttachTo)
local PlaceBetween = require(script.Parent.Parent.Features.PlaceBetween)
local ResizeTo = require(script.Parent.Parent.Features.ResizeTo)
local SetTo = require(script.Parent.Parent.Features.SetTo)

--- Types ---
type AlignmentMethod = "Method1" | "Method2"
type AlignmentBoundingBoxes = Model & { Method1: BasePart, Method2: BasePart }
type PossibleAlignments = { Method1: Vector3, Method2: Vector3 }
type MethodLabel = typeof(script.Parent.Parent.Parent.Assets.Ui.MethodLabel)

--- Variables ---
local SETTINGS_THAT_RESET_SELECTION = table.freeze({
	AlignTo = true,
	AttachTo = true,
	ResizeTo = true,
	SetTo = true,
	PartOnly = true,
	AlignRootmostModel = true,
})

--- Functions ---
local function RunWithUndo<T>(fn: (...any) -> T?, ...): T?
	local recordingId = ChangeHistoryService:TryBeginRecording("AlignmentPlusPlus", "AlignmentPlusPlus")
	if not recordingId then
		return nil
	end

	local success, result: string | T? = pcall(fn, ...)
	if success then
		ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Commit)
		return result :: T
	else
		ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Cancel)
		warn(`[Alignment++] Could not align because: {debug.traceback(result :: string)}`)
		return nil
	end
end

--- Selection Service ---
local SelectionService = {
	--- Boilerplate
	Initialized = false,
	Started = false,
	_trove = Trove.new(),
	_plugin = nil :: Plugin?,

	--- Service Specific
	OnSelectionChanged = Signal.new() :: Signal.Signal<>,

	-- General state.
	_mouse = nil :: PluginMouse?,

	-- Hover related state.
	_lastSelection = nil :: BasePart?,
	_lastHighlight = nil :: (CylinderHandleAdornment | SphereHandleAdornment)?,
	_lastObjectNormal = nil :: Vector3?,
	_currentHighlightTrove = nil :: Trove.Trove?, -- Contains the current highlighting instances and connections.
	_surfaceHighlight = nil :: BasePart?, -- Used solely for raycast exclusion.

	-- Selection related state.
	Target = nil :: BasePart?,
	Anchor = nil :: BasePart?,
	Anchor2 = nil :: BasePart?,
	_hoveringOverEdgeOrCorner = false, -- Used to determine if target/anchorAlignmentCFrame should be used.
	_currentSelection = nil :: (BasePart | CylinderHandleAdornment | SphereHandleAdornment)?,
	_targetObjectNormal = nil :: Vector3?, -- Used for align and resize to.
	_anchorObjectNormal = nil :: Vector3?, -- Used for align and resize to.
	_targetAlignmentCFrame = nil :: CFrame?, -- Used for edge and corner selection.
	_anchorAlignmentCFrame = nil :: CFrame?, -- Used for edge and corner selection.

	-- Alignment method selection related state.
	_alignmentMethodSelectionEnabled = false, -- Whether the user can select between multiple alignment methods.
	_alignmentTarget = nil :: BasePart?, -- The target that was selected.
	_possibleAlignments = nil :: PossibleAlignments?, -- The possible alignment translations.
	_alignmentBoundingBoxes = nil :: AlignmentBoundingBoxes?, -- Used to show the user the two alignment methods.
	_methodLabel = nil :: MethodLabel?, -- The label that shows which method is which.
	_lastSelectedMethod = nil :: BasePart?, -- The last selected alignment method.
	_selectedAlignmentMethod = nil :: AlignmentMethod?, -- The currently selected alignment method.

	-- Place Between method related state.
	_anchor2 = nil :: BasePart?, -- The second anchor for the Place Between alignment mode.
	_anchor2ObjectNormal = nil :: Vector3?, -- Used for align and resize to.
	_anchor2AlignmentCFrame = nil :: CFrame?, -- Used for edge and corner selection.
}
local self = SelectionService

function SelectionService.Init(plugin: Plugin)
	assert(not self.Initialized, `{script.Name} was already initialized`)

	self._plugin = plugin
	self._mouse = plugin:GetMouse()
	self.Initialized = true
end

function SelectionService.Start()
	assert(self.Initialized, `{script.Name} was not initialized`)
	assert(not self.Started, `{script.Name} was already started`)

	-- Handle part highlighting.
	local mouse = self._mouse :: PluginMouse
	self._trove:Add(mouse.Move:Connect(function()
		if self._hoveringOverEdgeOrCorner then
			return
		end

		if self._alignmentMethodSelectionEnabled then
			local selection = self.GetSelection(true)
			if selection then
				if self._lastSelectedMethod == selection then
					return
				end

				if self._lastSelectedMethod then
					local highlight = self._lastSelectedMethod:FindFirstChildOfClass("Highlight") :: Highlight
					highlight.FillColor = Color3.fromRGB(255, 0, 0)
				end
				local highlight = (selection :: BasePart):FindFirstChildOfClass("Highlight") :: Highlight
				highlight.FillColor = Color3.fromRGB(0, 255, 0)
				self._lastSelectedMethod = selection
				local otherBox = if selection.Name == "Method1"
					then (self._alignmentBoundingBoxes :: AlignmentBoundingBoxes).Method2
					else (self._alignmentBoundingBoxes :: AlignmentBoundingBoxes).Method1
				otherBox.Locked = true
				(self._methodLabel :: MethodLabel).Method.Method.Text = if selection.Name == "Method1"
					then "Single Axis"
					else "Multiple Axes"
				otherBox.Transparency = 1
				(self._methodLabel :: MethodLabel).Parent = selection :: BasePart
			elseif self._lastSelectedMethod then
				local highlight = self._lastSelectedMethod:FindFirstChildOfClass("Highlight") :: Highlight
				highlight.FillColor = Color3.fromRGB(255, 0, 0)
				local otherBox = if self._lastSelectedMethod.Name == "Method1"
					then (self._alignmentBoundingBoxes :: AlignmentBoundingBoxes).Method2
					else (self._alignmentBoundingBoxes :: AlignmentBoundingBoxes).Method1
				otherBox.Locked = false
				otherBox.Transparency = 0
				self._lastSelectedMethod = nil
				(self._methodLabel :: MethodLabel).Parent = nil
			end
			return
		end

		local isTarget = self.Target == nil
		local selection, objectNormal = self.GetSelection(isTarget)
		if not selection or not objectNormal then
			-- No selection found, clean any previous highlighting.
			if self._currentHighlightTrove then
				self._trove:Remove(self._currentHighlightTrove)
				self._currentHighlightTrove = nil
			end
			if self._lastSelection then
				self.OnSelectionChanged:FireDeferred()
			end
			self._lastSelection = nil
			self._lastObjectNormal = nil
			self._surfaceHighlight = nil
			return
		end

		-- Do nothing if hovering over the same part and surface as before.
		if self._lastSelection == selection and self._lastObjectNormal == objectNormal then
			return
		end

		-- A new surface or part is being hovered over. Clean previous highlighting, and apply new highlighting.
		if self._currentHighlightTrove then
			self._trove:Remove(self._currentHighlightTrove)
		end
		self._lastSelection = selection
		self._lastObjectNormal = objectNormal
		self._currentHighlightTrove = self.HighlightPart(selection, objectNormal)
		self.OnSelectionChanged:FireDeferred()
	end))

	-- Handle part selection, and actual plugin functionality (once both target and anchor are selected).
	self._trove:Add(mouse.Button1Down:Connect(function()
		if self._hoveringOverEdgeOrCorner then
			return
		end

		if self._alignmentMethodSelectionEnabled then
			if self._lastSelectedMethod then
				self._selectedAlignmentMethod = self._lastSelectedMethod.Name :: AlignmentMethod
			else
				self._ClearSelection(true)
			end
			return
		end

		self._currentSelection = self.GetSelection(self.Target == nil)
	end))
	self._trove:Add(mouse.Button1Up:Connect(function()
		if self._hoveringOverEdgeOrCorner then
			return
		end

		if self._selectedAlignmentMethod then
			if self._alignmentTarget and self._possibleAlignments then
				RunWithUndo(
					AlignTo.Align,
					self._alignmentTarget,
					self._possibleAlignments[self._selectedAlignmentMethod]
				)
			end
			self._ClearSelection(true)
			return
		end

		local isTarget = self.Target == nil
		local selection = self.GetSelection(isTarget)
		if not selection or not self._currentSelection or selection ~= self._currentSelection :: BasePart then
			self._currentSelection = nil
			return
		end

		if isTarget then
			-- Set target selection state.
			self.Target = self._currentSelection :: BasePart
			self._targetObjectNormal = self._lastObjectNormal
		else
			if SettingsService.Get("PlaceBetween") and self.Anchor then
				self.Anchor2 = self._currentSelection :: BasePart
				self._anchor2ObjectNormal = self._lastObjectNormal
				if self.Anchor2 then
					self._ApplyManipulation()
				else
					self.OnSelectionChanged:FireDeferred()
				end
				self._currentSelection = nil
				return
			end

			-- Set anchor selection state.
			self.Anchor = self._currentSelection :: BasePart
			self._anchorObjectNormal = self._lastObjectNormal
		end

		if self.Anchor and not SettingsService.Get("PlaceBetween") then
			-- Both selections have been made, apply the manipulation.
			self._ApplyManipulation()
		else
			self.OnSelectionChanged:FireDeferred()
		end
		self._currentSelection = nil
	end))

	-- Cancel selection on escape.
	self._trove:Add(UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if
			not gameProcessed
			and input.UserInputType == Enum.UserInputType.Keyboard
			and input.KeyCode == Enum.KeyCode.Escape
		then
			self._ClearSelection(true)
		end
	end))

	-- Reset highlighting when changing mode.
	self._trove:Add(SettingsService.OnSettingChanged:Connect(function(settingName)
		if SETTINGS_THAT_RESET_SELECTION[settingName] then
			self._ClearSelection(true)
		end
	end))

	-- When undoing an alignment selection, clear selection state.
	self._trove:Add(ChangeHistoryService.OnUndo:Connect(function()
		self._ClearSelection(true)
	end))

	-- Update service state.
	self.Started = true
end

function SelectionService.Stop()
	assert(self.Started, `{script.Name} was not started`)

	self._trove:Clean()
	self._ClearSelection(true)
	self.Started = false
end

function SelectionService.Unload()
	pcall(self.Stop)
end

-- Returns the part that was clicked, and the surface vector it clicked on.
function SelectionService.GetSelection(forTarget: boolean): (BasePart?, Vector3?)
	local mouse = self._mouse :: PluginMouse
	local rayParams = self._GetRaycastParams(forTarget)
	local origin = Workspace.CurrentCamera.CFrame.Position
	local direction = mouse.UnitRay.Direction * (2 ^ 14)
	local rayResult = Workspace:Raycast(origin, direction, rayParams)
	if not rayResult then
		return nil, nil
	end

	local includeLocked = SettingsService.Get(
		`Locked{if forTarget then "Target" else "Anchor"}PartsSelectable` :: SettingsService.SettingName
	)
	local selection: BasePart = rayResult.Instance
	if selection.Locked and not includeLocked then
		return nil, nil
	end

	-- Get object normal from world normal.
	local objectNormal = rayResult.Instance.CFrame:VectorToObjectSpace(rayResult.Normal)

	-- Round each axis to remove floating point inaccuracies.
	local absObjectNormal = objectNormal:Abs()
	local maxAxis = math.max(absObjectNormal.X, absObjectNormal.Y, absObjectNormal.Z)
	local epsilon = 1e-8
	if math.abs(maxAxis - absObjectNormal.X) < epsilon then
		objectNormal = Vector3.new(math.sign(objectNormal.X), 0, 0)
	elseif math.abs(maxAxis - absObjectNormal.Y) < epsilon then
		objectNormal = Vector3.new(0, math.sign(objectNormal.Y), 0)
	else
		objectNormal = Vector3.new(0, 0, math.sign(objectNormal.Z))
	end
	return selection, objectNormal
end

function SelectionService._GetRaycastParams(forTarget: boolean): RaycastParams
	local shouldBruteForce = SettingsService.Get(
		`NoCanCollideQuery{if forTarget then "Target" else "Anchor"}Selectable` :: SettingsService.SettingName
	) :: boolean
	local pickingAlignment = self._alignmentMethodSelectionEnabled
	local rayParams = RaycastParams.new()
	local exclusions: { any } = {}
	if not pickingAlignment then
		table.insert(exclusions, self._surfaceHighlight)
		table.insert(exclusions, self.Target)
		table.insert(exclusions, self.Anchor)
		if self.Target and not SettingsService.Get("ResizeTo") and not SettingsService.Get("PartOnly") then
			table.insert(exclusions, ModelHelper.GetPartModel(self.Target))
		end
	end
	rayParams.FilterType = if pickingAlignment then Enum.RaycastFilterType.Include else Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = (
		if pickingAlignment then { self._alignmentBoundingBoxes } else exclusions
	) :: any
	rayParams.BruteForceAllSlow = not pickingAlignment and shouldBruteForce
	rayParams.IgnoreWater = true
	return rayParams
end

function SelectionService.HighlightPart(part: BasePart, objectNormal: Vector3): Trove.Trove
	local highlightColors = SelectionService._GetHighlightColors(part)
	local highlightTrove = self._trove:Extend()

	-- Set To and Place Between highlighting.
	if SettingsService.Get("SetTo") or (SettingsService.Get("PlaceBetween") and not self.Target) then
		local selectionBox = highlightTrove:Add(HighlightHelper.HighlightPart(part))
		selectionBox.Color3 = highlightColors.Part
		selectionBox.SurfaceColor3 = highlightColors.Part
		return highlightTrove
	end

	-- Surface highlighting.
	local surfaceHighlight = highlightTrove:Add(HighlightHelper.HighlightSurface(part, objectNormal))
	surfaceHighlight.Color = highlightColors.Surface
	self._surfaceHighlight = surfaceHighlight

	-- Edge highlighting (visible for every mode).
	local edgeHighlights: { CylinderHandleAdornment } = {}
	if not SettingsService.Get("ResizeTo") or self.Target then
		edgeHighlights = HighlightHelper.HighlightEdges(part, objectNormal)
		for _, edgeHighlight in edgeHighlights do
			highlightTrove:Add(edgeHighlight)
			edgeHighlight.Color3 = highlightColors.Edge

			-- Handle edge highlight mouse events.
			highlightTrove:Add(edgeHighlight.MouseEnter:Connect(function()
				if self._lastHighlight and self._lastHighlight.ClassName == "SphereHandleAdornment" then
					return
				end

				if self._lastHighlight then
					if self._lastHighlight.ClassName == "CylinderHandleAdornment" then
						(self._lastHighlight :: CylinderHandleAdornment).Color3 = highlightColors.Edge
					else
						(self._lastHighlight :: SphereHandleAdornment).Color3 = highlightColors.Corner
					end
				end
				self._hoveringOverEdgeOrCorner = true
				edgeHighlight.Color3 = highlightColors.Hover
				self._lastHighlight = edgeHighlight
			end))
			highlightTrove:Add(edgeHighlight.MouseLeave:Connect(function()
				self._hoveringOverEdgeOrCorner = false
				edgeHighlight.Color3 = highlightColors.Edge
				self._lastHighlight = nil
			end))
			highlightTrove:Add(edgeHighlight.MouseButton1Down:Connect(function()
				self._currentSelection = self._lastHighlight
			end))
			highlightTrove:Add(edgeHighlight.MouseButton1Up:Connect(function()
				if not self._currentSelection or self._currentSelection ~= edgeHighlight then
					return
				end

				if not self.Target then
					-- Set target selection state.
					self.Target = part
					self._targetObjectNormal = self._lastObjectNormal
					self._targetAlignmentCFrame = part.CFrame * edgeHighlight.CFrame
				else
					if SettingsService.Get("PlaceBetween") and self.Anchor then
						self.Anchor2 = self._currentSelection :: BasePart
						self._anchor2ObjectNormal = self._lastObjectNormal
						self._anchor2AlignmentCFrame = part.CFrame * edgeHighlight.CFrame
						if self.Anchor2 then
							self._ApplyManipulation()
						else
							self.OnSelectionChanged:FireDeferred()
						end
						self._currentSelection = nil
						return
					end

					-- Set anchor selection state.
					self.Anchor = part
					self._anchorObjectNormal = self._lastObjectNormal
					self._anchorAlignmentCFrame = part.CFrame * edgeHighlight.CFrame
				end

				if self.Anchor and not SettingsService.Get("PlaceBetween") then
					-- Both selections have been made, apply the manipulation.
					self._ApplyManipulation()
				else
					self.OnSelectionChanged:FireDeferred()
				end
				self._currentSelection = nil
			end))
		end
	end
	local cornerHighlights: { SphereHandleAdornment } = {}
	if not SettingsService.Get("ResizeTo") then
		-- Corner highlighting.
		cornerHighlights = HighlightHelper.HighlightCorners(part, objectNormal)
		for _, cornerHighlight in cornerHighlights do
			highlightTrove:Add(cornerHighlight)
			cornerHighlight.Color3 = highlightColors.Corner

			-- Handle corner highlight mouse events.
			highlightTrove:Add(cornerHighlight.MouseEnter:Connect(function()
				if self._lastHighlight then
					if self._lastHighlight.ClassName == "CylinderHandleAdornment" then
						(self._lastHighlight :: CylinderHandleAdornment).Color3 = highlightColors.Edge
					else
						(self._lastHighlight :: SphereHandleAdornment).Color3 = highlightColors.Corner
					end
				end
				self._hoveringOverEdgeOrCorner = true
				cornerHighlight.Color3 = highlightColors.Hover
				self._lastHighlight = cornerHighlight
			end))
			highlightTrove:Add(cornerHighlight.MouseLeave:Connect(function()
				self._hoveringOverEdgeOrCorner = false
				cornerHighlight.Color3 = highlightColors.Corner
				self._lastHighlight = nil
			end))
			highlightTrove:Add(cornerHighlight.MouseButton1Down:Connect(function()
				self._currentSelection = self._lastHighlight
			end))
			highlightTrove:Add(cornerHighlight.MouseButton1Up:Connect(function()
				if not self._currentSelection or self._currentSelection ~= cornerHighlight then
					return
				end

				if not self.Target then
					-- Set target selection state.
					self.Target = part
					self._targetObjectNormal = self._lastObjectNormal
					self._targetAlignmentCFrame = part.CFrame * cornerHighlight.CFrame
				else
					if SettingsService.Get("PlaceBetween") and self.Anchor then
						self.Anchor2 = self._currentSelection :: BasePart
						self._anchor2ObjectNormal = self._lastObjectNormal
						self._anchor2AlignmentCFrame = part.CFrame * cornerHighlight.CFrame
						if self.Anchor2 then
							self._ApplyManipulation()
						else
							self.OnSelectionChanged:FireDeferred()
						end
						self._currentSelection = nil
						return
					end

					-- Set anchor selection state.
					self.Anchor = part
					self._anchorObjectNormal = self._lastObjectNormal
					self._anchorAlignmentCFrame = part.CFrame * cornerHighlight.CFrame
				end

				if self.Anchor and not SettingsService.Get("PlaceBetween") then
					-- Both selections have been made, apply the manipulation.
					self._ApplyManipulation()
				else
					self.OnSelectionChanged:FireDeferred()
				end
				self._currentSelection = nil
			end))
		end

		-- Handle updating highlight sizes.
		highlightTrove:Add(RunService.Heartbeat:Connect(function()
			for _, edgeHighlight in edgeHighlights do
				HighlightHelper.UpdateEdgeHighlightSize(edgeHighlight)
			end
			for _, cornerHighlight in cornerHighlights do
				HighlightHelper.UpdateCornerHighlightSize(cornerHighlight)
			end
		end))
	end

	-- Handle color updating when changing the contrast setting.
	highlightTrove:Add(SettingsService.OnSettingChanged:Connect(function(settingName)
		if settingName ~= "ContrastPartHighlighting" then
			return
		end

		local highlightColors = SelectionService._GetHighlightColors(part)
		surfaceHighlight.Color = highlightColors.Surface
		if edgeHighlights and cornerHighlights then
			for _, edgeHighlight in edgeHighlights do
				if self._lastHighlight == edgeHighlight then
					edgeHighlight.Color3 = highlightColors.Hover
				else
					edgeHighlight.Color3 = highlightColors.Edge
				end
			end
			for _, cornerHighlight in cornerHighlights do
				if self._lastHighlight == cornerHighlight then
					cornerHighlight.Color3 = highlightColors.Hover
				else
					cornerHighlight.Color3 = highlightColors.Corner
				end
			end
		end
	end))
	return highlightTrove
end

function SelectionService._GetHighlightColors(part: BasePart): {
	Surface: Color3,
	Edge: Color3,
	Corner: Color3,
	Hover: Color3,
	Part: Color3,
}
	local surfaceColor
	local edgeColor
	local cornerColor
	local hoverHighlightColor
	local selectionBoxColor
	if SettingsService.Get("ContrastPartHighlighting") then
		selectionBoxColor = ColorHelper.GetContrastingColor({ part.Color }, HighlightHelper.HIGHLIGHT_COLORS.Part, 30)
		surfaceColor = ColorHelper.GetContrastingColor({ part.Color }, HighlightHelper.HIGHLIGHT_COLORS.Surface, 20)
		edgeColor = ColorHelper.GetContrastingColor({ part.Color, surfaceColor }, HighlightHelper.HIGHLIGHT_COLORS.Edge)
		cornerColor = ColorHelper.GetContrastingColor(
			{ part.Color, surfaceColor, edgeColor },
			HighlightHelper.HIGHLIGHT_COLORS.Corner
		)
		hoverHighlightColor = ColorHelper.GetContrastingColor(
			{ part.Color, surfaceColor, edgeColor, cornerColor },
			HighlightHelper.HIGHLIGHT_COLORS.Surface
		)
	else
		surfaceColor = HighlightHelper.HIGHLIGHT_COLORS.Surface[1]
		edgeColor = HighlightHelper.HIGHLIGHT_COLORS.Edge[1]
		cornerColor = HighlightHelper.HIGHLIGHT_COLORS.Corner[1]
		hoverHighlightColor = HighlightHelper.HIGHLIGHT_COLORS.Edge[2]
	end
	return {
		Surface = surfaceColor,
		Edge = edgeColor,
		Corner = cornerColor,
		Hover = hoverHighlightColor,
		Part = selectionBoxColor,
	}
end

function SelectionService._ApplyManipulation()
	local target = self.Target
	local anchor = self.Anchor
	local targetObjectNormal = self._targetObjectNormal
	local anchorObjectNormal = self._anchorObjectNormal
	if not target or not anchor or not targetObjectNormal or not anchorObjectNormal then
		self._ClearSelection(false)
		return
	end

	if SettingsService.Get("AlignTo") then
		local modeFunction = AlignTo.AttemptAlign
		local translations = RunWithUndo(
			modeFunction,
			target,
			anchor,
			targetObjectNormal,
			anchorObjectNormal,
			self._targetAlignmentCFrame,
			self._anchorAlignmentCFrame
		) :: { Method1: Vector3, Method2: Vector3 }?
		if translations then
			self._alignmentMethodSelectionEnabled = true
			self._alignmentTarget = target
			self._possibleAlignments = translations
			self._alignmentBoundingBoxes = self._CreateAlignmentBoundingBoxes()
			self._methodLabel = script.Parent.Parent.Parent.Assets.Ui.MethodLabel:Clone()
		end
	elseif SettingsService.Get("SetTo") then
		RunWithUndo(SetTo, target, anchor)
	elseif SettingsService.Get("AttachTo") then
		RunWithUndo(
			AttachTo,
			target,
			anchor,
			targetObjectNormal,
			anchorObjectNormal,
			self._targetAlignmentCFrame,
			self._anchorAlignmentCFrame
		)
	elseif SettingsService.Get("ResizeTo") then
		RunWithUndo(
			ResizeTo,
			target,
			anchor,
			targetObjectNormal,
			anchorObjectNormal,
			self._targetAlignmentCFrame,
			self._anchorAlignmentCFrame
		)
	elseif SettingsService.Get("PlaceBetween") then
		RunWithUndo(
			PlaceBetween,
			target,
			anchor,
			self.Anchor2,
			targetObjectNormal,
			anchorObjectNormal,
			self._anchor2ObjectNormal,
			self._targetAlignmentCFrame,
			self._anchorAlignmentCFrame,
			self._anchor2AlignmentCFrame
		)
	end
	self._ClearSelection(self._alignmentBoundingBoxes == nil)
end

function SelectionService._CreateAlignmentBoundingBoxes(): AlignmentBoundingBoxes?
	local target = self.Target
	local possibleAlignments = self._possibleAlignments
	if not target or not possibleAlignments then
		return nil
	end

	-- Create highlights.
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 0, 0)
	highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
	highlight.OutlineTransparency = 0
	highlight.FillTransparency = 0.75
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

	-- Create bounding box container.
	local boundingBoxes = Instance.new("Model") :: AlignmentBoundingBoxes
	boundingBoxes.Name = "AlignmentBoundingBoxes"

	-- Create bounding box 1.
	local box1 = target:Clone()
	box1.Name = "Method1"
	box1:ClearAllChildren()
	box1.Transparency = 0
	box1.CollisionGroup = "StudioUnselectable"
	box1.CFrame = target.CFrame + possibleAlignments.Method1
	highlight.Adornee = box1
	highlight.Parent = box1
	box1.Parent = boundingBoxes

	-- Create bounding box 2.
	local box2 = box1:Clone() :: BasePart & { Highlight: Highlight }
	box2.Name = "Method2"
	box2.CFrame = target.CFrame + possibleAlignments.Method2
	box2.Highlight.Adornee = box2
	box2.Parent = boundingBoxes
	boundingBoxes.Parent = Workspace.CurrentCamera
	return boundingBoxes
end

function SelectionService._ClearSelection(clearAlignmentMethod: boolean)
	-- Reset hover related state.
	self._lastSelection = nil
	self._lastHighlight = nil
	self._lastObjectNormal = nil
	if self._currentHighlightTrove then
		self._trove:Remove(self._currentHighlightTrove)
		self._currentHighlightTrove = nil
	end
	self._surfaceHighlight = nil

	-- Reset selection related state.
	self.Target = nil
	self.Anchor = nil
	self._hoveringOverEdgeOrCorner = false
	self._currentSelection = nil
	self._targetObjectNormal = nil
	self._anchorObjectNormal = nil
	self._targetAlignmentCFrame = nil
	self._anchorAlignmentCFrame = nil

	-- Reset alignment method selection related state.
	if clearAlignmentMethod then
		self._alignmentMethodSelectionEnabled = false
		self._alignmentTarget = nil
		self._possibleAlignments = nil
		if self._alignmentBoundingBoxes then
			pcall(game.Destroy, self._alignmentBoundingBoxes)
			self._alignmentBoundingBoxes = nil
		end
		if self._methodLabel then
			pcall(game.Destroy, self._methodLabel)
			self._methodLabel = nil
		end
		self._lastSelectedMethod = nil
		self._selectedAlignmentMethod = nil
	end

	-- Reset place between related state.
	self._anchor2 = nil
	self._anchor2ObjectNormal = nil
	self._anchor2AlignmentCFrame = nil

	-- Fire event for propagation.
	self.OnSelectionChanged:FireDeferred()
end

return SelectionService
