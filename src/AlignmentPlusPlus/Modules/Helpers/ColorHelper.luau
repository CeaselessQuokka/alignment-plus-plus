--!strict
-- Color Helper --
const ColorHelper = {}

-- https://en.wikipedia.org/wiki/Color_difference#CIELAB_%CE%94E*
-- https://en.wikipedia.org/wiki/CIELAB_color_space
-- https://www.researchgate.net/publication/229511830_The_development_of_the_CIE_2000_colour-difference_formula_CIEDE2000
-- Coding this was utter pain :)
function ColorHelper.ComputeDeltaE2000(colorA: Color3, colorB: Color3): number
	local function ConvertRgbToLab(color: Color3): (number, number, number)
		local function f(t: number): number
			if t > 0.008856 then
				return t ^ (1 / 3)
			else
				return (7.787 * t) + (16 / 116)
			end
		end

		local r, g, b = color.R, color.G, color.B
		const lr = if r <= 0.04045 then r / 12.92 else ((r + 0.055) / 1.055) ^ 2.4
		const lg = if g <= 0.04045 then g / 12.92 else ((g + 0.055) / 1.055) ^ 2.4
		const lb = if b <= 0.04045 then b / 12.92 else ((b + 0.055) / 1.055) ^ 2.4
		const x = (lr * 0.4124564) + (lg * 0.3575761) + (lb * 0.1804375)
		const y = (lr * 0.2126729) + (lg * 0.7151522) + (lb * 0.0721750)
		const z = (lr * 0.0193339) + (lg * 0.1191920) + (lb * 0.9503041)
		const xr = x / 0.95047
		const yr = y
		const zr = z / 1.08883
		const fx = f(xr)
		const fy = f(yr)
		const fz = f(zr)
		return (116 * fy) - 16, 500 * (fx - fy), 200 * (fy - fz)
	end

	const TAU = math.pi * 2
	local l1, a1, b1 = ConvertRgbToLab(colorA)
	local l2, a2, b2 = ConvertRgbToLab(colorB)
	const c1 = math.sqrt((a1 ^ 2) + (b1 ^ 2))
	const c2 = math.sqrt((a2 ^ 2) + (b2 ^ 2))
	const cAvg = (c1 + c2) / 2
	const g = (1 - math.sqrt((cAvg ^ 7) / ((cAvg ^ 7) + (25 ^ 7)))) / 2
	const a1p = (1 + g) * a1
	const a2p = (1 + g) * a2
	const c1p = math.sqrt((a1p ^ 2) + (b1 ^ 2))
	const c2p = math.sqrt((a2p ^ 2) + (b2 ^ 2))
	local h1p = math.atan2(b1, a1p)
	local h2p = math.atan2(b2, a2p)
	h1p = if h1p < 0 then h1p + TAU else h1p
	h2p = if h2p < 0 then h2p + TAU else h2p
	const dlp = l2 - l1
	const dcp = c2p - c1p
	local dh, dhp, hAvgp
	if c1p < 1e-12 or c2p < 1e-12 then
		dh = 0
		dhp = 0
		hAvgp = (h1p + h2p) % TAU
	else
		dh = h2p - h1p
		if dh > math.pi then
			dh -= TAU
		elseif dh < -math.pi then
			dh += TAU
		end

		dhp = 2 * math.sqrt(math.max(0, (c1p * c2p))) * math.sin(dh / 2)

		if math.abs(h1p - h2p) <= math.pi then
			hAvgp = (h1p + h2p) / 2
		elseif h1p + h2p < TAU then
			hAvgp = (h1p + h2p + TAU) / 2
		else
			hAvgp = (h1p + h2p - TAU) / 2
		end
		if hAvgp < 0 then
			hAvgp += TAU
		elseif hAvgp >= TAU then
			hAvgp -= TAU
		end
		hAvgp = hAvgp % TAU
	end
	const lAvg = (l1 + l2) / 2
	const cAvgp = (c1p + c2p) / 2
	const sl = 1 + (0.015 * (lAvg - 50) ^ 2) / math.sqrt(20 + (lAvg - 50) ^ 2)
	const sc = 1 + (0.045 * cAvgp)
	const t = 1
		- (0.17 * math.cos(hAvgp - math.rad(30)))
		+ (0.24 * math.cos(2 * hAvgp))
		+ (0.32 * math.cos((3 * hAvgp) + math.rad(6)))
		- (0.2 * math.cos((4 * hAvgp) - math.rad(63)))
	const sh = 1 + (0.015 * cAvgp * t)
	const dt = math.rad(30) * math.exp(-(((hAvgp - math.rad(275)) / math.rad(25)) ^ 2))
	const rc = 2 * math.sqrt((cAvgp ^ 7) / (cAvgp ^ 7 + 25 ^ 7))
	const rt = -rc * math.sin(2 * dt)
	return math.sqrt((dlp / sl) ^ 2 + (dcp / sc) ^ 2 + (dhp / sh) ^ 2 + (rt * (dcp / sc) * (dhp / sh)))
end

-- The smallest perceptual distance between a color and any of a set of others. This is what "how well does
-- this stand out here" actually means: a color is only as distinct as its closest neighbour.
function ColorHelper.GetMinimumDeltaE(color: Color3, against: { Color3 }): number
	local smallest = math.huge
	for _, other in against do
		smallest = math.min(smallest, ColorHelper.ComputeDeltaE2000(color, other))
	end
	return smallest
end

-- Picks whichever candidate stands out the most against everything it has to be told apart from.
--
-- GetContrastingColor takes the first candidate clearing a threshold, which is fine for picking a readable
-- surface color but is not good enough for the hover color: it would happily land on something only just far
-- enough from the edge color to pass, leaving the two nearly indistinguishable in practice.
function ColorHelper.GetMostContrastingColor(mainColors: { Color3 }, colorList: { Color3 }): Color3
	local best = colorList[1]
	local bestDistance = -1
	for _, candidate in colorList do
		const distance = ColorHelper.GetMinimumDeltaE(candidate, mainColors)
		if distance > bestDistance then
			best = candidate
			bestDistance = distance
		end
	end
	return best
end

-- Takes the first candidate that clears a threshold against everything given, in list order, so the preferred
-- color wins whenever it is distinct enough. Falls back to whichever candidate comes closest to clearing.
function ColorHelper.GetContrastingColor(mainColors: { Color3 }, colorList: { Color3 }, threshold: number?): Color3
	const contrastThreshold = threshold or 30
	for _, listedColor in colorList do
		if ColorHelper.GetMinimumDeltaE(listedColor, mainColors) >= contrastThreshold then
			return listedColor
		end
	end
	return ColorHelper.GetMostContrastingColor(mainColors, colorList)
end

return table.freeze(ColorHelper)
