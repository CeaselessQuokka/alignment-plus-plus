--!strict
-- Types --
export type InstanceName = string
export type InstanceClassName = string
export type InstanceSuperclassName = string

export type Hierarchy = HierarchyData | {
	[InstanceName]: HierarchyData,
}
export type HierarchyData = {
	Name: string?,
	Class: InstanceClassName?, -- Note: IsA takes precedence
	IsA: InstanceSuperclassName?,
	Children: Hierarchy?,
}

type Component = {
	Instance: Instance,
	Tag: string,
}

type Extension = {
	ShouldConstruct: (component: Component) -> boolean,
}

-- HierarchyIs Component Extension --
--[[

	Elevator Hierarchy Example:
	{
		-- Name is only for the root instance in theory, but can technically be used for any instance.
		Name = "Elevator",
		Class = "Model",
		Children = {
			Engine = {
				IsA = "BasePart",
				Children = {
					EngineAttachment = {
						Class = "Attachment",
					},
					Gyro = {
						Class = "AlignOrientation",
					},
					Motor = {
						Class = "AlignPosition",
					},
				},
			},
		},
	}

--]]
return function(hierarchy: Hierarchy): Extension
	return {
		ShouldConstruct = function(component: Component): boolean
			local function ValidateHierarchy(data: Hierarchy, instance: Instance)
				assert(
					data.Name == nil or instance.Name == data.Name,
					`[{component.Tag} ({instance:GetFullName()})] Must be Name: "{data.Name}" | got: "{instance.Name}"`
				)
				if data.IsA then
					assert(
						instance:IsA((data :: any).IsA),
						`[{component.Tag} ({instance:GetFullName()})] Must be IsA: "{data.IsA}" | got: "{instance.ClassName}"`
					)
				elseif data.Class then
					assert(
						instance.ClassName == data.Class,
						`[{component.Tag} ({instance:GetFullName()})] Must be ClassName: "{data.Class}" | got: "{instance.ClassName}"`
					)
				end

				if data.Children then
					for name: string, childData: HierarchyData in data.Children :: any do
						const child = instance:FindFirstChild(name)
						assert(child ~= nil, `[{component.Tag} ({instance:GetFullName()})] Missing child: "{name}"`)
						ValidateHierarchy(childData, child)
					end
				end
			end
			ValidateHierarchy(hierarchy, component.Instance)
			return true
		end,
	}
end
