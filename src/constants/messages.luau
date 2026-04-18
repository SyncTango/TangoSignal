--!strict

return {
	ERROR_MESSAGES = {
		SIGNAL_ERROR = function(err: string): string
			return "Signal error: " .. err
		end,

		ALREADY_DESTROYED = "Signal was already destroyed",
	},
}
