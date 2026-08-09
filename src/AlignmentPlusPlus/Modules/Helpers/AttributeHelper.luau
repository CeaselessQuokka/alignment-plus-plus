--!strict
-- Types --
export type Validator = (value: any, name: string) -> (boolean, string?)
export type Transformer<T> = (element: string) -> T

-- Variables --
const ERROR = [[

		[%s] Invalid Attribute
			Attribute: %q (%s)
			Reason: %s
			Instance: %s

]]

-- Attribute Helper --
const AttributeHelper = {}

function AttributeHelper.Get<T>(instance: Instance, name: string, validator: Validator?, default: T?): T?
	assert(typeof(instance) == "Instance", `Expected "instance" parameter to be an Instance`)
	assert(typeof(name) == "string", `Expected "name" parameter to be a string`)
	assert(
		typeof(validator) == "function" or validator == nil,
		`Expected "validator" parameter to be a function or nil`
	)

	const value = instance:GetAttribute(name)
	if validator and (value ~= nil or default ~= nil) then -- If value is nil and default is nil, then we skip validation for an implicit optional attribute.
		const isValid, reason = validator(value, name)
		assert(isValid, ERROR:format("Get", name, tostring(value), reason or "N/A", instance:GetFullName()))
	end
	-- GetAttribute is typed as unknown, and the validator is what actually vouches for the shape.
	return if value == nil then default else value :: any
end

-- The "with" parameter accepts any valid Lua pattern.
function AttributeHelper.GetWith(instance: Instance, with: string, truncateWith: boolean?): { [string]: any }
	assert(typeof(instance) == "Instance", `Expected "instance" parameter to be an Instance`)
	assert(typeof(with) == "string", `Expected "with" parameter to be a string`)
	assert(
		typeof(truncateWith) == "boolean" or truncateWith == nil,
		`Expected "truncateWith" parameter to be a boolean or nil`
	)

	const filteredAttributes: { [string]: any } = {}
	for name, value in instance:GetAttributes() do
		if name:find(with) then
			filteredAttributes[if truncateWith then name:gsub(with, "") else name] = value
		end
	end
	return filteredAttributes
end

function AttributeHelper.GetAsArray<T>(
	instance: Instance,
	name: string,
	stripWhitespace: boolean?, -- Defaults to false.
	validator: Validator?,
	transformer: Transformer<T>?,
	default: string?
): { T }
	assert(typeof(instance) == "Instance", `Expected "instance" parameter to be an Instance`)
	assert(typeof(name) == "string", `Expected "name" parameter to be a string`)
	assert(
		typeof(stripWhitespace) == "boolean" or stripWhitespace == nil,
		`Expected "stripWhitespace" parameter to be a boolean or nil`
	)
	assert(
		typeof(validator) == "function" or validator == nil,
		`Expected "validator" parameter to be a function or nil`
	)
	assert(
		typeof(transformer) == "function" or transformer == nil,
		`Expected "transformer" parameter to be a function or nil`
	)
	assert(typeof(default) == "string" or default == nil, `Expected "default" parameter to be a string or nil`)

	const value = instance:GetAttribute(name) or default
	assert(
		typeof(value) == "string" or value == nil,
		ERROR:format("GetAsArray", name, tostring(value), "Expected a string or nil", instance:GetFullName())
	)
	if value == nil or value == "" then
		return {}
	end

	const elements: { T } = {}
	for _, element in (value :: string):split(",") do
		if stripWhitespace then
			element = element:match("^%s*(.-)%s*$") or ""
		end
		if element == "" then
			continue
		end

		if validator then
			const isValid, reason = validator(element, name)
			assert(isValid, ERROR:format("GetAsArray -> for", name, element, reason or "N/A", instance:GetFullName()))
		end

		-- Without a transformer the element is its own result, which only the caller can name a type for.
		table.insert(elements, if transformer then transformer(element) else element :: any)
	end
	return elements
end

function AttributeHelper.GetAsSet<T>(
	instance: Instance,
	name: string,
	stripWhitespace: boolean?, -- Defaults to false.
	validator: Validator?,
	transformer: Transformer<T>?,
	default: string?
): { [T]: boolean }
	const set: { [T]: boolean } = {}
	for _, element in AttributeHelper.GetAsArray(instance, name, stripWhitespace, validator, transformer, default) do
		set[element] = true
	end
	return set
end

function AttributeHelper.OnAttributeChanged<T>(
	instance: Instance,
	name: string,
	callback: (newValue: T) -> (),
	validator: Validator?,
	default: T?
): RBXScriptConnection
	assert(typeof(instance) == "Instance", `Expected "instance" parameter to be an Instance`)
	assert(typeof(name) == "string", `Expected "name" parameter to be a string`)
	assert(typeof(callback) == "function", `Expected "callback" parameter to be a function`)
	assert(
		typeof(validator) == "function" or validator == nil,
		`Expected "validator" parameter to be a function or nil`
	)

	const function OnAttributeChanged()
		-- Get is optional by nature, but a caller that supplied a default is guaranteed a value back.
		callback(AttributeHelper.Get(instance, name, validator, default) :: any)
	end
	task.defer(OnAttributeChanged)
	return instance:GetAttributeChangedSignal(name):Connect(OnAttributeChanged)
end

return table.freeze(AttributeHelper)
