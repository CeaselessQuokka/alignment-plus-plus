--!strict
-- Services --
const ChangeHistoryService = game:GetService("ChangeHistoryService")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")
const Workspace = game:GetService("Workspace")

-- Imports --
const Signal = require(script.Parent.Parent.Packages.Signal)
const Trove = require(script.Parent.Parent.Packages.Trove)

const InputService = require(script.Parent.InputService)
const SettingsService = require(script.Parent.SettingsService)

const ColorHelper = require(script.Parent.Parent.Helpers.ColorHelper)
const GeometryHelper = require(script.Parent.Parent.Helpers.GeometryHelper)
const HighlightHelper = require(script.Parent.Parent.Helpers.HighlightHelper)
const ModeHelper = require(script.Parent.Parent.Helpers.ModeHelper)
const ModelHelper = require(script.Parent.Parent.Helpers.ModelHelper)
const PickHelper = require(script.Parent.Parent.Helpers.PickHelper)

const AlignTo = require(script.Parent.Parent.Features.AlignTo)
const AttachTo = require(script.Parent.Parent.Features.AttachTo)
const PlaceBetween = require(script.Parent.Parent.Features.PlaceBetween)
const PointAt = require(script.Parent.Parent.Features.PointAt)
const ResizeTo = require(script.Parent.Parent.Features.ResizeTo)
const SetTo = require(script.Parent.Parent.Features.SetTo)

-- Types --
type Pick = PickHelper.Pick
type Mode = ModeHelper.Mode
type MethodLabel = typeof(script.Parent.Parent.Parent.Assets.Ui.MethodLabel)

-- What the cursor is currently over, before it has been committed to a slot.
type Hover = {
	Part: BasePart,
	Subject: ModelHelper.Subject,
	Basis: GeometryHelper.FaceBasis,
	Layout: HighlightHelper.Layout?, -- Only built while handles are being drawn.
	Element: GeometryHelper.Element,
	ElementIndex: number?,
	Colors: HighlightHelper.Colors,
	ColorsAreContrasting: boolean, -- Which mode the cached colors were built for.
	SlotColor: Color3, -- The slot this would fill, which the subject outline is drawn in.
	ShowsHandles: boolean,
}

-- Hover is rebuilt from scratch every frame, so a press and its release are matched on what was under the
-- cursor rather than on the identity of the table describing it.
type PressedElement = {
	Part: BasePart,
	Kind: GeometryHelper.PickKind,
	ElementIndex: number?,
}

-- The two candidate results of an alignment, drawn in the viewport for the user to choose between.
type AlignmentChoice = {
	Target: Pick,
	Translations: AlignTo.Translations,
	Ghosts: Model,
	Label: MethodLabel,
	Hovered: BasePart?,
}

-- Variables --
-- Changing any of these invalidates whatever is part way through being selected.
const SETTINGS_THAT_RESET_SELECTION: { [SettingsService.SettingName]: boolean } = table.freeze({
	AlignTo = true,
	AttachTo = true,
	PointAt = true,
	ResizeTo = true,
	SetTo = true,
	PlaceBetween = true,
	SubjectAutoModel = true,
	SubjectRootmostModel = true,
	SubjectPartOnly = true,
})

const GHOST_UNCHOSEN_COLOR = Color3.fromRGB(255, 0, 0)
const GHOST_CHOSEN_COLOR = Color3.fromRGB(0, 255, 0)

-- Handle outlines stay a flat dark color rather than following the palette, so that the shape of a buried
-- handle always reads against whatever it is buried in.
const OUTLINE_COLOR = Color3.fromRGB(0, 0, 0)

-- A ray long enough to cross any reasonable place, and a cap on how many rejected parts we will see through
-- before giving up.
const RAY_LENGTH = 2 ^ 14
const MAXIMUM_RAY_RETRIES = 16

-- How much nearer something has to be before it takes the hovered face away from under the cursor. Handles
-- float slightly proud of the surface, so a little slack stops the face flickering against its own highlight.
const STICKY_DEPTH_TOLERANCE = 0.1

