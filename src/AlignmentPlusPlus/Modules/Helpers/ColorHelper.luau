--!strict
--- Color Helper ---
local ColorHelper = {}

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
		local lr = if r <= 0.04045 then r / 12.92 else ((r + 0.055) / 1.055) ^ 2.4
		local lg = if g <= 0.04045 then g / 12.92 else ((g + 0.055) / 1.055) ^ 2.4
		local lb = if b <= 0.04045 then b / 12.92 else ((b + 0.055) / 1.055) ^ 2.4
		local x = (lr * 0.4124564) + (lg * 0.3575761) + (lb * 0.1804375)
		local y = (lr * 0.2126729) + (lg * 0.7151522) + (lb * 0.0721750)
		local z = (lr * 0.0193339) + (lg * 0.1191920) + (lb * 0.9503041)
		local xr = x / 0.95047
		local yr = y
		local zr = z / 1.08883
		local fx = f(xr)
		local fy = f(yr)
		local fz = f(zr)
		return (116 * fy) - 16, 500 * (fx - fy), 200 * (fy - fz)
	end

	local TAU = math.pi * 2
	local l1, a1, b1 = ConvertRgbToLab(colorA)
	local l2, a2, b2 = ConvertRgbToLab(colorB)
	local c1 = math.sqrt((a1 ^ 2) + (b1 ^ 2))
	local c2 = math.sqrt((a2 ^ 2) + (b2 ^ 2))
	local cAvg = (c1 + c2) / 2
	local g = (1 - math.sqrt((cAvg ^ 7) / ((cAvg ^ 7) + (25 ^ 7)))) / 2
	local a1p = (1 + g) * a1
	local a2p = (1 + g) * a2
	local c1p = math.sqrt((a1p ^ 2) + (b1 ^ 2))
	local c2p = math.sqrt((a2p ^ 2) + (b2 ^ 2))
	local h1p = math.atan2(b1, a1p)
	local h2p = math.atan2(b2, a2p)
	h1p = if h1p < 0 then h1p + TAU else h1p
	h2p = if h2p < 0 then h2p + TAU else h2p
	local dlp = l2 - l1
	local dcp = c2p - c1p
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
	local lAvg = (l1 + l2) / 2
	local cAvgp = (c1p + c2p) / 2
	local sl = 1 + (0.015 * (lAvg - 50) ^ 2) / math.sqrt(20 + (lAvg - 50) ^ 2)
	local sc = 1 + (0.045 * cAvgp)
	local t = 1
		- (0.17 * math.cos(hAvgp - math.rad(30)))
		+ (0.24 * math.cos(2 * hAvgp))
		+ (0.32 * math.cos((3 * hAvgp) + math.rad(6)))
		- (0.2 * math.cos((4 * hAvgp) - math.rad(63)))
	local sh = 1 + (0.015 * cAvgp * t)
	local dt = math.rad(30) * math.exp(-(((hAvgp - math.rad(275)) / math.rad(25)) ^ 2))
	local rc = 2 * math.sqrt((cAvgp ^ 7) / (cAvgp ^ 7 + 25 ^ 7))
	local rt = -rc * math.sin(2 * dt)
	return math.sqrt((dlp / sl) ^ 2 + (dcp / sc) ^ 2 + (dhp / sh) ^ 2 + (rt * (dcp / sc) * (dhp / sh)))
end

function ColorHelper.GetContrastingColor(mainColors: { Color3 }, colorList: { Color3 }, threshold: number?)
	local contrastThreshold = threshold or 30
	local thresholds: { [Color3]: number } = {}
	for _, listedColor in colorList do
		local skip = false
		for _, color in mainColors do
			local deltaE = ColorHelper.ComputeDeltaE2000(color, listedColor)
			if deltaE < contrastThreshold then
				skip = true
				thresholds[listedColor] = deltaE
				break
			end
		end
		if not skip then
			return listedColor
		end
	end

	local color: Color3 = nil
	local maxContrast = -1
	for listedColor, deltaE in thresholds do
		if deltaE > maxContrast then
			maxContrast = deltaE
			color = listedColor
		end
	end
	return color
end

return ColorHelper
