--!strict
local TangoSignal = {}
TangoSignal.__index = TangoSignal

type Props = {
	_callbacks: { (...any) -> () },
	_isDestroyed: boolean,
}

type Self = typeof(setmetatable({}, TangoSignal)) & Props

local Messages = require(script.Parent.Parent.constants.messages)
local Logger = require(script.Parent.Logger)

function TangoSignal.new(): Self
	local self: Self = setmetatable({}, TangoSignal) :: Self

	self._callbacks = {}
	self._isDestroyed = false

	return self
end

function TangoSignal.Fire(self: Self, ...: any): ()
	assert(not self._isDestroyed, Messages.ERROR_MESSAGES.ALREADY_DESTROYED)

	for _, callback in self._callbacks do
		local ok, err = pcall(callback :: any, ...)

		if not ok then
			Logger:log(Messages.ERROR_MESSAGES.SIGNAL_ERROR(err))
		end
	end
end

function TangoSignal.Connect(self: Self, callback: (...any) -> ()): { Disconnect: () -> () }
	assert(not self._isDestroyed, Messages.ERROR_MESSAGES.ALREADY_DESTROYED)

	table.insert(self._callbacks, callback)

	return {
		Disconnect = function()
			local index = table.find(self._callbacks, callback)

			if index then
				table.remove(self._callbacks, index)
			end
		end,
	}
end

function TangoSignal.await(self: Self): ...any
	assert(not self._isDestroyed, Messages.ERROR_MESSAGES.ALREADY_DESTROYED)

	local BindableEvent = Instance.new("BindableEvent")
	local connection

	connection = self:Connect(function(...)
		BindableEvent:Fire(...)

		connection:Disconnect()
	end)

	return BindableEvent.Event:Wait()
end

function TangoSignal.Destroy(self: Self): ()
	assert(not self._isDestroyed, Messages.ERROR_MESSAGES.ALREADY_DESTROYED)

	self._isDestroyed = true
end

return TangoSignal
