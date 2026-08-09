--!strict
-- Imports --
const ModelHelper = require(script.Parent.Parent.Helpers.ModelHelper)
const PickHelper = require(script.Parent.Parent.Helpers.PickHelper)

-- Types --
type Pick = PickHelper.Pick

-- Place Between --
-- Every selection is just a point, so a face, an edge, a corner and a whole object can all be mixed freely
-- across the three picks without any of them being a special case.
return function(target: Pick, anchorA: Pick, anchorB: Pick)
	const midpoint = (anchorA.Point + anchorB.Point) / 2
	ModelHelper.Translate(target.Subject, midpoint - target.Point)
end
