--!strict
-- Services --
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")

-- Imports --
const Signal = require(script.Parent.Parent.Packages.Signal)
const Trove = require(script.Parent.Parent.Packages.Trove)

-- Variables --
-- Three keys cover everything that is worth changing mid-pick:
--
--   Alt   -- swap between picking a face, edge or corner and picking the whole object.
--   Ctrl  -- deal in parts only, ignoring whatever model they sit in. This also lets a pick land inside a
--            model an earlier pick already claimed, which is what Place Between needs.
--   Shift -- reach for the outermost model instead of the nearest one. Resize To only ever works on parts, so
--            there it means Extend Past instead: run the resize out to the anchor's plane rather than
--            stopping where the two selections meet.
const WHOLE_PART_KEYS = table.freeze({ Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt })
const PART_ONLY_KEYS = table.freeze({ Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl })
const OUTERMOST_MODEL_KEYS = table.freeze({ Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift })

-- Functions --
const function IsAnyKeyDown(keys: { Enum.KeyCode }): boolean
	for _, key in keys do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

-- Input Service --
const InputService = {
	-- Boilerplate
	Initialized = false,
	Started = false,
	_trove = Trove.new(),

	-- Service Specific
	OnModifiersChanged = Signal.new() :: Signal.Signal<>,

	WholePartHeld = false,
	PartOnlyHeld = false,
	OutermostModelHeld = false,
	ExtendPastHeld = false, -- The same key as OutermostModelHeld; only Resize To reads it.
}
const self = InputService

function InputService.Init()
	assert(not self.Initialized, `{script.Name} was already initialized`)

	self.Initialized = true
end

function InputService.Start()
	assert(self.Initialized, `{script.Name} was not initialized`)
	assert(not self.Started, `{script.Name} was already started`)

	-- Modifier state is polled rather than driven by InputBegan/InputEnded. Studio consumes plenty of key
	-- events for its own shortcuts, and a released key that never produced an event would otherwise leave a
	-- modifier stuck on indefinitely.
	self._trove:Add(RunService.Heartbeat:Connect(function()
		const wholePartHeld = IsAnyKeyDown(WHOLE_PART_KEYS)
		const partOnlyHeld = IsAnyKeyDown(PART_ONLY_KEYS)
		const outermostModelHeld = IsAnyKeyDown(OUTERMOST_MODEL_KEYS)
		if
			wholePartHeld == self.WholePartHeld
			and partOnlyHeld == self.PartOnlyHeld
			and outermostModelHeld == self.OutermostModelHeld
		then
			return
		end

		self.WholePartHeld = wholePartHeld
		self.PartOnlyHeld = partOnlyHeld
		self.OutermostModelHeld = outermostModelHeld
		self.ExtendPastHeld = outermostModelHeld
		self.OnModifiersChanged:Fire()
	end))

	-- Update service state.
	self.Started = true
end

function InputService.Stop()
	assert(self.Started, `{script.Name} was not started`)

	self._trove:Clean()
	self.WholePartHeld = false
	self.PartOnlyHeld = false
	self.OutermostModelHeld = false
	self.ExtendPastHeld = false
	self.Started = false
end

function InputService.Unload()
	pcall(self.Stop)
	self.OnModifiersChanged:DisconnectAll()
end

return InputService
