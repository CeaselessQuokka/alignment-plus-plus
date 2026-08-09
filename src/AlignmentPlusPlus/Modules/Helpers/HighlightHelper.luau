--!strict
-- Services --
const Workspace = game:GetService("Workspace")

-- Imports --
const GeometryHelper = require(script.Parent.GeometryHelper)

-- Types --
type Element = GeometryHelper.Element
type FaceBasis = GeometryHelper.FaceBasis

-- One drawable/hit testable element, resolved into world space at its on screen size.
export type LayoutElement = {
	Element: Element,
	Position: Vector3, -- World space reference point.
	Radius: number, -- World space radius, sized to hold a constant number of pixels on screen.
	PixelRadius: number, -- The same radius measured on screen, which is what hit testing compares against.
	Direction: Vector3?, -- World space vector running along the edge. Only present for edges.
	HalfLength: number?, -- Half the length of the edge. Only present for edges.
}

-- Everything that can be hovered on a single face, plus the sizes used to draw it. Recomputed as the camera
-- moves so that handles hold their on screen size no matter how far away the part is.
export type Layout = {
	Part: BasePart,
	Basis: FaceBasis,
	Face: LayoutElement,
	Edges: { LayoutElement },
	Corners: { LayoutElement },
	PlateOffset: number, -- How far to float the face plate off the surface to avoid z-fighting.
}

export type Colors = {
	Surface: Color3,
	Edge: Color3,
	Corner: Color3,
	Hover: Color3,
	Outline: Color3, -- Drawn around handles so they stay visible through whatever they are buried in.
	Part: Color3,
}

export type Surface = {
	Plate: Part,
	Edges: { Part },
	Corners: { Part },
}

-- Variables --
const SURFACE_HIGHLIGHT_COLORS = table.freeze({
	Color3.fromRGB(91, 133, 224),
	Color3.fromRGB(85, 184, 212),
	Color3.fromRGB(143, 112, 224),
	Color3.fromRGB(202, 110, 204),
	Color3.fromRGB(87, 171, 115),
	Color3.fromRGB(143, 202, 87),
	Color3.fromRGB(245, 213, 71),
	Color3.fromRGB(242, 148, 73),
	Color3.fromRGB(190, 136, 92),
	Color3.fromRGB(230, 99, 103),
	Color3.fromRGB(0, 0, 0),
	Color3.fromRGB(255, 255, 255),
})

const EDGE_HIGHLIGHT_COLORS = table.freeze({
	Color3.fromRGB(230, 99, 103),
	Color3.fromRGB(202, 110, 204),
	Color3.fromRGB(143, 112, 224),
	Color3.fromRGB(91, 133, 224),
	Color3.fromRGB(85, 184, 212),
	Color3.fromRGB(87, 171, 115),
	Color3.fromRGB(143, 202, 87),
	Color3.fromRGB(245, 213, 71),
	Color3.fromRGB(242, 148, 73),
	Color3.fromRGB(190, 136, 92),
	Color3.fromRGB(0, 0, 0),
	Color3.fromRGB(255, 255, 255),
})

const CORNER_HIGHLIGHT_COLORS = table.freeze({
	Color3.fromRGB(87, 171, 115),
	Color3.fromRGB(143, 202, 87),
	Color3.fromRGB(245, 213, 71),
	Color3.fromRGB(242, 148, 73),
	Color3.fromRGB(190, 136, 92),
	Color3.fromRGB(91, 133, 224),
	Color3.fromRGB(85, 184, 212),
	Color3.fromRGB(143, 112, 224),
	Color3.fromRGB(202, 110, 204),
	Color3.fromRGB(230, 99, 103),
	Color3.fromRGB(0, 0, 0),
	Color3.fromRGB(255, 255, 255),
})

-- Candidates for the hovered handle, brightest first. The one picked is whichever is furthest from the part
-- and from every other highlight color at once, so hovering is never a subtle shift of the same hue.
const HOVER_HIGHLIGHT_COLORS = table.freeze({
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 241, 118),
	Color3.fromRGB(0, 255, 255),
	Color3.fromRGB(255, 64, 255),
	Color3.fromRGB(64, 255, 128),
	Color3.fromRGB(255, 128, 0),
	Color3.fromRGB(0, 0, 0),
})

