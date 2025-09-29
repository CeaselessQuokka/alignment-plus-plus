--!strict
--- Services ---
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

--- Types ---
export type SurfaceHighlight = BasePart

--- Variables ---
local SURFACE_HIGHLIGHT_COLORS = {
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
}

local EDGE_HIGHLIGHT_COLORS = {
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
}

local CORNER_HIGHLIGHT_COLORS = {
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
}

local PART_HIGHLIGHT_COLORS = {
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
}

--- Functions ---
local function GetSizeBasedOffDistanceFromCamera(
	position: Vector3,
	minSize: number,
	preferredMaxSize: number,
	distanceThreshold: number
): number
	local camera = workspace.CurrentCamera
	local distance = (camera.CFrame.Position - position).Magnitude
	return minSize + ((preferredMaxSize - minSize) * (distance / distanceThreshold))
end

--- Highlight Helper ---
local HighlightHelper = {
	HIGHLIGHT_COLORS = {
		Surface = SURFACE_HIGHLIGHT_COLORS,
		Edge = EDGE_HIGHLIGHT_COLORS,
		Corner = CORNER_HIGHLIGHT_COLORS,
		Part = PART_HIGHLIGHT_COLORS,
	},
}

function HighlightHelper.HighlightSurface(part: BasePart, objectNormal: Vector3): SurfaceHighlight
	local function CreateHighlight(): SurfaceHighlight
		local highlight = Instance.new("Part")
		highlight.Name = "QDT_AlignmentPlusPlusSurfaceSurfaceHighlight"
		highlight.Anchored = true
		highlight.CanCollide = false
		highlight.CastShadow = false
		highlight.CollisionGroup = "StudioUnselectable"
		highlight.Locked = true
		highlight.Material = Enum.Material.SmoothPlastic
		highlight.BottomSurface = Enum.SurfaceType.Smooth
		highlight.TopSurface = Enum.SurfaceType.Smooth
		return highlight
	end

	local absObjectNormal = objectNormal:Abs()
	local planeSize = (Vector3.one - absObjectNormal) * part.Size
	local depthSize = absObjectNormal * 0.03125
	local highlight = CreateHighlight()
	highlight.Size = planeSize + depthSize
	highlight.Color = SURFACE_HIGHLIGHT_COLORS[1]
	highlight.CFrame = part.CFrame
		* CFrame.new(objectNormal * (part.Size:Dot(absObjectNormal) / 2) + (objectNormal * 0.015625))
	highlight.Parent = Workspace.CurrentCamera
	return highlight
end

function HighlightHelper.HighlightEdges(part: BasePart, objectNormal: Vector3): { CylinderHandleAdornment }
	local function GetEdgesFromObjectNormal(target: BasePart, normal: Vector3): { [CFrame]: number }
		local size = target.Size
		local halfSize = size / 2
		local xRotation = CFrame.Angles(math.pi / 2, 0, 0)
		local yRotation = CFrame.Angles(0, math.pi / 2, 0)
		local absNormal = normal:Abs()
		if absNormal == Vector3.xAxis then
			local sign = objectNormal:Sign().X
			return {
				[CFrame.new(sign * halfSize.X, halfSize.Y, 0)] = size.Z, -- Top
				[CFrame.new(sign * halfSize.X, -halfSize.Y, 0)] = size.Z, -- Bottom
				[CFrame.new(sign * halfSize.X, 0, halfSize.Z) * xRotation] = size.Y, -- Right
				[CFrame.new(sign * halfSize.X, 0, -halfSize.Z) * xRotation] = size.Y, -- Back
			}
		elseif absNormal == Vector3.yAxis then
			local sign = objectNormal:Sign().Y
			return {
				[CFrame.new(0, sign * halfSize.Y, -halfSize.Z) * yRotation] = size.X, -- Front
				[CFrame.new(0, sign * halfSize.Y, halfSize.Z) * yRotation] = size.X, -- Back
				[CFrame.new(-halfSize.X, sign * halfSize.Y, 0)] = size.Z, -- Left
				[CFrame.new(halfSize.X, sign * halfSize.Y, 0)] = size.Z, -- Right
			}
		else
			local sign = objectNormal:Sign().Z
			return {
				[CFrame.new(0, halfSize.Y, sign * halfSize.Z) * yRotation] = size.X, -- Top
				[CFrame.new(0, -halfSize.Y, sign * halfSize.Z) * yRotation] = size.X, -- Bottom
				[CFrame.new(-halfSize.X, 0, sign * halfSize.Z) * xRotation] = size.Y, -- Left
				[CFrame.new(halfSize.X, 0, sign * halfSize.Z) * xRotation] = size.Y, -- Right
			}
		end
	end

	local highlights: { CylinderHandleAdornment } = {}
	for edgeCFrame, highlightHeight in GetEdgesFromObjectNormal(part, objectNormal) do
		local highlight = Instance.new("CylinderHandleAdornment")
		highlight.Name = "QDT_AlignmentPlusPlusPartEdgeHighlight"
		highlight.CFrame = edgeCFrame
		highlight.Height = highlightHeight
		highlight.Color3 = EDGE_HIGHLIGHT_COLORS[1]
		highlight.Adornee = part
		HighlightHelper.UpdateEdgeHighlightSize(highlight)
		highlight.Parent = CoreGui
		table.insert(highlights, highlight)
	end
	return highlights
