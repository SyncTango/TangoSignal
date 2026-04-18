local RunService = game:GetService("RunService")

local Logger = {}

local IsServer = RunService:IsServer()

function Logger:log(message: string): ()
	local prefix = IsServer and "Server" or "Client"

	print(`[{prefix}] {message}`)
end

return Logger
