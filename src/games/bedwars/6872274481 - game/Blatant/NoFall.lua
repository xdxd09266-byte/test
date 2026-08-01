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
					groundHitEvent.SendToServer = function(self, data, ...)
						if NoFall.Enabled and type(data) == "table" and typeof(data.velocity) == "Vector3" then
							data = table.clone(data)
							data.velocity = Vector3.new(data.velocity.X, -10, data.velocity.Z)
						end
						return oldSendToServer(self, data, ...)
					end
				end
			else
				warningNotification('NoFall', 'Failed to find GroundHit event', 3)
			end
		end
	end,
	Tooltip = 'Prevents taking fall damage by spoofing impact velocity.'
})