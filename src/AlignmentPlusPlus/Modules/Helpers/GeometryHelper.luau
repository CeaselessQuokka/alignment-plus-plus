--!strict
-- Types --
export type PickKind = "Part" | "Face" | "Edge" | "Corner"

-- An orthonormal description of one face of a part's bounding box, in object space.
export type FaceBasis = {
	Normal: Vector3, -- Signed unit axis pointing out of the face.
	U: Vector3, -- Unsigned unit axis lying in the face.
	V: Vector3, -- Unsigned unit axis lying in the face, perpendicular to U.
	HalfDepth: number, -- Half of the part's size along Normal.
	HalfU: number, -- Half of the part's size along U.
	HalfV: number, -- Half of the part's size along V.
	Center: Vector3, -- Object space center of the face.
}

-- One selectable element of the face being hovered.
--
-- Note that an edge or corner keeps the normal of the face it was picked on rather than its own bisector or
-- diagonal. Picking the right edge of the front face means "the front face, measured at its right edge", so
-- the direction a mode works along is the front normal and only the reference point moves.
export type Element = {
	Kind: PickKind,
	Position: Vector3, -- Object space reference point.
	Normal: Vector3, -- Object space normal of the face this element was picked on.
	Axes: { Vector3 }, -- Object space signed axes this element is able to drive when resizing.
	Direction: Vector3?, -- Object space unit vector running along the edge. Only present for edges.
	HalfLength: number?, -- Half the length of the edge. Only present for edges.
}

-- Variables --
const AXIS_VECTORS = table.freeze({ Vector3.xAxis, Vector3.yAxis, Vector3.zAxis })
const SIGNS = table.freeze({ 1, -1 })

-- Functions --
-- math.sign returns 0 for 0, which would collapse an axis to nothing. Faces always have a side, so bias to positive.
const function SignOf(value: number): number
	return if value < 0 then -1 else 1
end

-- Geometry Helper --
const GeometryHelper = {}

-- Collapses a direction onto the signed unit axis it points along the most. This removes the floating point noise
-- that raycast normals carry, and gives rounded parts (balls, cylinders, meshes) a sensible bounding box face.
function GeometryHelper.SnapToAxis(direction: Vector3): Vector3
	if direction.Magnitude < 1e-6 then
		return Vector3.xAxis
	end

	const absolute = direction:Abs()
	if absolute.X >= absolute.Y and absolute.X >= absolute.Z then
		return Vector3.xAxis * SignOf(direction.X)
	elseif absolute.Y >= absolute.Z then
		return Vector3.yAxis * SignOf(direction.Y)
	end
	return Vector3.zAxis * SignOf(direction.Z)
end

-- Returns the part's size along an axis. The axis does not need to be signed.
function GeometryHelper.GetExtentAlong(size: Vector3, axis: Vector3): number
	return size:Dot(axis:Abs())
end

-- Builds the in-plane axes for a face. The pairing is cyclic (X -> Y, Z | Y -> Z, X | Z -> X, Y) so that
-- U:Cross(V) always resolves back to the unsigned normal, which keeps corner and edge ordering stable.
function GeometryHelper.GetFaceBasis(size: Vector3, objectNormal: Vector3): FaceBasis
	const normal = GeometryHelper.SnapToAxis(objectNormal)
	const absoluteNormal = normal:Abs()
	local u, v
	if absoluteNormal == Vector3.xAxis then
		u, v = Vector3.yAxis, Vector3.zAxis
	elseif absoluteNormal == Vector3.yAxis then
		u, v = Vector3.zAxis, Vector3.xAxis
	else
		u, v = Vector3.xAxis, Vector3.yAxis
	end

	const halfDepth = GeometryHelper.GetExtentAlong(size, normal) / 2
	return {
		Normal = normal,
		U = u,
		V = v,
		HalfDepth = halfDepth,
		HalfU = GeometryHelper.GetExtentAlong(size, u) / 2,
		HalfV = GeometryHelper.GetExtentAlong(size, v) / 2,
		Center = normal * halfDepth,
	}
end

-- The face itself, as a single element owning only the axis it faces along.
function GeometryHelper.GetFaceElement(basis: FaceBasis): Element
	return {
		Kind = "Face",
		Position = basis.Center,
		Normal = basis.Normal,
		Axes = { basis.Normal },
	}
end