const PART_HIGHLIGHT_COLORS = table.freeze({
	Color3.fromRGB(190, 136, 92),
	Color3.fromRGB(242, 148, 73),
	Color3.fromRGB(245, 213, 71),
	Color3.fromRGB(91, 133, 224),
	Color3.fromRGB(85, 184, 212),
	Color3.fromRGB(143, 112, 224),
	Color3.fromRGB(202, 110, 204),
	Color3.fromRGB(87, 171, 115),
	Color3.fromRGB(143, 202, 87),
	Color3.fromRGB(230, 99, 103),
	Color3.fromRGB(0, 0, 0),
	Color3.fromRGB(255, 255, 255),
})

-- Handles are sized purely in pixels, so a handle is the same size to aim at no matter how near or far the
-- part is. Anything proportional to the part instead makes a big surface up close sprout handles that swallow
-- the viewport, and the neighbouring geometry behind them along with it.
const EDGE_RADIUS_PIXELS = 4.5
const CORNER_RADIUS_PIXELS = 7

-- The one exception: a handle is never allowed to eat the face it sits on. Thin parts viewed edge on would
-- otherwise end up with handles wider than the face itself, leaving the face impossible to click.
const EDGE_MAX_FACE_FRACTION = 0.18
const CORNER_MAX_FACE_FRACTION = 0.22

-- A little forgiveness so a handle is grabbable slightly before it is visually under the cursor.
const GRAB_TOLERANCE_PIXELS = 2

-- How much of a buried handle shows through. Mostly the outline, so a handle in open air still reads as solid
-- rather than glowing, while one behind geometry is still clearly there.
const OUTLINE_FILL_TRANSPARENCY = 0.55
const HOVERED_OUTLINE_FILL_TRANSPARENCY = 0.15

-- Matches the engine's minimum part size. The plate straddles the surface plane so that its outer face sits
-- just proud of the part while the rest stays buried inside it.
const PLATE_THICKNESS = 0.05

-- Functions --
const function CreateHighlightPart(name: string): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Archivable = false
	part.CanCollide = false
	part.CanQuery = false -- Keeps highlights out of every spatial query, including our own selection raycasts.
	part.CanTouch = false
	part.CastShadow = false
	part.CollisionGroup = "StudioUnselectable"
	part.Locked = true
	part.Massless = true
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Gives a handle an outline that draws through whatever it is buried in. A corner sitting below the floor, or
-- an edge inside a neighbouring part, is otherwise completely invisible and impossible to aim at.
const function AddOutline(handle: Part): Highlight
	const outline = Instance.new("Highlight")
	outline.Name = "Outline"
	outline.Adornee = handle
	outline.Archivable = false
	outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	outline.FillTransparency = OUTLINE_FILL_TRANSPARENCY
	outline.OutlineTransparency = 0
	outline.Parent = handle
	return outline
end

-- Highlight Helper --
const HighlightHelper = {
	HIGHLIGHT_COLORS = table.freeze({
		Surface = SURFACE_HIGHLIGHT_COLORS,
		Edge = EDGE_HIGHLIGHT_COLORS,
		Corner = CORNER_HIGHLIGHT_COLORS,
		Hover = HOVER_HIGHLIGHT_COLORS,
		Part = PART_HIGHLIGHT_COLORS,
	}),
}

-- How many studs one pixel covers at a given world point. Everything that wants a constant on screen size is
-- expressed as a pixel count multiplied by this.
function HighlightHelper.GetPixelScale(point: Vector3): number
	const camera = Workspace.CurrentCamera
	if not camera then
		return 0.01
	end

	const viewportHeight = math.max(camera.ViewportSize.Y, 1)
	const cameraCFrame = camera.CFrame
	const depth = math.max((point - cameraCFrame.Position):Dot(cameraCFrame.LookVector), 0.05)
	return (2 * depth * math.tan(math.rad(camera.FieldOfView) / 2)) / viewportHeight
end