end

function HighlightHelper.HighlightCorners(part: BasePart, objectNormal: Vector3): { SphereHandleAdornment }
	local function GetCornersFromObjectNormal(target: BasePart, normal: Vector3): { CFrame }
		local halfSize = target.Size / 2
		local absNormal = normal:Abs()
		if absNormal == Vector3.xAxis then
			local sign = objectNormal:Sign().X
			return {
				CFrame.new(sign * halfSize.X, halfSize.Y, halfSize.Z), -- Top Right
				CFrame.new(sign * halfSize.X, halfSize.Y, -halfSize.Z), -- Top Back
				CFrame.new(sign * halfSize.X, -halfSize.Y, halfSize.Z), -- Bottom Right
				CFrame.new(sign * halfSize.X, -halfSize.Y, -halfSize.Z), -- Bottom Back
			}
		elseif absNormal == Vector3.yAxis then
			local sign = objectNormal:Sign().Y
			return {
				CFrame.new(halfSize.X, sign * halfSize.Y, halfSize.Z), -- Front Right
				CFrame.new(-halfSize.X, sign * halfSize.Y, halfSize.Z), -- Front Left
				CFrame.new(halfSize.X, sign * halfSize.Y, -halfSize.Z), -- Back Right
				CFrame.new(-halfSize.X, sign * halfSize.Y, -halfSize.Z), -- Back Left
			}
		else
			local sign = objectNormal:Sign().Z
			return {
				CFrame.new(halfSize.X, halfSize.Y, sign * halfSize.Z), -- Top Right
				CFrame.new(-halfSize.X, halfSize.Y, sign * halfSize.Z), -- Top Left
				CFrame.new(halfSize.X, -halfSize.Y, sign * halfSize.Z), -- Bottom Right
				CFrame.new(-halfSize.X, -halfSize.Y, sign * halfSize.Z), -- Bottom Left
			}
		end
	end

	local highlights: { SphereHandleAdornment } = {}
	for _, cornerCFrame in GetCornersFromObjectNormal(part, objectNormal) do
		local highlight = Instance.new("SphereHandleAdornment")
		highlight.Name = "QDT_AlignmentPlusPlusPartCornerHighlight"
		highlight.CFrame = cornerCFrame
		highlight.Color3 = CORNER_HIGHLIGHT_COLORS[1]
		highlight.Adornee = part
		HighlightHelper.UpdateCornerHighlightSize(highlight)
		highlight.ZIndex = 1
		highlight.Parent = CoreGui
		table.insert(highlights, highlight)
	end
	return highlights
end

function HighlightHelper.HighlightPart(part: BasePart): SelectionBox
	local highlight = Instance.new("SelectionBox")
	highlight.Name = "QDT_AlignmentPlusPlusPartHighlight"
	highlight.Adornee = part
	highlight.LineThickness = 0.0625
	highlight.Color3 = PART_HIGHLIGHT_COLORS[1]
	highlight.SurfaceColor3 = PART_HIGHLIGHT_COLORS[1]
	highlight.SurfaceTransparency = 0.75
	highlight.Parent = CoreGui
	return highlight
end

function HighlightHelper.UpdateEdgeHighlightSize(highlight: CylinderHandleAdornment)
	local part = highlight.Adornee :: BasePart
	local halfHeight = highlight.Height / 2
	local rx, ry = highlight.CFrame:ToOrientation()
	local topHighlightCFrame
	local bottomHighlightCFrame
	if rx > 0 then
		topHighlightCFrame = part.CFrame * CFrame.new(0, halfHeight, 0) * highlight.CFrame
		bottomHighlightCFrame = part.CFrame * CFrame.new(0, -halfHeight, 0) * highlight.CFrame
	elseif ry > 0 then
		topHighlightCFrame = part.CFrame * CFrame.new(halfHeight, 0, 0) * highlight.CFrame
		bottomHighlightCFrame = part.CFrame * CFrame.new(-halfHeight, 0, 0) * highlight.CFrame
	else
		topHighlightCFrame = part.CFrame * CFrame.new(0, 0, halfHeight) * highlight.CFrame
		bottomHighlightCFrame = part.CFrame * CFrame.new(0, 0, -halfHeight) * highlight.CFrame
	end
	local distances: { number } = {}
	local step = if highlight.Height / 5 < 10 then 0.25 else 1 / (highlight.Height / 5)
	for a = 0, 1, step do
		local cframe = topHighlightCFrame:Lerp(bottomHighlightCFrame, a)
		local distance = GetSizeBasedOffDistanceFromCamera(cframe.Position, 0.03125, 5, 700)
		table.insert(distances, distance)
	end
	table.insert(distances, GetSizeBasedOffDistanceFromCamera(bottomHighlightCFrame.Position, 0.03125, 5, 700)) -- Ensure bottom is included.
	highlight.Radius = math.min(table.unpack(distances))
end

function HighlightHelper.UpdateCornerHighlightSize(highlight: SphereHandleAdornment)
	local part = highlight.Adornee :: BasePart
	local position = (part.CFrame * highlight.CFrame).Position
	highlight.Radius = GetSizeBasedOffDistanceFromCamera(position, 0.09375, 12.5, 700)
end

return table.freeze(HighlightHelper)
