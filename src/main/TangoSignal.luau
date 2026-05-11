local TangoSignal = {}
TangoSignal.__index = TangoSignal

type Props = {
	_callbacks: { (...any) -> () },
	_threads: { thread },
	_isDestroyed: boolean,
	_head: number,
}

type Self = typeof(setmetatable({}, TangoSignal)) & Props

local Messages = require(script.Parent.Parent.constants.messages)
local Logger = require(script.Parent.Logger)

local freeRunnerThread = nil

local function threadReuse()
	while true do
		local signal, args = coroutine.yield()

		local acquiredThread = freeRunnerThread
		freeRunnerThread = nil

		while signal._head ~= 0 do
			signal._head -= 1
			signal._callbacks[signal._head + 1](args)
		end
		freeRunnerThread = acquiredThread
	end
end

function TangoSignal.new(): Self
	local self: Self = setmetatable({}, TangoSignal) :: Self

	self._callbacks = {}
	self._threads = {}
	self._isDestroyed = false
	self._head = 0

	return self
end

function TangoSignal.Fire(self: Self, ...: any): ()
	assert(not self._isDestroyed, Messages.ERROR_MESSAGES.ALREADY_DESTROYED)

	self._head = #self._callbacks
	while self._head ~= 0 do
		if not freeRunnerThread then
			freeRunnerThread = coroutine.create(threadReuse)
			coroutine.resume(freeRunnerThread)
		end
		warn("EXECUTING!!!")
		task.spawn(freeRunnerThread, self, ...)
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
	assert(coroutine.isyieldable(), Messages.ERROR_MESSAGES.AWAIT_NOT_YIELDABLE)

	local runningThread = coroutine.running()
	local connection

	connection = self:Connect(function(...)
		connection:Disconnect()

		coroutine.resume(runningThread, ...)
	end)

	table.insert(self._threads, runningThread)

	return coroutine.yield()
end

function TangoSignal.awaitWithTimeout(self: Self, timeout: number): ...any
	assert(not self._isDestroyed, Messages.ERROR_MESSAGES.ALREADY_DESTROYED)
	assert(coroutine.isyieldable(), Messages.ERROR_MESSAGES.AWAIT_NOT_YIELDABLE)

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

		hasResumed = true

		if connection then
			connection:Disconnect()
		end

		coroutine.resume(runningThread, ...)
	end)

	table.insert(self._threads, runningThread)

	return coroutine.yield()
end

function TangoSignal.Destroy(self: Self): ()
	assert(not self._isDestroyed, Messages.ERROR_MESSAGES.ALREADY_DESTROYED)

	self._isDestroyed = true
	table.clear(self._callbacks)
	table.clear(self._threads)
	setmetatable(self, nil)
end

return TangoSignal
