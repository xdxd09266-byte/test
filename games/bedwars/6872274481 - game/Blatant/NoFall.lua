local NoFall
local groundHitEvent

local function findGroundHitEvent()
	local suc, tsRemotes = pcall(function() return require(game:GetService("ReplicatedStorage").TS.remotes).default end)
	if suc and tsRemotes then
		local suc2, event = pcall(function() return tsRemotes.Client:Get("GroundHit") end)
		if suc2 and event and type(event.SendToServer) == "function" then
			return event
		end
	end
	return nil
end

local oldSendToServer
NoFall = vape.Categories.Blatant:CreateModule({
	Name = 'NoFall',
	Function = function(callback)
		if callback then
			if not groundHitEvent then groundHitEvent = findGroundHitEvent() end
			
			if groundHitEvent then
				if not oldSendToServer then
					oldSendToServer = groundHitEvent.SendToServer
					groundHitEvent.SendToServer = function(self, blockHit, velocity, serverTime, ...)
						if NoFall.Enabled and typeof(velocity) == "Vector3" then
							velocity = Vector3.new(velocity.X, -10, velocity.Z)
						end
						return oldSendToServer(self, blockHit, velocity, serverTime, ...)
					end
				end
			else
				warningNotification('NoFall', 'Failed to find GroundHit event', 3)
			end
		end
	end,
	Tooltip = 'Prevents taking fall damage by spoofing impact velocity.'
})