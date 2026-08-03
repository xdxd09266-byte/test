local AntiCrash
local MaxRate
local hooks = {}

local function throttleRemote(remote)
	local sent = 0
	local window = 0
	local old = hookfunction(remote.FireServer, function(self, ...)
		local now = os.clock()
		if now - window >= 1 then
			window = now
			sent = 0
		end
		if sent < MaxRate.Value then
			sent = sent + 1
			return old(self, ...)
		end
	end)
	table.insert(hooks, { remote, old })
end

AntiCrash = vape.Categories.Blatant:CreateModule({
	Name = 'AntiCrash',
	Function = function(callback)
		local events = game:GetService('ReplicatedStorage'):FindFirstChild('GameEvents')
		local combat = events and events:FindFirstChild('CombatRemotes')
		if not combat then return end
		if callback then
			for _, r in ipairs(combat:GetChildren()) do
				if r:IsA('RemoteEvent') then
					local name = r.Name:lower()
					if name:find('parry') or name:find('swing') or name:find('feint') or name:find('attack') or name:find('hit') then
						throttleRemote(r)
					end
				end
			end
			vape:CreateNotification('AntiCrash', 'Throttling combat remotes', 3)
		else
			for _, pair in hooks do
				pcall(hookfunction, pair[1].FireServer, pair[2])
			end
			hooks = {}
		end
	end,
	Tooltip = 'Rate-limits combat remotes so you never crash yourself.'
})
MaxRate = AntiCrash:CreateSlider({
	Name = 'Max Packets/s',
	Min = 10,
	Max = 5000,
	Default = 100,
	Suffix = '/s'
})