-- Resolves a face into world space handle positions and radii.
function HighlightHelper.ComputeLayout(part: BasePart, basis: FaceBasis): Layout
	const partCFrame = part.CFrame
	const faceMinExtent = math.min(basis.HalfU, basis.HalfV) * 2
	const faceCenter = partCFrame * basis.Center

	const function Resolve(element: Element, pixels: number, maxFraction: number): LayoutElement
		const position = partCFrame * element.Position
		const pixelScale = HighlightHelper.GetPixelScale(position)
		const radius = math.max(math.min(pixels * pixelScale, faceMinExtent * maxFraction), 1e-4)
		return {
			Element = element,
			Position = position,
			Radius = radius,
			-- Derived from the clamped world radius rather than the requested pixel count, so what can be
			-- grabbed always matches what is actually drawn.
			PixelRadius = radius / pixelScale,
			Direction = if element.Direction then partCFrame:VectorToWorldSpace(element.Direction) else nil,
			HalfLength = element.HalfLength,
		}
	end

	const edges: { LayoutElement } = {}
	for _, edge in GeometryHelper.GetEdgeElements(basis) do
		table.insert(edges, Resolve(edge, EDGE_RADIUS_PIXELS, EDGE_MAX_FACE_FRACTION))
	end

	const corners: { LayoutElement } = {}
	for _, corner in GeometryHelper.GetCornerElements(basis) do
		table.insert(corners, Resolve(corner, CORNER_RADIUS_PIXELS, CORNER_MAX_FACE_FRACTION))
	end

	return {
		Part = part,
		Basis = basis,
		Face = {
			Element = GeometryHelper.GetFaceElement(basis),
			Position = faceCenter,
			Radius = 0,
			PixelRadius = 0,
		},
		Edges = edges,
		Corners = corners,
		-- Scaling the offset with distance keeps the plate a sub-pixel sliver above the surface at every zoom,
		-- so it neither z-fights up close nor visibly floats far away.
		PlateOffset = math.max(HighlightHelper.GetPixelScale(faceCenter), 0.002),
	}
end

-- Builds the parts used to draw a layout. Edges and corners are optional so that modes which only care about
-- whole parts or whole faces do not clutter the viewport with handles that do nothing.
function HighlightHelper.CreateSurface(layout: Layout, showEdges: boolean, showCorners: boolean): Surface
	const plate = CreateHighlightPart("QDT_AlignmentPlusPlusSurfaceHighlight")
	plate.Material = Enum.Material.SmoothPlastic
	plate.Color = SURFACE_HIGHLIGHT_COLORS[1]

	const edges: { Part } = {}
	if showEdges then
		for _ in layout.Edges do
			const edge = CreateHighlightPart("QDT_AlignmentPlusPlusEdgeHighlight")
			edge.Shape = Enum.PartType.Cylinder
			edge.Color = EDGE_HIGHLIGHT_COLORS[1]
			AddOutline(edge)
			table.insert(edges, edge)
		end
	end

	const corners: { Part } = {}
	if showCorners then
		for _ in layout.Corners do
			const corner = CreateHighlightPart("QDT_AlignmentPlusPlusCornerHighlight")
			corner.Shape = Enum.PartType.Ball
			corner.Color = CORNER_HIGHLIGHT_COLORS[1]
			AddOutline(corner)
			table.insert(corners, corner)
		end
	end

	const surface: Surface = { Plate = plate, Edges = edges, Corners = corners }
	HighlightHelper.UpdateSurface(surface, layout)

	-- Parented last so nothing is ever seen at a stale size for a frame.
	plate.Parent = Workspace.CurrentCamera
	for _, edge in edges do
		edge.Parent = Workspace.CurrentCamera
	end
	for _, corner in corners do
		corner.Parent = Workspace.CurrentCamera
	end
	return surface
end

-- Repositions and resizes an existing surface against a freshly computed layout.
function HighlightHelper.UpdateSurface(surface: Surface, layout: Layout)
	const basis = layout.Basis
	const partCFrame = layout.Part.CFrame
	const inPlaneSize = (basis.U * basis.HalfU * 2) + (basis.V * basis.HalfV * 2)

	surface.Plate.Size = inPlaneSize:Abs() + (basis.Normal:Abs() * PLATE_THICKNESS)
	surface.Plate.CFrame = partCFrame * CFrame.new(basis.Center + (basis.Normal * layout.PlateOffset))

	for index, edge in surface.Edges do
		const element = layout.Edges[index]
		const direction = element.Direction :: Vector3
		const bisector = partCFrame:VectorToWorldSpace(element.Element.Normal)
		edge.Size = Vector3.new((element.HalfLength :: number) * 2, element.Radius * 2, element.Radius * 2)
		edge.CFrame = CFrame.fromMatrix(element.Position, direction, bisector)
	end

	for index, corner in surface.Corners do
		const element = layout.Corners[index]
		corner.Size = Vector3.one * element.Radius * 2
		corner.CFrame = CFrame.new(element.Position)
	end