-- The four edges bounding the face. Two run along V and two run along U.
--
-- An edge drives the same single axis its face does, so resizing one extends that face until the edge lands
-- where it was told to, leaving the two faces either side of it alone.
function GeometryHelper.GetEdgeElements(basis: FaceBasis): { Element }
	const edges: { Element } = {}
	for _, sign in SIGNS do
		table.insert(edges, {
			Kind = "Edge" :: PickKind,
			Position = basis.Center + (basis.U * basis.HalfU * sign),
			Normal = basis.Normal,
			Axes = { basis.Normal },
			Direction = basis.V,
			HalfLength = basis.HalfV,
		})
	end
	for _, sign in SIGNS do
		table.insert(edges, {
			Kind = "Edge" :: PickKind,
			Position = basis.Center + (basis.V * basis.HalfV * sign),
			Normal = basis.Normal,
			Axes = { basis.Normal },
			Direction = basis.U,
			HalfLength = basis.HalfU,
		})
	end
	return edges
end

-- The four corners bounding the face.
--
-- Unlike an edge, a corner drives all three axes, since there is no single face a corner belongs to more than
-- the other two. That is what lets a corner resize land exactly on a point.
function GeometryHelper.GetCornerElements(basis: FaceBasis): { Element }
	const corners: { Element } = {}
	for _, signU in SIGNS do
		for _, signV in SIGNS do
			const offsetU = basis.U * signU
			const offsetV = basis.V * signV
			table.insert(corners, {
				Kind = "Corner" :: PickKind,
				Position = basis.Center + (offsetU * basis.HalfU) + (offsetV * basis.HalfV),
				Normal = basis.Normal,
				Axes = { basis.Normal, offsetU, offsetV },
			})
		end
	end
	return corners
end

-- The part as a whole. The reference point is the part's center, and the normal is kept as the face that was
-- looked at so that modes which still want a direction (such as Align To) behave the same as a face pick.
function GeometryHelper.GetPartElement(basis: FaceBasis): Element
	return {
		Kind = "Part",
		Position = Vector3.zero,
		Normal = basis.Normal,
		Axes = { basis.Normal },
	}
end

-- Rebuilds an element from the face it belongs to and its position within that face. Elements are described in
-- object space and depend on the part's size, so anything that outlives a resize has to be rebuilt rather than
-- kept around.
function GeometryHelper.BuildElement(size: Vector3, faceNormal: Vector3, kind: PickKind, index: number?): Element
	const basis = GeometryHelper.GetFaceBasis(size, faceNormal)
	if kind == "Part" then
		return GeometryHelper.GetPartElement(basis)
	elseif kind == "Face" then
		return GeometryHelper.GetFaceElement(basis)
	elseif kind == "Edge" then
		return GeometryHelper.GetEdgeElements(basis)[index or 1]
	end
	return GeometryHelper.GetCornerElements(basis)[index or 1]
end

-- Returns the point on a bounding box furthest along a direction. Used to keep whole part picks flush against
-- an anchor rather than burying the part's center in it.
function GeometryHelper.GetSupportPoint(size: Vector3, direction: Vector3): Vector3
	const half = size / 2
	return Vector3.new(half.X * SignOf(direction.X), half.Y * SignOf(direction.Y), half.Z * SignOf(direction.Z))
end

-- Solves for how far a point must travel along a direction to land on a plane. Returns nil when the direction
-- runs parallel to the plane, in which case there is no intersection to speak of.
function GeometryHelper.IntersectPlane(
	origin: Vector3,
	direction: Vector3,
	planePoint: Vector3,
	planeNormal: Vector3
): number?
	const denominator = direction:Dot(planeNormal)
	if math.abs(denominator) < 1e-6 then
		return nil
	end
	return (planePoint - origin):Dot(planeNormal) / denominator
end

-- The shortest rotation that takes one unit direction onto another. Falls back to any perpendicular axis when
-- the directions are exactly opposed, since the rotation axis is undefined there.
function GeometryHelper.GetRotationBetween(from: Vector3, to: Vector3): CFrame
	const dot = math.clamp(from:Dot(to), -1, 1)
	if dot > 1 - 1e-6 then
		return CFrame.identity
	end

	local axis = from:Cross(to)
	if axis.Magnitude < 1e-6 then
		-- Exactly opposed, so pick whichever world axis is least aligned with the direction to rotate around.
		local fallback = AXIS_VECTORS[1]
		local smallest = math.huge
		for _, candidate in AXIS_VECTORS do
			const alignment = math.abs(candidate:Dot(from))
			if alignment < smallest then
				smallest = alignment
				fallback = candidate
			end
		end
		axis = from:Cross(fallback)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end

return table.freeze(GeometryHelper)