-- Functions --
const function RunWithUndo<T>(fn: (...any) -> T?, ...): T?
	const recordingId = ChangeHistoryService:TryBeginRecording("AlignmentPlusPlus", "AlignmentPlusPlus")
	if not recordingId then
		return nil
	end

	const success, result: any = pcall(fn, ...)
	if success then
		ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Commit)
		return result
	end

	ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Cancel)
	warn(`[Alignment++] Could not complete the action because: {debug.traceback(tostring(result))}`)
	return nil
end

-- Selection Service --
const SelectionService = {
	-- Boilerplate
	Initialized = false,
	Started = false,
	_trove = Trove.new(),
	_plugin = nil :: Plugin?,

	-- Service Specific
	OnSelectionChanged = Signal.new() :: Signal.Signal<>,

	Picks = {} :: { Pick }, -- Selections committed so far, in slot order.
	HoverKind = nil :: GeometryHelper.PickKind?, -- What clicking right now would select.
	HoverSubject = nil :: ModelHelper.Subject?, -- What clicking right now would select it on.

	_mouse = nil :: PluginMouse?,
	_hover = nil :: Hover?,
	_surface = nil :: HighlightHelper.Surface?,
	_hoverBox = nil :: SelectionBox?,
	_pressed = nil :: PressedElement?, -- Guards against press and release landing on different things.
	_committedTrove = nil :: Trove.Trove?,
	_alignmentChoice = nil :: AlignmentChoice?,
}
const self = SelectionService

function SelectionService.Init(plugin: Plugin)
	assert(not self.Initialized, `{script.Name} was already initialized`)

	self._plugin = plugin
	self._mouse = plugin:GetMouse()
	self.Initialized = true
end

function SelectionService.Start()
	assert(self.Initialized, `{script.Name} was not initialized`)
	assert(not self.Started, `{script.Name} was already started`)

	const mouse = self._mouse :: PluginMouse

	-- Hover is resolved every frame rather than only on mouse movement, because zooming, orbiting and holding
	-- a modifier all change what is under the cursor without the cursor itself moving.
	self._trove:Add(RunService.Heartbeat:Connect(function()
		self._UpdateHover()
	end))

	self._trove:Add(mouse.Button1Down:Connect(function()
		if self._alignmentChoice then
			return
		end

		const hover = self._hover
		self._pressed = if hover
			then { Part = hover.Part, Kind = hover.Element.Kind, ElementIndex = hover.ElementIndex }
			else nil
	end))

	self._trove:Add(mouse.Button1Up:Connect(function()
		if self._alignmentChoice then
			self._ChooseAlignment()
			return
		end

		const hover = self._hover
		const pressed = self._pressed
		self._pressed = nil
		if
			not hover
			or not pressed
			or hover.Part ~= pressed.Part
			or hover.Element.Kind ~= pressed.Kind
			or hover.ElementIndex ~= pressed.ElementIndex
		then
			return
		end

		self._CommitPick(hover)
	end))

	self._trove:Add(UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if input.KeyCode == Enum.KeyCode.Escape then
			self.Clear()
		elseif input.KeyCode == Enum.KeyCode.Backspace and #self.Picks > 0 and not self._alignmentChoice then
			-- Stepping back one selection at a time is far less punishing than losing all of them.
			table.remove(self.Picks)
			self._RebuildCommittedVisuals()
			self.OnSelectionChanged:FireDeferred()
		end
	end))

	self._trove:Add(SettingsService.OnSettingChanged:Connect(function(settingName)
		if SETTINGS_THAT_RESET_SELECTION[settingName] then
			self.Clear()
		end
	end))

	self._trove:Add(ChangeHistoryService.OnUndo:Connect(function()
		self.Clear()
	end))

	-- Update service state.
	self.Started = true
end

function SelectionService.Stop()
	assert(self.Started, `{script.Name} was not started`)

	self._trove:Clean()
	self.Clear()
	self.Started = false
end