end

-- Applies the base colors, then paints whichever handle is hovered so it reads as the active one.
function HighlightHelper.ColorSurface(
	surface: Surface,
	colors: Colors,
	hoveredKind: GeometryHelper.PickKind,
	hoveredIndex: number?
)
	const function Paint(handle: Part, isHovered: boolean, baseColor: Color3)
		handle.Color = if isHovered then colors.Hover else baseColor

		-- The hovered handle also fills in more solidly, so it stands out even where the color alone would not
		-- carry, such as against a part of a similar shade.
		const outline = handle:FindFirstChildOfClass("Highlight")
		if outline then
			outline.FillColor = handle.Color
			outline.OutlineColor = if isHovered then colors.Hover else colors.Outline
			outline.FillTransparency = if isHovered
				then HOVERED_OUTLINE_FILL_TRANSPARENCY
				else OUTLINE_FILL_TRANSPARENCY
		end
	end

	surface.Plate.Color = if hoveredKind == "Face" or hoveredKind == "Part" then colors.Hover else colors.Surface
	for index, edge in surface.Edges do
		Paint(edge, hoveredKind == "Edge" and hoveredIndex == index, colors.Edge)
	end
	for index, corner in surface.Corners do
		Paint(corner, hoveredKind == "Corner" and hoveredIndex == index, colors.Corner)
	end
end

function HighlightHelper.DestroySurface(surface: Surface)
	surface.Plate:Destroy()
	for _, edge in surface.Edges do
		edge:Destroy()
	end
	for _, corner in surface.Corners do
		corner:Destroy()
	end
end

-- Screen space distance, in pixels, from a point on screen to a world point. Returns nil when the world point
-- sits behind the camera, where a projected position would be meaningless.
function HighlightHelper.GetPixelDistanceToPoint(screenPoint: Vector2, worldPoint: Vector3): number?
	const camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	const projected, onScreen = camera:WorldToViewportPoint(worldPoint)
	if not onScreen and projected.Z <= 0 then
		return nil
	end
	return (Vector2.new(projected.X, projected.Y) - screenPoint).Magnitude
end

-- Screen space distance, in pixels, from a point on screen to a world space segment. The segment is projected
-- and then measured in 2D, which is what the user actually perceives when aiming at a handle.
--
-- The segment is clipped against the camera's near plane first. Standing close to a large part puts one end of
-- a long edge behind the camera, and projecting a point from back there produces nonsense, so the edge used to
-- be silently unselectable despite running right across the screen.
function HighlightHelper.GetPixelDistanceToSegment(screenPoint: Vector2, from: Vector3, to: Vector3): number?
	const camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	const cameraCFrame = camera.CFrame
	const nearPlane = math.max(camera.NearPlaneZ and math.abs(camera.NearPlaneZ) or 0.1, 0.05)
	local nearDepth = (from - cameraCFrame.Position):Dot(cameraCFrame.LookVector)
	local farDepth = (to - cameraCFrame.Position):Dot(cameraCFrame.LookVector)
	local nearPoint = from
	local farPoint = to
	if nearDepth < nearPlane and farDepth < nearPlane then
		return nil
	elseif nearDepth < nearPlane then
		nearPoint = from:Lerp(to, (nearPlane - nearDepth) / (farDepth - nearDepth))
	elseif farDepth < nearPlane then
		farPoint = to:Lerp(from, (nearPlane - farDepth) / (nearDepth - farDepth))
	end

	const projectedFrom, _ = camera:WorldToViewportPoint(nearPoint)
	const projectedTo, _ = camera:WorldToViewportPoint(farPoint)
	const start = Vector2.new(projectedFrom.X, projectedFrom.Y)
	const finish = Vector2.new(projectedTo.X, projectedTo.Y)
	const segment = finish - start
	const lengthSquared = segment:Dot(segment)
	if lengthSquared < 1e-6 then
		return (screenPoint - start).Magnitude
	end

	const alpha = math.clamp((screenPoint - start):Dot(segment) / lengthSquared, 0, 1)
	return (screenPoint - (start + (segment * alpha))).Magnitude
end

