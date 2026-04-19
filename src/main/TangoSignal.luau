--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TangoSignal = {}
TangoSignal.__index = TangoSignal

type Props = {
	_callbacks: { (...any) -> () },
	_isDestroyed: boolean,
}

type Self = typeof(setmetatable({}, TangoSignal)) & Props

local messages = require(ReplicatedStorage.constants.messages)
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

--TODO
function TangoSignal.await(self: Self): ...any
	assert(not self._isDestroyed, Messages.ERROR_MESSAGES.ALREADY_DESTROYED)

	local runningThread = coroutine.running()
	local connection

	connection = self:Connect(function(...)
		connection:Disconnect()

		coroutine.resume(runningThread, ...)
	end)

	return coroutine.yield()
end

function TangoSignal.awaitWithTimeout(self: Self, timeout: number): ...any
	assert(not self._isDestroyed, Messages.ERROR_MESSAGES.ALREADY_DESTROYED)

	local runningThread = coroutine.running()
	local connection

	local hasResumed = false

	task.delay(timeout, function()
		if hasResumed then
			return
		end

		hasResumed = true

		if connection then
			connection:Disconnect()
		end

		coroutine.resume(runningThread, nil)
	end)

	connection = self:Connect(function(...)
		if hasResumed then
			return
		end

		if connection then
			connection:Disconnect()
		end

		coroutine.resume(runningThread, ...)
	end)

	return coroutine.yield()
end

function TangoSignal.Destroy(self: Self): ()
	assert(not self._isDestroyed, Messages.ERROR_MESSAGES.ALREADY_DESTROYED)

	self._isDestroyed = true
end

return TangoSignal