function SelectionService.Unload()
	pcall(self.Stop)
	self.OnSelectionChanged:DisconnectAll()
end

-- The slot the next click will fill, or nil once every slot is taken.
function SelectionService.GetCurrentSlot(): ModeHelper.Slot?
	return ModeHelper.GetActiveMode().Slots[#self.Picks + 1]
end

function SelectionService.IsChoosingAlignment(): boolean
	return self._alignmentChoice ~= nil
end

-- How far out from the picked part to reach for the thing a manipulation moves. A held modifier overrides the
-- setting, so the scope can be changed for a single pick without leaving the viewport.
function SelectionService.GetSubjectScope(mode: Mode): ModelHelper.SubjectScope
	if mode.PartsOnly or InputService.PartOnlyHeld then
		return "Part"
	elseif InputService.OutermostModelHeld then
		return "OutermostModel"
	elseif SettingsService.Get("SubjectPartOnly") then
		return "Part"
	elseif SettingsService.Get("SubjectRootmostModel") then
		return "OutermostModel"
	end
	return "NearestModel"
end

-- Where the cursor is on screen, derived by projecting a point along the mouse's own ray. Going through the
-- camera's projection this way guarantees the result lines up with WorldToViewportPoint, which is what handle
-- hit testing compares against.
function SelectionService._GetScreenPoint(): Vector2?
	const camera = Workspace.CurrentCamera
	const mouse = self._mouse
	if not camera or not mouse then
		return nil
	end

	const ray = mouse.UnitRay
	const projected = camera:WorldToViewportPoint(ray.Origin + (ray.Direction * 10))
	return Vector2.new(projected.X, projected.Y)
end

function SelectionService._GetRaycastParams(extraExclusions: { Instance }?): RaycastParams
	const mode = ModeHelper.GetActiveMode()
	const isTargetSlot = #self.Picks == 0
	const params = RaycastParams.new()

	-- Everything the plugin draws lives under the camera, so excluding it in one go keeps highlights, markers
	-- and ghosts out of selection rays even when brute force querying is on.
	const exclusions: { Instance } = { Workspace.CurrentCamera }
	if extraExclusions then
		table.move(extraExclusions, 1, #extraExclusions, #exclusions + 1, exclusions)
	end

	const target = self.Picks[1]
	if target then
		-- The thing being moved is never a valid anchor for itself.
		table.insert(exclusions, target.Part)

		-- Skipping the rest of the target's model is what stops an align from referencing the very model it is
		-- about to move. Modes that work inside a single model turn it off, and asking for parts only lifts it
		-- too, since at that point no model is being moved for it to protect.
		const filtersModel = mode.FiltersSubjectModel and not InputService.PartOnlyHeld
		if filtersModel and target.Subject:IsA("Model") then
			table.insert(exclusions, target.Subject)
		end
	end

	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions
	params.BruteForceAllSlow = SettingsService.Get(
		if isTargetSlot then "NoCanCollideQueryTargetSelectable" else "NoCanCollideQueryAnchorSelectable"
	)
	params.IgnoreWater = true
	return params
end

-- Casts into the scene, seeing through anything the current settings say is not selectable. Previously a
-- locked part simply blocked the ray, which made anything behind it unreachable.
function SelectionService._Raycast(): RaycastResult?
	const camera = Workspace.CurrentCamera
	const mouse = self._mouse
	if not camera or not mouse then
		return nil
	end

	const allowLocked =
		SettingsService.Get(if #self.Picks == 0 then "LockedTargetPartsSelectable" else "LockedAnchorPartsSelectable")
	const origin = camera.CFrame.Position
	const direction = mouse.UnitRay.Direction * RAY_LENGTH
	const skipped: { Instance } = {}
	for _ = 1, MAXIMUM_RAY_RETRIES do
		const result = Workspace:Raycast(origin, direction, self._GetRaycastParams(skipped))
		if not result then
			return nil
		end

		-- Terrain is a single part covering the whole place, so its faces, edges and corners describe the world
		-- bounds rather than anything you could point at. There is nothing any mode could do with it.
		const isSelectable = not result.Instance:IsA("Terrain") and (allowLocked or not result.Instance.Locked)
		if isSelectable then
			return result
		end
		table.insert(skipped, result.Instance)
	end
	return nil
end

function SelectionService._GetHighlightColors(part: BasePart): HighlightHelper.Colors
	const palette = HighlightHelper.HIGHLIGHT_COLORS
	if not SettingsService.Get("ContrastPartHighlighting") then
		return {
			Surface = palette.Surface[1],
			Edge = palette.Edge[1],
			Corner = palette.Corner[1],
			Hover = palette.Hover[1],
			Outline = OUTLINE_COLOR,
			Part = palette.Part[1],
		}
	end

	const partColor = ColorHelper.GetContrastingColor({ part.Color }, palette.Part, 30)
	const surface = ColorHelper.GetContrastingColor({ part.Color }, palette.Surface, 20)
	const edge = ColorHelper.GetContrastingColor({ part.Color, surface }, palette.Edge)
	const corner = ColorHelper.GetContrastingColor({ part.Color, surface, edge }, palette.Corner)
	return {
		Surface = surface,
		Edge = edge,
		Corner = corner,
		-- Deliberately the most distinct color available rather than the first merely acceptable one. A hover
		-- color that only just clears the threshold against the edge color is indistinguishable in practice,
		-- which is exactly the case this has to avoid.
		Hover = ColorHelper.GetMostContrastingColor({ part.Color, surface, edge, corner }, palette.Hover),
		Outline = OUTLINE_COLOR,
		Part = partColor,
	}
end

function SelectionService._ClearHoverVisuals()
	if self._surface then
		HighlightHelper.DestroySurface(self._surface)
		self._surface = nil
	end
	if self._hoverBox then
		self._hoverBox:Destroy()
		self._hoverBox = nil
	end
end

-- Whether the cursor is still on the face already being hovered, and if so how far away that face is.
--
-- Two different things count as still being on it. Sitting over one of its handles counts unconditionally,
-- because handles are drawn on top of everything: an edge buried inside a wall is plainly visible and has to
-- stay clickable, so nothing is allowed to steal it. Sitting over the face itself only counts while nothing
-- has come between the camera and it, since the face is drawn normally and really is hidden.
function SelectionService._GetStickDistance(
	hover: Hover,
	origin: Vector3,
	direction: Vector3,
	screenPoint: Vector2
): (boolean, number)
	if not hover.Part.Parent then
		return false, 0
	end

	if hover.ShowsHandles then
		const layout = HighlightHelper.ComputeLayout(hover.Part, hover.Basis)
		if HighlightHelper.HitTest(layout, screenPoint, true, true) then
			return true, 0 -- Zero so that no depth can outrank it.
		end
	end

	const faceDistance = HighlightHelper.GetFaceHitDistance(hover.Part, hover.Basis, origin, direction)
	return faceDistance ~= nil, faceDistance or 0
end

function SelectionService._UpdateHover()
	if self._alignmentChoice then
		self._UpdateAlignmentChoiceHover()
		return
	end

	const camera = Workspace.CurrentCamera
	const mouse = self._mouse
	const slot = SelectionService.GetCurrentSlot()
	const screenPoint = self._GetScreenPoint()
	const result = if slot then self._Raycast() else nil

	-- Stay on the face already being hovered unless the cursor has left it, or something has come between the
	-- camera and it. Without this, moving out towards an edge or corner would hop to a neighbouring face (or
	-- straight past the part) before the handle was ever reachable.
	const previous = self._hover
	local stuckPart: BasePart? = nil
	local stuckBasis: GeometryHelper.FaceBasis? = nil
	if previous and slot and screenPoint and camera and mouse then
		const isStillOn, stickDistance =
			self._GetStickDistance(previous, camera.CFrame.Position, mouse.UnitRay.Direction.Unit, screenPoint)
		if isStillOn and (not result or result.Distance >= stickDistance - STICKY_DEPTH_TOLERANCE) then
			stuckPart = previous.Part
			stuckBasis = previous.Basis
		end
	end

	if not slot or not screenPoint or (not result and not stuckPart) then
		if self._hover then
			self._hover = nil
			self.HoverKind = nil
			self.HoverSubject = nil
			self._ClearHoverVisuals()
			self.OnSelectionChanged:FireDeferred()
		end
		return
	end

	const part = stuckPart or (result :: RaycastResult).Instance
	const mode = ModeHelper.GetActiveMode()
	const subject = ModelHelper.ResolveSubject(part, SelectionService.GetSubjectScope(mode))
	const basis = stuckBasis
		or GeometryHelper.GetFaceBasis(part.Size, part.CFrame:VectorToObjectSpace((result :: RaycastResult).Normal))
	const showsHandles = ModeHelper.IsSubElementPick(slot, InputService.WholePartHeld)

	-- Resolve which element of the face is under the cursor. Corners beat edges beat the face itself. The
	-- layout is only worth building when handles are actually in play, since this runs every frame.
	const layout = if showsHandles then HighlightHelper.ComputeLayout(part, basis) else nil
	local element: GeometryHelper.Element
	local elementIndex: number? = nil
	if layout then
		const hit, index = HighlightHelper.HitTest(layout, screenPoint, true, true)
		element = if hit then hit.Element else GeometryHelper.GetFaceElement(basis)
		elementIndex = index
	else
		element = GeometryHelper.GetPartElement(basis)
	end

	-- Contrasting colors are expensive to work out, so they are kept for as long as the hovered part and the
	-- setting that produced them both hold.
	const isContrasting = SettingsService.Get("ContrastPartHighlighting")
	local isSamePart = false
	local isSameFace = false
	local reusableColors: HighlightHelper.Colors? = nil
	if previous then
		isSamePart = previous.Part == part
		isSameFace = isSamePart and previous.Basis.Normal == basis.Normal
		if isSamePart and previous.ColorsAreContrasting == isContrasting then
			reusableColors = previous.Colors
		end
	end
	const colors = reusableColors or self._GetHighlightColors(part)

	-- Outline whatever a click would actually move, always, in the color of the slot it would fill. Without it
	-- there is no way to tell from the viewport whether a click takes the part, the model around it, or the
	-- outermost model, which is exactly what the scope modifiers change under you.
	const slotColor = Color3.fromHex(slot.Color)
	if
		previous == nil
		or previous.Subject ~= subject
		or previous.SlotColor ~= slotColor
		or previous.ShowsHandles ~= showsHandles
	then
		if self._hoverBox then
			self._hoverBox:Destroy()
		end
		self._hoverBox = HighlightHelper.CreateBox(subject, slotColor, not showsHandles)
	end

	-- Only rebuild the handles when the shape of what is drawn actually changes; otherwise just resize them so
	-- they hold their on screen size as the camera moves.
	const needsRebuild = previous == nil or previous.ShowsHandles ~= showsHandles or not isSameFace
	if needsRebuild then
		if self._surface then
			HighlightHelper.DestroySurface(self._surface)
			self._surface = nil
		end
		if layout then
			self._surface = HighlightHelper.CreateSurface(layout, true, true)
		end
	elseif self._surface and layout then
		HighlightHelper.UpdateSurface(self._surface, layout)
	end

	if self._surface then
		HighlightHelper.ColorSurface(self._surface, colors, element.Kind, elementIndex)
	end

	const changed = previous == nil
		or previous.Part ~= part
		or previous.Subject ~= subject
		or previous.ShowsHandles ~= showsHandles
		or previous.Element.Kind ~= element.Kind
		or previous.ElementIndex ~= elementIndex
		or previous.Basis.Normal ~= basis.Normal
	self._hover = {
		Part = part,
		Subject = subject,
		Basis = basis,
		Layout = layout,
		Element = element,
		ElementIndex = elementIndex,
		Colors = colors,
		ColorsAreContrasting = isContrasting,
		SlotColor = slotColor,
		ShowsHandles = showsHandles,
	}
	self.HoverKind = element.Kind
	self.HoverSubject = subject
	if changed then
		self.OnSelectionChanged:FireDeferred()
	end
end

function SelectionService._CommitPick(hover: Hover)
	const mode = ModeHelper.GetActiveMode()
	const pick = PickHelper.Create(
		hover.Part,
		hover.Subject,
		hover.Basis.Normal,
		hover.Element,
		hover.ElementIndex,
		SettingsService.Get("RespectPartPivot")
	)
	table.insert(self.Picks, pick)
	self._ClearHoverVisuals()
	self._hover = nil
	self.HoverKind = nil
	self.HoverSubject = nil

	if #self.Picks >= #mode.Slots then
		self._Apply(mode)
		return
	end

	self._RebuildCommittedVisuals()
	self.OnSelectionChanged:FireDeferred()
end

-- Draws an outline (and a point marker for sub-element picks) for everything selected so far.
function SelectionService._RebuildCommittedVisuals()
	if self._committedTrove then
		self._committedTrove:Destroy()
		self._committedTrove = nil
	end
	if #self.Picks == 0 then
		return
	end

	const trove = Trove.new()
	const mode = ModeHelper.GetActiveMode()
	for index, pick in self.Picks do
		const slot = mode.Slots[index]
		if not slot then
			continue
		end

		const color = Color3.fromHex(slot.Color)
		trove:Add(HighlightHelper.CreateBox(pick.Subject, color, pick.Kind == "Part"))
		if pick.Kind ~= "Part" then
			const marker = trove:Add(HighlightHelper.CreateMarker(pick.Point, color)) :: Part
			trove:Add(RunService.Heartbeat:Connect(function()
				HighlightHelper.UpdateMarker(marker)
			end))
		end
	end
	self._committedTrove = trove
end

function SelectionService._Apply(mode: Mode)
	const target = self.Picks[1]
	const anchor = self.Picks[2]
	if not target or not anchor then
		self.Clear()
		return
	end

	if mode.Name == "AlignTo" then
		const translations = RunWithUndo(AlignTo.Run, target, anchor) :: AlignTo.Translations?
		if translations then
			self._BeginAlignmentChoice(target, translations)
			return
		end
	elseif mode.Name == "AttachTo" then
		RunWithUndo(AttachTo, target, anchor)
	elseif mode.Name == "PointAt" then
		RunWithUndo(PointAt, target, anchor)
	elseif mode.Name == "ResizeTo" then
		RunWithUndo(ResizeTo, target, anchor, InputService.ExtendPastHeld)
	elseif mode.Name == "SetTo" then
		RunWithUndo(SetTo, target, anchor)
	elseif mode.Name == "PlaceBetween" then
		const secondAnchor = self.Picks[3]
		if secondAnchor then
			RunWithUndo(PlaceBetween, target, anchor, secondAnchor)
		end
	end
	self._FinishAction()
end

-- Resets for the next action, optionally holding on to the target so several operations can be chained
-- against the same object without reselecting it every time.
function SelectionService._FinishAction()
	const target = self.Picks[1]
	self.Clear()
	if target and SettingsService.Get("KeepTargetAfterAction") and target.Part.Parent then
		-- Rebuilt rather than reused, since the action may have moved or resized the part out from under the
		-- object space element the original pick was described by.
		table.insert(self.Picks, PickHelper.Refresh(target, SettingsService.Get("RespectPartPivot")))
		self._RebuildCommittedVisuals()
		self.OnSelectionChanged:FireDeferred()
	end
end

function SelectionService._BeginAlignmentChoice(target: Pick, translations: AlignTo.Translations)
	const ghosts = Instance.new("Model")
	ghosts.Name = "QDT_AlignmentPlusPlusAlignmentGhosts"
	ghosts.Archivable = false

	const function CreateGhost(name: string, translation: Vector3): BasePart
		local ghost: BasePart
		if target.Subject:IsA("Model") then
			const boundingCFrame, size = target.Subject:GetBoundingBox()
			ghost = Instance.new("Part")
			ghost.Size = size
			ghost.CFrame = boundingCFrame + translation
		else
			ghost = (target.Subject :: BasePart):Clone()
			ghost:ClearAllChildren()
			ghost.CFrame = (target.Subject :: BasePart).CFrame + translation
		end
		ghost.Name = name
		ghost.Anchored = true
		ghost.Archivable = false
		ghost.CanCollide = false
		-- A ghost cloned from the target inherits its CanQuery, and these have to stay queryable or the ray
		-- that works out which one is being hovered would pass straight through them.
		ghost.CanQuery = true
		ghost.CanTouch = false
		ghost.CastShadow = false
		ghost.CollisionGroup = "StudioUnselectable"
		ghost.Locked = false
		-- Highlights do not draw over a fully transparent part, and a ghost cloned from the target inherits
		-- whatever transparency that had, so it is pinned opaque here.
		ghost.Transparency = 0

		const highlight = Instance.new("Highlight")
		highlight.Adornee = ghost
		highlight.FillColor = GHOST_UNCHOSEN_COLOR
		highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
		highlight.OutlineTransparency = 0
		highlight.FillTransparency = 0.75
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = ghost
		ghost.Parent = ghosts
		return ghost
	end

	CreateGhost("AlongNormal", translations.AlongNormal)
	CreateGhost("NearestAxis", translations.NearestAxis)
	ghosts.Parent = Workspace.CurrentCamera

	self._alignmentChoice = {
		Target = target,
		Translations = translations,
		Ghosts = ghosts,
		Label = script.Parent.Parent.Parent.Assets.Ui.MethodLabel:Clone(),
		Hovered = nil,
	}
	self.OnSelectionChanged:FireDeferred()
end

function SelectionService._UpdateAlignmentChoiceHover()
	const choice = self._alignmentChoice :: AlignmentChoice
	const camera = Workspace.CurrentCamera
	const mouse = self._mouse
	if not camera or not mouse then
		return
	end

	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { choice.Ghosts }
	const result = Workspace:Raycast(camera.CFrame.Position, mouse.UnitRay.Direction * RAY_LENGTH, params)
	const hovered = if result then result.Instance else nil
	if hovered == choice.Hovered then
		return
	end

	choice.Hovered = hovered
	for _, ghost in choice.Ghosts:GetChildren() do
		const highlight = ghost:FindFirstChildOfClass("Highlight")
		if highlight then
			highlight.FillColor = if ghost == hovered then GHOST_CHOSEN_COLOR else GHOST_UNCHOSEN_COLOR
		end
	end

	if hovered then
		choice.Label.Method.Method.Text = if hovered.Name == "AlongNormal" then "Along Normal" else "Nearest Axis"
		choice.Label.Parent = hovered
	else
		choice.Label.Parent = nil
	end
end

function SelectionService._ChooseAlignment()
	const choice = self._alignmentChoice :: AlignmentChoice
	const hovered = choice.Hovered
	if not hovered then
		self.Clear()
		return
	end

	const translation = if hovered.Name == "AlongNormal"
		then choice.Translations.AlongNormal
		else choice.Translations.NearestAxis
	RunWithUndo(AlignTo.Align, choice.Target, translation)
	self._ClearAlignmentChoice()
	self._FinishAction()
end

function SelectionService._ClearAlignmentChoice()
	const choice = self._alignmentChoice
	if not choice then
		return
	end

	choice.Label.Parent = nil
	pcall(game.Destroy, choice.Label)
	pcall(game.Destroy, choice.Ghosts)
	self._alignmentChoice = nil
end

function SelectionService.Clear()
	self._ClearAlignmentChoice()
	self._ClearHoverVisuals()
	if self._committedTrove then
		self._committedTrove:Destroy()
		self._committedTrove = nil
	end

	self._hover = nil
	self.HoverKind = nil
	self.HoverSubject = nil
	self._pressed = nil
	table.clear(self.Picks)
	self.OnSelectionChanged:FireDeferred()
end

return SelectionService