-- Picks whichever handle in a layout the cursor is over, preferring corners over edges over the face itself.
-- Returns nil when edges and corners are not in play and the cursor is not near one.
function HighlightHelper.HitTest(
	layout: Layout,
	screenPoint: Vector2,
	testEdges: boolean,
	testCorners: boolean
): (LayoutElement?, number?)
	if testCorners then
		local closest: LayoutElement? = nil
		local closestIndex: number? = nil
		local closestDistance = math.huge
		for index, element in layout.Corners do
			const distance = HighlightHelper.GetPixelDistanceToPoint(screenPoint, element.Position)
			const limit = element.PixelRadius + GRAB_TOLERANCE_PIXELS
			if distance and distance <= limit and distance < closestDistance then
				closest = element
				closestIndex = index
				closestDistance = distance
			end
		end
		if closest then
			return closest, closestIndex
		end
	end

	if testEdges then
		local closest: LayoutElement? = nil
		local closestIndex: number? = nil
		local closestDistance = math.huge
		for index, element in layout.Edges do
			const direction = element.Direction :: Vector3
			const halfLength = element.HalfLength :: number
			const distance = HighlightHelper.GetPixelDistanceToSegment(
				screenPoint,
				element.Position - (direction * halfLength),
				element.Position + (direction * halfLength)
			)
			const limit = element.PixelRadius + GRAB_TOLERANCE_PIXELS
			if distance and distance <= limit and distance < closestDistance then
				closest = element
				closestIndex = index
				closestDistance = distance
			end
		end
		if closest then
			return closest, closestIndex
		end
	end

	return nil, nil
end

-- How far along a ray a face is hit, or nil when the ray misses the face's own rectangle.
--
-- This is what lets a face stay selected while the cursor travels out towards its edges and corners. Curved
-- geometry is the reason it is needed: on a sphere the surface normal turns continuously, so the face it
-- rounds to would otherwise flip to a neighbour well before the cursor ever reached a handle.
function HighlightHelper.GetFaceHitDistance(
	part: BasePart,
	basis: FaceBasis,
	origin: Vector3,
	unitDirection: Vector3
): number?
	const partCFrame = part.CFrame
	const normal = partCFrame:VectorToWorldSpace(basis.Normal)
	const denominator = unitDirection:Dot(normal)
	if math.abs(denominator) < 1e-6 then
		return nil
	end

	const center = partCFrame * basis.Center
	const distance = (center - origin):Dot(normal) / denominator
	if distance <= 0 then
		return nil
	end

	const offset = (origin + (unitDirection * distance)) - center
	const alongU = math.abs(offset:Dot(partCFrame:VectorToWorldSpace(basis.U)))
	const alongV = math.abs(offset:Dot(partCFrame:VectorToWorldSpace(basis.V)))
	if alongU > basis.HalfU or alongV > basis.HalfV then
		return nil
	end
	return distance
end

-- An outline around whatever a manipulation will move.
--
-- Filled in when the whole object is the selection, and left as a bare outline when a face, edge or corner of
-- it is. That way the object being moved is always shown, without the fill fighting the face plate drawn on
-- top of it.
function HighlightHelper.CreateBox(adornee: Instance, color: Color3, filled: boolean): SelectionBox
	const box = Instance.new("SelectionBox")
	box.Name = "QDT_AlignmentPlusPlusSelectionBox"
	box.Adornee = adornee
	box.Archivable = false
	box.LineThickness = 0.0625
	box.Color3 = color
	box.SurfaceColor3 = color
	box.SurfaceTransparency = if filled then 0.75 else 1
	box.Parent = Workspace.CurrentCamera
	return box
end

-- A small marker left on a locked in pick so the exact point being used stays visible while the next pick is
-- being made. Sized in pixels like the handles so it never balloons when the camera moves in.
function HighlightHelper.CreateMarker(position: Vector3, color: Color3): Part
	const marker = CreateHighlightPart("QDT_AlignmentPlusPlusSelectionMarker")
	marker.Shape = Enum.PartType.Ball
	marker.Color = color
	marker.Size = Vector3.one * CORNER_RADIUS_PIXELS * HighlightHelper.GetPixelScale(position) * 2
	marker.CFrame = CFrame.new(position)
	marker.Parent = Workspace.CurrentCamera
	return marker
end

function HighlightHelper.UpdateMarker(marker: Part)
	marker.Size = Vector3.one * CORNER_RADIUS_PIXELS * HighlightHelper.GetPixelScale(marker.Position) * 2
end

return table.freeze(HighlightHelper)
