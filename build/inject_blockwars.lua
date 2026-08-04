local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local collectionService = cloneref(game:GetService('CollectionService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local runService = cloneref(game:GetService('RunService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo

local bw = {}
local blocks = {}
local BlockTimes = {}
local ACDisabler
local bypassRoot
local isAttacking

local function applySpeed(speed, dt)
	local root = entitylib.character.RootPart
	local dest = (entitylib.character.Humanoid.MoveDirection * math.max((speed + (entitylib.character.Humanoid.WalkSpeed - 16)) - entitylib.character.Humanoid.WalkSpeed, 0) * dt)
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
	rayCheck.CollisionGroup = root.CollisionGroup

	local ray = workspace:Raycast(root.Position, dest, rayCheck)
	if ray then
		dest = ((ray.Position + ray.Normal) - root.Position)
	end
	root.CFrame += dest
end

local function collection(tags, module, customadd, customremove)
	tags = typeof(tags) ~= 'table' and {tags} or tags
	local objs, connections = {}, {}

	for _, tag in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if customadd then
				customadd(objs, v, tag)
				return
			end
			table.insert(objs, v)
		end))
		table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if customremove then
				customremove(objs, v, tag)
				return
			end
			v = table.find(objs, v)
			if v then
				table.remove(objs, v)
			end
		end))

		for _, v in collectionService:GetTagged(tag) do
			if customadd then
				customadd(objs, v, tag)
				continue
			end
			table.insert(objs, v)
		end
	end

	local cleanFunc = function(self)
		for _, v in connections do
			v:Disconnect()
		end
		table.clear(connections)
		table.clear(objs)
		table.clear(self)
	end
	if module then
		module:Clean(cleanFunc)
	end
	return objs, cleanFunc
end

local function getInventory()
	local inv = {}
	local backpack = lplr:FindFirstChildWhichIsA('Backpack')
	if backpack then
		inv = backpack:GetChildren()
	end

	local equipped = lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool')
	if equipped then
		table.insert(inv, equipped)
	end

	return inv
end

local function getTool()
	return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool')
end

run(function()
	local oldstart = entitylib.start
	local function customEntity(ent)
		entitylib.addEntity(ent, nil, function(self)
			return (lplr.Team and lplr.Team.Name or '') ~= self.Character:GetAttribute('TeamId')
		end)
	end

	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			for _, ent in collectionService:GetTagged('Attackable') do
				customEntity(ent)
			end
			table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('Attackable'):Connect(customEntity))
			table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('Attackable'):Connect(function(ent)
				entitylib.removeEntity(ent)
			end))
		end
	end
end)
entitylib.start()

run(function()
	bw = {
		RemoteIndex = require(replicatedStorage.Modules.RemotesIndex),
		BlockBreakConstants = require(replicatedStorage.Modules.Configs.BlockBreakConfig),
		ShopConfig = require(replicatedStorage.Modules.Configs.ShopConfig),
		Inventory = debug.getupvalue(require(replicatedStorage.Modules.ShopUIClient).Start, 8)
	}

	blocks = collection('BedWarsX_PlacedBlock', vape, function(tab, block)
		tab[block.Position // 3] = block
	end, function(tab, block)
		tab[block.Position // 3] = nil
	end)

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	task.delay(1, function()
		if workspace:GetAttribute('ServerType') ~= 'Lobby' then
			games:Increment()
		end
	end)

	vape:Clean(lplr:GetAttributeChangedSignal('RoundKills'):Connect(function()
		if lplr:GetAttribute('RoundKills') > 0 then
			kills:Increment()
		end
	end))

	vape:Clean(bw.RemoteIndex.Round_Event.OnClientEvent:Connect(function(data)
		if type(data) == 'table' and data.id == 'final_kill' then
			if lplr.Team and lplr.Team.Name == data.teamId then
				wins:Increment()
			end
		end
	end))

	vape:Clean(bw.RemoteIndex.Bed_Destroyed.OnClientEvent:Connect(function(data)
		if type(data) == 'table' and data.breakerId == lplr.UserId then
			beds:Increment()
		end
	end))

	vape:Clean(entitylib.Events.EntityAdded:Connect(function(entity)
		BlockTimes[entity.Character] = 0

		local animator = entity.Humanoid:FindFirstChild('Animator')
		if animator then
			table.insert(entity.Connections, animator.AnimationPlayed:Connect(function(track)
				if track.Animation.AnimationId == 'rbxassetid://99664081334494' or track.Animation.AnimationId == 'rbxassetid://75062274621204' then
					BlockTimes[entity.Character] = os.clock()
				end
			end))
		end
	end))

	vape:Clean(entitylib.Events.EntityRemoving:Connect(function(entity)
		BlockTimes[entity.Character] = nil
	end))
end)

for _, v in {'AimAssist', 'Reach', 'SilentAim', 'TriggerBot', 'Jesus', 'AutoRejoin', 'Disabler', 'FastProxPrompt', 'SafeWalk', 'MurderMystery'} do
	vape:Remove(v)
end

run(function()
local overParams = RaycastParams.new()
overParams.RespectCanCollide = true

local function clampVec(vec, max)
	if vec.Magnitude > max then
		return vec.Unit == vec.Unit and vec.Unit * max or Vector3.zero
	end

	return vec
end

ACDisabler = vape.Categories.Blatant:CreateModule({
	Name = 'AC Disabler',
	Function = function(callback)
		if callback then
			bypassRoot = Instance.new('Part')
			bypassRoot.CanCollide = false
			bypassRoot.CanQuery = false
			bypassRoot.Size = Vector3.new(2, 2, 1)
			bypassRoot.Material = Enum.Material.SmoothPlastic
			bypassRoot.Transparency = 1
			bypassRoot.Parent = workspace.CurrentCamera
			ACDisabler:Clean(bypassRoot)

			local oldcf, oldvelo
			local bindKey = game:GetService('HttpService'):GenerateGUID(true)
			runService:BindToRenderStep(bindKey, 0, function()
				if entitylib.isAlive and oldcf then
					entitylib.character.RootPart.CFrame = oldcf
				end
			end)

			ACDisabler:Clean(function()
				runService:UnbindFromRenderStep(bindKey)
			end)

			for _, connection in {entitylib.Events.LocalAdded, replicatedStorage.GameEvents.BedWarsRemotes.AntiCheat_Strike.OnClientEvent} do
				ACDisabler:Clean(connection:Connect(function()
					oldcf = nil
				end))
			end

			local tpTimer = 0
			local fallTimer = 0
			ACDisabler:Clean(runService.Heartbeat:Connect(function(dt)
				if entitylib.isAlive then
					local root = entitylib.character.RootPart
					if not oldcf then
						bypassRoot.CFrame = root.CFrame
					end
					oldcf = root.CFrame

					local diff = (oldcf.Position - bypassRoot.Position) * Vector3.new(1, 0, 1)
					local united = diff.Unit
					united = united == united and diff.Magnitude > 0.1 and united * entitylib.character.Humanoid.WalkSpeed or Vector3.zero
					bypassRoot.AssemblyLinearVelocity = Vector3.new(united.X, 0, united.Z)
					bypassRoot.CFrame = CFrame.lookAlong(Vector3.new(bypassRoot.Position.X, root.Position.Y, bypassRoot.Position.Z), root.CFrame.LookVector)
					if diff.Magnitude > 6 and (os.clock() - tpTimer) > 0.75 then
						bypassRoot.CFrame += clampVec(diff, entitylib.character.Humanoid.WalkSpeed)
						tpTimer = os.clock()
					end

					overParams.CollisionGroup = root.CollisionGroup
					overParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
					local flyCheck = workspace:Raycast(bypassRoot.Position, Vector3.new(0, -8, 0), overParams)
					if not flyCheck then
						if fallTimer == 0 then
							fallTimer = os.clock()
						end
						bypassRoot.CFrame -= Vector3.new(0, ((os.clock() - fallTimer) % 1) * 10, 0)
					else
						fallTimer = 0
					end

					root.CFrame = bypassRoot.CFrame
					if root.AssemblyLinearVelocity.Magnitude < 0.1 then
						root.AssemblyLinearVelocity += Vector3.new(0, -0.1, 0)
					end
				else
					bypassRoot.CFrame = CFrame.new()
					bypassRoot.AssemblyLinearVelocity = Vector3.zero
				end
			end))
		else
			bypassRoot = nil
		end
	end,
	Tooltip = 'a disabler xd disables most checks'
})

end)

run(function()
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

end)

run(function()
local AntiHit
local RangeSlider
local SpeedSlider
local BounceSlider
local DepthSlider

local function getIgnore()
	local ignore = {gameCamera, entitylib.character.Character}
	for _, ent in entitylib.List do
		if ent.Character then
			table.insert(ignore, ent.Character)
		end
	end
	return ignore
end

local function getDiveY(root, params)
	-- top surface of the map
	local top = workspace:Raycast(root.Position + Vector3.new(0, 50, 0), Vector3.new(0, -400, 0), params)
	local topY = top and top.Position.Y or root.Position.Y

	-- walk down looking for a pocket that fully fits the character
	local probe = topY - 3
	while probe > topY - 60 do
		local up = workspace:Raycast(Vector3.new(root.Position.X, probe + 2, root.Position.Z), Vector3.new(0, 8, 0), params)
		local down = workspace:Raycast(Vector3.new(root.Position.X, probe - 2, root.Position.Z), Vector3.new(0, -8, 0), params)

		local ceilingY = up and up.Position.Y or probe + 10
		local floorY = down and down.Position.Y or probe - 10

		if ceilingY > probe + 3.5 and floorY < probe - 2.5 then
			return probe, ceilingY, floorY
		end
		probe -= 2
	end

	return topY - DepthSlider.Value, math.huge, -math.huge
end

local function hasMelee(char)
	for _, child in char:GetChildren() do
		if child:IsA('Tool') and child:GetAttribute('WeaponType') then
			return true
		end
	end
	return false
end

local function threatNear(me)
	for _, ent in entitylib.List do
		if not ent.Targetable or not ent.RootPart or not ent.Character then
			continue
		end
		if (ent.RootPart.Position - me).Magnitude > RangeSlider.Value then
			continue
		end
		if hasMelee(ent.Character) then
			return true
		end
	end
	return false
end

AntiHit = vape.Categories.Blatant:CreateModule({
	Name = 'Anti Hit',
	Function = function(callback)
		if callback then
			local under = false
			local original, anchor, ceiling, floor, goingUp
			local lastBounce = 0

			AntiHit:Clean(function()
				if under then
					pcall(function()
						local root = entitylib.isAlive and entitylib.character.RootPart
						if root then
							root.CFrame = original
							root.AssemblyLinearVelocity = Vector3.zero
						end
					end)
				end
				under = false
			end)

			AntiHit:Clean(runService.Heartbeat:Connect(function()
				if not entitylib.isAlive then
					under = false
					return
				end

				local root = entitylib.character.RootPart
				local threatened = threatNear(root.Position)

				if threatened and not under then
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = getIgnore()
					local diveY, cY, fY = getDiveY(root, params)
					original = root.CFrame
					anchor, ceiling, floor = diveY, cY, fY
					goingUp, lastBounce = true, 0
					root.CFrame = CFrame.new(original.Position.X, anchor, original.Position.Z) * original.Rotation
					root.AssemblyLinearVelocity = Vector3.zero
					under = true
				end

				if under then
					if MethodSlider.Value == 'Up/Down' then
						local interval = 1 / math.max(SpeedSlider.Value, 0.1)
						if os.clock() - lastBounce >= interval then
							lastBounce = os.clock()
							local bounce = math.min(BounceSlider.Value, ceiling - anchor - 3.5, anchor - floor - 2.5)
							bounce = math.max(bounce, 0.5)
							local ny = goingUp and (anchor + bounce) or (anchor - bounce)
							root.CFrame = CFrame.new(original.Position.X, ny, original.Position.Z) * original.Rotation
							root.AssemblyLinearVelocity = Vector3.zero
							goingUp = not goingUp
						end
					end

					if not threatened then
						root.CFrame = original
						root.AssemblyLinearVelocity = Vector3.zero
						under = false
					end
				end
			end))
		end
	end,
	Tooltip = 'When enemies with melee weapons are near, sinks into an air pocket under the map and either stays under or teleports up and down (see Method) so server-side hitchecks miss. Disabling snaps you back up.'
})

MethodSlider = AntiHit:CreateDropdown({
	Name = 'Method',
	List = {'Up/Down', 'Under Map'},
	Default = 'Up/Down'
})
RangeSlider = AntiHit:CreateSlider({
	Name = 'Range',
	Min = 6,
	Max = 24,
	Default = 13,
	Suffix = 'studs'
})
SpeedSlider = AntiHit:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 10,
	Default = 5,
	Suffix = 'tps/s'
})
BounceSlider = AntiHit:CreateSlider({
	Name = 'Bounce',
	Min = 1,
	Max = 8,
	Default = 4,
	Suffix = 'studs'
})
DepthSlider = AntiHit:CreateSlider({
	Name = 'Depth',
	Min = 5,
	Max = 30,
	Default = 12,
	Suffix = 'studs'
})

end)

run(function()
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

end)

run(function()
local Fly
local Value
local Keys
local Platform = Instance.new('Part')
Platform.CanQuery = false
Platform.Anchored = true
Platform.Size = Vector3.new(4, 1, 4)
Platform.Transparency = 1
Platform.Parent = nil

Fly = vape.Categories.Blatant:CreateModule({
	Name = 'Fly',
	Function = function(callback)
		if Platform then
			Platform.Parent = callback and gameCamera or nil
		end

		if callback then
			if not ACDisabler.Enabled then
				ACDisabler:Toggle()
			end

			Fly:Clean(runService.PreSimulation:Connect(function(dt)
				if entitylib.isAlive then
					applySpeed(Value.Value, dt)
					Platform.CFrame = down ~= 0 and CFrame.identity or entitylib.character.RootPart.CFrame + Vector3.new(0, -(entitylib.character.HipHeight + 0.5), 0)
				end
			end))

			up, down = 0, 0
			for _, v in {'InputBegan', 'InputEnded'} do
				Fly:Clean(inputService[v]:Connect(function(input)
					if not inputService:GetFocusedTextBox() then
						local divided = Keys.Value:split('/')
						if input.KeyCode == Enum.KeyCode[divided[1]] then
							up = v == 'InputBegan' and 1 or 0
						elseif input.KeyCode == Enum.KeyCode[divided[2]] then
							down = v == 'InputBegan' and -1 or 0
						end
					end
				end))
			end

			if inputService.TouchEnabled then
				pcall(function()
					local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
					Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
						up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
					end))
				end)
			end
		end
	end,
	ExtraText = function()
		return 'BlockWars'
	end,
	Tooltip = 'Makes you go zoom.'
})
Keys = Fly:CreateDropdown({
	Name = 'Keys',
	List = {'Space/LeftControl', 'Space/LeftShift', 'E/Q', 'Space/Q', 'ButtonA/ButtonL2'},
	Tooltip = 'The key combination for going up & down'
})
Value = Fly:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 38,
	Default = 38,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})

end)

run(function()
local InfAura
local targetinfo = vape.Libraries.targetinfo
local Targets
local Max
local Rate
local Mode
local delayTable = {}
local isAttacking = false

local function getSword()
	local inv = getInventory()
	for _, tool in inv do
		if tool:GetAttribute('WeaponType') then
			return tool
		end
	end
end

local function attackTarget(tool, target, startCF)
	local swing = replicatedStorage.GameEvents.CombatRemotes.Combat_FeintSwing
	local attack = replicatedStorage.GameEvents.CombatRemotes.Combat_RequestAttack
	if swing and attack and swing:IsA('RemoteEvent') and attack:IsA('RemoteEvent') then
		swing:FireServer()
		attack:FireServer(tool:GetAttribute('WeaponType'), target.Character)
	end
end

InfAura = vape.Categories.Blatant:CreateModule({
	Name = 'InfAura',
	Function = function(callback)
		if callback then
			repeat
				isAttacking = false
				local tool = getSword()

				if tool then
					if tool.Parent ~= lplr.Character then
						entitylib.character.Humanoid:EquipTool(tool)
					end

					local plrs = entitylib.AllPosition({
						Range = 9e9,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Limit = Max.Value
					})

					if #plrs > 0 then
						isAttacking = true
						local root = entitylib.character.RootPart
						local startCF = root.CFrame

						for _, v in plrs do
							targetinfo.Targets[v] = tick() + 1
							if (os.clock() - (delayTable[v.Character] or 0)) < Rate.Value then
								continue
							end

							if Mode.Value == 'Teleport' then
								root.CFrame = CFrame.lookAt(v.RootPart.Position + Vector3.new(0, 1, 0), v.RootPart.Position)
								task.wait(0.05)
								attackTarget(tool, v, startCF)
								task.wait(0.05)
								root.CFrame = startCF
							else
								attackTarget(tool, v, startCF)
							end

							delayTable[v.Character] = os.clock()
						end
					end
				end

				task.wait(0.016)
			until not InfAura.Enabled
		else
			isAttacking = false
			table.clear(delayTable)
		end
	end,
	Tooltip = 'Attacks every target on the map, no range limit.\nRemote: fires attacks from anywhere.\nTeleport: blinks to each target so hits register server-side.'
})
Targets = InfAura:CreateTargets({
	Players = true,
	NPCs = true
})
Max = InfAura:CreateSlider({
	Name = 'Max targets',
	Min = 1,
	Max = 20,
	Default = 10
})
Rate = InfAura:CreateSlider({
	Name = 'Attack delay',
	Min = 0,
	Max = 1,
	Decimal = 1000,
	Default = 0.1,
	Suffix = 's'
})
Mode = InfAura:CreateDropdown({
	Name = 'Mode',
	List = {
		'Remote',
		'Teleport'
	}
})

end)

run(function()
local InfiniteJump
local VelocitySlider
local up = false

InfiniteJump = vape.Categories.Blatant:CreateModule({
	Name = 'InfiniteJump',
	Function = function(callback)
		if callback then
			if not ACDisabler.Enabled then
				ACDisabler:Toggle()
			end

			InfiniteJump:Clean(runService.PreSimulation:Connect(function()
				if entitylib.isAlive and up then
					local root = entitylib.character.RootPart
					root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, VelocitySlider.Value, root.AssemblyLinearVelocity.Z)
				end
			end))

			InfiniteJump:Clean(inputService.InputBegan:Connect(function(input)
				if not inputService:GetFocusedTextBox() then
					if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
						up = true
					end
				end
			end))

			InfiniteJump:Clean(inputService.InputEnded:Connect(function(input)
				if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
					up = false
				end
			end))

			if inputService.TouchEnabled then
				pcall(function()
					local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
					InfiniteJump:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
						up = jumpButton.ImageRectOffset.X == 146
					end))
				end)
			end
		else
			up = false
		end
	end,
	Tooltip = 'Jump infinitely with vertical velocity while holding Space. Automatically enables the anticheat bypass.'
})

VelocitySlider = InfiniteJump:CreateSlider({
	Name = 'Velocity',
	Min = 10,
	Max = 150,
	Default = 50,
	Suffix = ' velocity'
})

end)

run(function()
local Killaura
local Targets
local SwingRange
local AttackRange
local AngleSlider
local Max
local Mouse
local BoxSwingColor
local BoxAttackColor
local ParticleTexture
local ParticleColor1
local ParticleColor2
local ParticleSize
local Face
local InstaKill
local Particles, Boxes, AttackDelay = {}, {}, {}

local function getSword()
	local inv = getInventory()
	for _, tool in inv do
		if tool:GetAttribute('WeaponType') then
			return tool
		end
	end
end

local function getAttackData()
	if Mouse.Enabled then
		if not inputService:IsMouseButtonPressed(0) then return false end
	end

	local tool = getSword()
	return tool or nil, tool
end

Killaura = vape.Categories.Blatant:CreateModule({
	Name = 'Killaura',
	Function = function(callback)
		if callback then
			repeat
				isAttacking = false
				local tool = getAttackData()
				local attacked = {}

				if tool then
					local plrs = entitylib.AllPosition({
						Range = AttackRange.Value,
						Wallcheck = Targets.Walls.Enabled or nil,
						Origin = bypassRoot and bypassRoot.Position or nil,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Limit = Max.Value
					})

					if #plrs > 0 then
						isAttacking = true
						local selfpos = entitylib.character.RootPart.Position
						local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

						if tool.Parent ~= lplr.Character then
							entitylib.character.Humanoid:EquipTool(tool)
						end

						for _, v in plrs do
							local delta = (v.RootPart.Position - selfpos)
							local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
							if angle > (math.rad(AngleSlider.Value) / 2) then continue end

							table.insert(attacked, {
								Entity = v,
								Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
							})
							targetinfo.Targets[v] = tick() + 1

							if (os.clock() - (BlockTimes[v.Character] or 0)) < 0.3 then
								continue
							end

							if (os.clock() - (AttackDelay[v.Character] or 0) < 0.03) then
								continue
							end

							local hitCount = InstaKill and InstaKill.Enabled and 100 or 1
							for _ = 1, hitCount do
								replicatedStorage.GameEvents.CombatRemotes.Combat_FeintSwing:FireServer()
								replicatedStorage.GameEvents.CombatRemotes.Combat_RequestAttack:FireServer(tool:GetAttribute('WeaponType'), v.Character)
							end
							AttackDelay[v.Character] = os.clock()
						end
					end
				end

				for i, v in Boxes do
					v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
					if v.Adornee then
						v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
						v.Transparency = 1 - attacked[i].Check.Opacity
					end
				end

				for i, v in Particles do
					v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
					v.Parent = attacked[i] and gameCamera or nil
				end

				if Face.Enabled and attacked[1] then
					local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
					entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.01, vec.Z))
				end

				task.wait(0.016)
			until not Killaura.Enabled
		else
			isAttacking = false

			for _, v in Boxes do
				v.Adornee = nil
			end

			for _, v in Particles do
				v.Parent = nil
			end
		end
	end,
	Tooltip = 'Attack players around you\nwithout aiming at them.'
})
Targets = Killaura:CreateTargets({
	Players = true,
	NPCs = true
})
AttackRange = Killaura:CreateSlider({
	Name = 'Attack range',
	Min = 1,
	Max = 13,
	Default = 13,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
AngleSlider = Killaura:CreateSlider({
	Name = 'Max angle',
	Min = 1,
	Max = 360,
	Default = 90
})
Max = Killaura:CreateSlider({
	Name = 'Max targets',
	Min = 1,
	Max = 10,
	Default = 10
})
Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
InstaKill = Killaura:CreateToggle({Name = '4BigGuys', Tooltip = 'Fire 100 hits per swing for instant kills.'})
Killaura:CreateToggle({
	Name = 'Show target',
	Function = function(callback)
		BoxSwingColor.Object.Visible = callback
		BoxAttackColor.Object.Visible = callback
		if callback then
			for i = 1, 10 do
				local box = Instance.new('BoxHandleAdornment')
				box.Adornee = nil
				box.AlwaysOnTop = true
				box.Size = Vector3.new(3, 5, 3)
				box.CFrame = CFrame.new(0, -0.5, 0)
				box.ZIndex = 0
				box.Parent = vape.gui
				Boxes[i] = box
			end
		else
			for _, v in Boxes do
				v:Destroy()
			end
			table.clear(Boxes)
		end
	end
})
BoxSwingColor = Killaura:CreateColorSlider({
	Name = 'Target Color',
	Darker = true,
	DefaultHue = 0.6,
	DefaultOpacity = 0.5,
	Visible = false
})
BoxAttackColor = Killaura:CreateColorSlider({
	Name = 'Attack Color',
	Darker = true,
	DefaultOpacity = 0.5,
	Visible = false
})
Killaura:CreateToggle({
	Name = 'Target particles',
	Function = function(callback)
		ParticleTexture.Object.Visible = callback
		ParticleColor1.Object.Visible = callback
		ParticleColor2.Object.Visible = callback
		ParticleSize.Object.Visible = callback
		if callback then
			for i = 1, 10 do
				local part = Instance.new('Part')
				part.Size = Vector3.new(2, 4, 2)
				part.Anchored = true
				part.CanCollide = false
				part.Transparency = 1
				part.CanQuery = false
				part.Parent = Killaura.Enabled and gameCamera or nil
				local particles = Instance.new('ParticleEmitter')
				particles.Brightness = 1.5
				particles.Size = NumberSequence.new(ParticleSize.Value)
				particles.Shape = Enum.ParticleEmitterShape.Sphere
				particles.Texture = ParticleTexture.Value
				particles.Transparency = NumberSequence.new(0)
				particles.Lifetime = NumberRange.new(0.4)
				particles.Speed = NumberRange.new(16)
				particles.Rate = 128
				particles.Drag = 16
				particles.ShapePartial = 1
				particles.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
				particles.Parent = part
				Particles[i] = part
			end
		else
			for _, v in Particles do
				v:Destroy()
			end
			table.clear(Particles)
		end
	end
})
ParticleTexture = Killaura:CreateTextBox({
	Name = 'Texture',
	Default = 'rbxassetid://14736249347',
	Function = function()
		for _, v in Particles do
			v.ParticleEmitter.Texture = ParticleTexture.Value
		end
	end,
	Darker = true,
	Visible = false
})
ParticleColor1 = Killaura:CreateColorSlider({
	Name = 'Color Begin',
	Function = function(hue, sat, val)
		for _, v in Particles do
			v.ParticleEmitter.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
			})
		end
	end,
	Darker = true,
	Visible = false
})
ParticleColor2 = Killaura:CreateColorSlider({
	Name = 'Color End',
	Function = function(hue, sat, val)
		for _, v in Particles do
			v.ParticleEmitter.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
			})
		end
	end,
	Darker = true,
	Visible = false
})
ParticleSize = Killaura:CreateSlider({
	Name = 'Size',
	Min = 0,
	Max = 1,
	Default = 0.2,
	Decimal = 100,
	Function = function(val)
		for _, v in Particles do
			v.ParticleEmitter.Size = NumberSequence.new(val)
		end
	end,
	Darker = true,
	Visible = false
})
Face = Killaura:CreateToggle({Name = 'Face target'})

end)

run(function()
local Speed
local Value
local AutoJump
local AutoJumpCustom
local AutoJumpValue

Speed = vape.Categories.Blatant:CreateModule({
	Name = 'Speed',
	Function = function(callback)
		if callback then
			if not ACDisabler.Enabled then
				ACDisabler:Toggle()
			end

			Speed:Clean(runService.PreSimulation:Connect(function(dt)
				if entitylib.isAlive and not Fly.Enabled then
					local state = entitylib.character.Humanoid:GetState()
					if state == Enum.HumanoidStateType.Climbing then return end
					applySpeed(Value.Value, dt)

					if AutoJump.Enabled and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and movevec ~= Vector3.zero then
						if AutoJumpCustom.Enabled then
							local velocity = entitylib.character.RootPart.Velocity * Vector3.new(1, 0, 1)
							entitylib.character.RootPart.Velocity = Vector3.new(velocity.X, AutoJumpValue.Value, velocity.Z)
						else
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
				end
			end))
		end
	end,
	ExtraText = function()
		return 'BlockWars'
	end,
	Tooltip = 'Increases your movement with various methods.'
})
Value = Speed:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 38,
	Default = 38,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
AutoJump = Speed:CreateToggle({
	Name = 'AutoJump',
	Function = function(callback)
		AutoJumpCustom.Object.Visible = callback
	end
})
AutoJumpCustom = Speed:CreateToggle({
	Name = 'Custom Jump',
	Function = function(callback)
		AutoJumpValue.Object.Visible = callback
	end,
	Tooltip = 'Allows you to adjust the jump power',
	Darker = true,
	Visible = false
})
AutoJumpValue = Speed:CreateSlider({
	Name = 'Jump Power',
	Min = 1,
	Max = 50,
	Default = 30,
	Darker = true,
	Visible = false
})

end)

run(function()
local TPAura
local Targets
local Range
local HitDelay
local CycleDelay
local YOffset
local TpBack

local function getSword()
	local inv = getInventory()
	for _, tool in inv do
		if tool:GetAttribute('WeaponType') then
			return tool
		end
	end
end

TPAura = vape.Categories.Blatant:CreateModule({
	Name = 'TPAura',
	Function = function(callback)
		if callback then
			repeat
				local tool = getSword()
				if tool then
					local plrs = entitylib.AllPosition({
						Range = Range.Value,
						Wallcheck = false,
						Origin = bypassRoot and bypassRoot.Position or nil,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Limit = 1
					})

					if #plrs > 0 then
						local target = plrs[1]
						local root = entitylib.character.RootPart
						local startCF = root.CFrame
						local targetPos = target.RootPart.Position

						root.CFrame = CFrame.lookAt(targetPos + Vector3.new(0, YOffset.Value, 0), targetPos)
						targetinfo.Targets[target] = tick() + 1

						if tool.Parent ~= lplr.Character then
							entitylib.character.Humanoid:EquipTool(tool)
						end

						task.wait(HitDelay.Value)

						local swing = replicatedStorage.GameEvents.CombatRemotes.Combat_FeintSwing
						local attack = replicatedStorage.GameEvents.CombatRemotes.Combat_RequestAttack
						if swing and attack and swing:IsA('RemoteEvent') and attack:IsA('RemoteEvent') then
							swing:FireServer()
							attack:FireServer(tool:GetAttribute('WeaponType'), target.Character)
						end

						if TpBack.Enabled then
							task.wait(HitDelay.Value)
							root.CFrame = startCF
						end
					end
				end

				task.wait(CycleDelay.Value)
			until not TPAura.Enabled
		end
	end,
	Tooltip = 'Teleports to your target, hits them, then teleports back.'
})
Targets = TPAura:CreateTargets({
	Players = true,
	NPCs = true
})
Range = TPAura:CreateSlider({
	Name = 'Target range',
	Min = 10,
	Max = 100,
	Default = 30,
	Suffix = 'studs'
})
HitDelay = TPAura:CreateSlider({
	Name = 'Hit delay',
	Min = 0,
	Max = 0.5,
	Decimal = 1000,
	Default = 0.05,
	Suffix = 's'
})
CycleDelay = TPAura:CreateSlider({
	Name = 'Cycle delay',
	Min = 0,
	Max = 1,
	Decimal = 1000,
	Default = 0.15,
	Suffix = 's'
})
YOffset = TPAura:CreateSlider({
	Name = 'Height offset',
	Min = 0,
	Max = 5,
	Decimal = 10,
	Default = 1,
	Suffix = 'studs'
})
TpBack = TPAura:CreateToggle({
	Name = 'Teleport back',
	Default = true,
	Tooltip = 'Returns to your original position after each hit.'
})

end)

run(function()
local FixGUIs

FixGUIs = vape.Legit:CreateModule({
	Name = 'FixGUIs',
	Function = function(callback)
		if callback then
			local guis = {lplr.PlayerGui:FindFirstChild('Team_UpgradesV3', true), lplr.PlayerGui:FindFirstChild('ItemShopV3', true)}
			if #guis < 2 then
				repeat
					guis = {lplr.PlayerGui:FindFirstChild('Team_UpgradesV3', true), lplr.PlayerGui:FindFirstChild('ItemShopV3', true)}
					task.wait()
				until #guis >= 2 or not FixGUIs.Enabled

				if not FixGUIs.Enabled then
					return
				end
			end

			local vis = false
			local mouse = Instance.new('ImageLabel')
			mouse.Size = UDim2.fromOffset(20, 20)
			mouse.Visible = false
			mouse.Parent = vape.gui
			FixGUIs:Clean(mouse)

			for _, gui in guis do
				if gui then
					for _, v in gui:QueryDescendants('TextButton') do
						local ancestor = v:FindFirstAncestorWhichIsA('ScrollingFrame')
						if not ancestor then
							v.Modal = true
						end
					end

					vis = vis or gui.Visible
					FixGUIs:Clean(gui:GetPropertyChangedSignal('Visible'):Connect(function()
						vis = gui.Visible
					end))
				end
			end

			FixGUIs:Clean(runService.Heartbeat:Connect(function()
				local location = inputService:GetMouseLocation()
				mouse.Visible = vis
				if mouse.Visible then
					mouse.Position = UDim2.fromOffset(location.X, location.Y)
				end
			end))
		end
	end,
	Tooltip = 'Fix GUI\'s in first person.'
})
end)

run(function()
local HideShield
local parts = {}

local function localAdded(char)
	local shield = char.Character:WaitForChild('ShieldModel', 10)
	if shield then
		parts = shield:QueryDescendants('BasePart')
	end
end

HideShield = vape.Legit:CreateModule({
	Name = 'HideShield',
	Function = function(callback)
		if callback then
			HideShield:Clean(entitylib.Events.LocalAdded:Connect(localAdded))
			if entitylib.isAlive then
				task.spawn(localAdded, entitylib.character)
			end

			repeat
				for _, v in parts do
					v.Transparency = 1
				end

				task.wait()
			until not HideShield.Enabled
		else
			table.clear(parts)
		end
	end,
	Tooltip = 'Hide the shield entirely.'
})
end)

run(function()
local AutoLeave

AutoLeave = vape.Categories.Utility:CreateModule({
	Name = 'AutoLeave',
	Function = function(callback)
		if callback then
			AutoLeave:Clean(bw.RemoteIndex.Victory_Show.OnClientEvent:Connect(function()
				replicatedStorage.GameEvents.BedWarsRemotes.Return_To_Lobby:FireServer()
			end))
		end
	end,
	Tooltip = 'Automatically leave after the match ends.'
})
end)

run(function()
local AutoPotions
local toggles = {}
local nextDrink = {}
local AutoBuyToggle
local potions = {
	potion_invis = {tool = 'InvisiblePotion', fallback = 15},
	potion_speed = {tool = 'SpeedPotion', fallback = 15},
	potion_jump = {tool = 'JumpPotion', fallback = 15}
}

for id, info in potions do
	local item = bw.ShopConfig.Items[id]
	info.duration = (item and item.stats and item.stats.duration) or info.fallback
end

local function findTool(id)
	local name = potions[id].tool
	for _, tool in getInventory() do
		if tool.Name == name or tool:GetAttribute('_BaseName') == name then
			return tool
		end
	end
	return nil
end

local function drink(id)
	local tool = findTool(id)
	if not tool then
		local item = bw.ShopConfig.Items[id]
		local cost = item and item.cost and item.cost.Block or 0
		if AutoBuyToggle.Enabled and cost > 0 and (bw.Inventory.blocks or 0) >= cost then
			bw.RemoteIndex.Shop_Purchase:InvokeServer({itemId = id})
			tool = findTool(id)
		end
		if not tool then
			return
		end
	end

	if tool.Parent ~= entitylib.character then
		entitylib.character.Humanoid:EquipTool(tool)
	end
	tool:Activate()
	nextDrink[id] = workspace:GetServerTimeNow() + potions[id].duration + 1
end

AutoPotions = vape.Categories.Utility:CreateModule({
	Name = 'AutoPotions',
	Function = function(callback)
		if callback then
			task.spawn(function()
				repeat
					if entitylib.isAlive then
						local now = workspace:GetServerTimeNow()
						for id, toggle in toggles do
							if toggle.Enabled and (nextDrink[id] or 0) < now then
								drink(id)
							end
						end
					end
					task.wait(0.5)
				until not AutoPotions.Enabled
				table.clear(nextDrink)
			end)
		end
	end,
	Tooltip = 'Buys and drinks potions as soon as their effect wears off: permanent invisibility, speed and jump.'
})
toggles.potion_invis = AutoPotions:CreateToggle({Name = 'Invis', Default = true})
toggles.potion_speed = AutoPotions:CreateToggle({Name = 'Speed'})
toggles.potion_jump = AutoPotions:CreateToggle({Name = 'Jump'})
AutoBuyToggle = AutoPotions:CreateToggle({Name = 'Auto buy', Default = true})

end)

run(function()
local AutoQueue

AutoQueue = vape.Categories.Utility:CreateModule({
	Name = 'AutoQueue',
	Function = function(callback)
		if callback then
			if workspace:GetAttribute('ServerType') == 'Lobby' then
				task.spawn(function()
					bw.RemoteIndex.Matchmaking_Request:InvokeServer('queue')
				end)
			end
		end
	end,
	Tooltip = 'Automatically queue in the lobby.'
})
end)

run(function()
local AutoToxic
local GG
local Toggles, Lists, Cloned, Presets = {}, {}, {}, {}

local function sendMessage(name, obj, default)
	local message = default
	if #Lists[name].ListEnabled > 0 then
		if #Cloned[name] <= 0 then
			Cloned[name] = table.clone(Lists[name].ListEnabled)
		end

		local entry = Random.new():NextInteger(1, #Cloned[name])
		message = Cloned[name][entry]
		table.remove(Cloned[name], entry)
	end

	if not message then return end

	message = message and message:gsub('<obj>', obj or '') or ''
	if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		if textChatService:CanUserChatAsync(lplr.UserId) then
			textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(message)
		else
			textChatService.ChatInputBarConfiguration.TargetTextChannel:SendPresetAsync(Presets[message] or Presets['So close'])
		end
	else
		replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, 'All')
	end
end

AutoToxic = vape.Categories.Utility:CreateModule({
	Name = 'AutoToxic',
	Function = function(callback)
		if callback then
			AutoToxic:Clean(bw.RemoteIndex.Round_Event.OnClientEvent:Connect(function(data)
				if type(data) == 'table' and data.id == 'final_kill' then
					if GG.Enabled then
						if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
							if textChatService:CanUserChatAsync(lplr.UserId) then
								textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('gg')
							else
								textChatService.ChatInputBarConfiguration.TargetTextChannel:SendPresetAsync(Presets['Good game'])
							end
						else
							replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('gg', 'All')
						end
					end

					if lplr.Team and lplr.Team.Name == data.teamId then
						if Toggles.Win.Enabled then
							sendMessage('Win', nil, 'yall garbage')
						end
					end
				end
			end))
		end
	end,
	Tooltip = 'Says a message after a certain action'
})
GG = AutoToxic:CreateToggle({
	Name = 'AutoGG',
	Default = true
})
for _, v in {'Win'} do
	Cloned[v] = {}
	Toggles[v] = AutoToxic:CreateToggle({
		Name = v..' ',
		Function = function(callback)
			if Lists[v] then
				Lists[v].Object.Visible = callback
			end
		end
	})
	Lists[v] = AutoToxic:CreateTextList({
		Name = v,
		Darker = true,
		Visible = false,
		Function = function()
			table.clear(Cloned[v])
		end
	})
end

pcall(function()
	for _, group in textChatService:GetPresetsAsync().categoryGroups do
		for _, category in group.categories do
			for _, message in category.messages do
				Presets[message.value] = message.presetId
			end
		end
	end
end)
end)

run(function()
local Detector
local SpeedSlider
local flagged = {}
local highlights = {}

local function flagPlayer(plr)
	if flagged[plr] then return end
	flagged[plr] = true
	vape:CreateNotification('Cheat Detector', plr.Name..' is cheating (speed)', 5, 'alert')
end

local function clearPlayer(plr)
	flagged[plr] = nil
	local hl = highlights[plr]
	if hl then
		hl:Destroy()
		highlights[plr] = nil
	end
end

local function clearAll()
	local keys = {}
	for plr in highlights do
		table.insert(keys, plr)
	end
	for _, plr in keys do
		clearPlayer(plr)
	end
	table.clear(flagged)
end

local function refreshHighlight(plr, hue)
	local char = plr.Character
	if not char then
		clearPlayer(plr)
		return
	end
	local hl = highlights[plr]
	if not hl or hl.Parent ~= char then
		if hl then
			hl:Destroy()
		end
		hl = Instance.new('Highlight')
		hl.FillTransparency = 0.35
		hl.OutlineTransparency = 0
		hl.Parent = char
		highlights[plr] = hl
	end
	hl.FillColor = Color3.fromHSV(hue % 1, 1, 1)
end

Detector = vape.Categories.Utility:CreateModule({
	Name = 'Cheat Detector',
	Function = function(callback)
		if callback then
			local samples = {}

			Detector:Clean(runService.Heartbeat:Connect(function()
				local hue = tick() % 1
				for plr in flagged do
					refreshHighlight(plr, hue + plr.UserId % 10 / 10)
				end
			end))

			Detector:Clean(playersService.PlayerRemoving:Connect(clearPlayer))

			Detector:Clean(bw.RemoteIndex.Victory_Show.OnClientEvent:Connect(clearAll))

			task.spawn(function()
				repeat
					task.wait(0.4)
					if not Detector.Enabled then break end
					local now = tick()
					for _, ent in entitylib.List do
						local plr = ent.Player
						if not plr or plr == lplr or not ent.RootPart or flagged[plr] then
							continue
						end
						local pos = ent.RootPart.Position * Vector3.new(1, 0, 1)
						local sample = samples[plr]
						if sample then
							local speed = (pos - sample.pos).Magnitude / (now - sample.time)
							if speed > SpeedSlider.Value then
								local streak = sample.streak + 1
								if streak >= 3 then
									flagPlayer(plr)
								else
									samples[plr] = {pos = pos, time = now, streak = streak}
								end
							else
								samples[plr] = {pos = pos, time = now, streak = 0}
							end
						else
							samples[plr] = {pos = pos, time = now, streak = 0}
						end
					end
				until not Detector.Enabled
				table.clear(samples)
			end)
		else
			clearAll()
		end
	end,
	Tooltip = 'Detects players moving faster than physically possible (sustained speed above the threshold) and highlights them in rainbow for the rest of the match.'
})
SpeedSlider = Detector:CreateSlider({
	Name = 'Speed threshold',
	Min = 25,
	Max = 100,
	Default = 40,
	Suffix = ' studs/s'
})

end)

run(function()
local StreamSniper
local WhitelistList
local NotifyJoin
local AutoQueueToggle
local track
local tracked = {}
local notified = {}
local resolvedIds = {}
local resolvedEntries = {}
local resolvedNames = {}
local failedAt = {}
local httpService = cloneref(game:GetService('HttpService'))
local headers = {
	['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

local function persistCache()
	pcall(function()
		writefile('weedhack/streamsniper_cache.txt', httpService:JSONEncode(resolvedEntries))
	end)
end

local function loadCache()
	pcall(function()
		if isfile and isfile('weedhack/streamsniper_cache.txt') then
			local data = httpService:JSONDecode(readfile('weedhack/streamsniper_cache.txt'))
			if type(data) == 'table' then
				for k, v in data do
					resolvedEntries[k] = v
					if type(v) == 'number' then
						resolvedIds[v] = true
					end
				end
			end
		end
	end)
end

local function fetchUser(id)
	local ok, res = pcall(function()
		return game:HttpGet('https://users.roblox.com/v1/users/'..id, true, headers)
	end)
	if ok and res then
		local ok2, data = pcall(function()
			return httpService:JSONDecode(res)
		end)
		if ok2 and type(data) == 'table' and data.id then
			resolvedIds[data.id] = true
			if data.name then
				resolvedNames[data.id] = data.name
			end
			return data
		end
	end
	return nil
end

local function isWhitelisted(plr)
	local name = plr.Name:lower()
	local display = plr.DisplayName:lower()
	for _, v in WhitelistList.ListEnabled do
		local entry = tostring(v)
		local low = entry:lower()
		if low == name or low == display then
			return true
		end
		local id = tonumber(entry)
		if id and id == plr.UserId then
			return true
		end
	end
	return resolvedIds[plr.UserId] == true
end

local function resolveEntries(notify)
	local pending = {}
	for _, v in WhitelistList.ListEnabled do
		local entry = tostring(v)
		if resolvedEntries[entry] ~= nil then continue end
		local id = tonumber(entry)
		if id then
			resolvedEntries[entry] = id
			if not fetchUser(id) then
				resolvedIds[id] = true
			end
		else
			if (failedAt[entry] or 0) + 60 < os.clock() then
				table.insert(pending, entry)
			end
		end
	end

	if #pending == 0 then
		if notify then
			vape:CreateNotification('Stream Sniper', 'Whitelist active', 3)
		end
		return
	end

	task.spawn(function()
		local resolved = 0
		for _, entry in pending do
			if resolvedEntries[entry] ~= nil then continue end
			local ok, res = pcall(function()
				return game:HttpGet('https://users.roblox.com/v1/users/search?keyword='..httpService:UrlEncode(entry)..'&limit=10', true, headers)
			end)
			local low = entry:lower()
			if ok and res then
				local ok2, data = pcall(function()
					return httpService:JSONDecode(res)
				end)
				if ok2 and type(data) == 'table' and data.data then
					for _, user in data.data do
						local uname = (user.name or ''):lower()
						local dname = (user.displayName or ''):lower()
						if uname == low or dname == low then
							resolvedEntries[entry] = user.id
							resolvedIds[user.id] = true
							resolvedNames[user.id] = user.name
							resolved += 1
							break
						end
					end
				end
			end
			if resolvedEntries[entry] == nil then
				failedAt[entry] = os.clock()
			end
			task.wait(1.5)
		end
		persistCache()
		for _, plr in playersService:GetPlayers() do
			if plr ~= lplr then
				track(plr, true)
			end
		end
		if notify and resolved > 0 then
			vape:CreateNotification('Stream Sniper', 'Whitelist resolved '..resolved..' users', 4)
		end
	end)
end

local function canQueue()
	if lplr:GetAttribute('Searching') then
		return false
	end
	if workspace:GetAttribute('ServerType') == 'Lobby' then
		return true
	end
	local ok, state = pcall(function()
		return bw.RemoteIndex.Matchmaking_Request:InvokeServer('status')
	end)
	if not ok or type(state) ~= 'table' then
		return false
	end
	local st = state.state
	if st == 'searching' or st == 'matched' or st == 'partyAlive' or st == 'partyMember' then
		return false
	end
	return true
end

local function queueFor(plr)
	if not canQueue() then return end
	local ok, state = pcall(function()
		return bw.RemoteIndex.Matchmaking_Request:InvokeServer('queue')
	end)
	if not ok then return end
	if type(state) == 'table' and state.state == 'searching' then
		vape:CreateNotification('Stream Sniper', 'Auto-queued to match '..plr.Name, 5)
	end
end

track = function(plr, force)
	if plr == lplr then return end
	if not isWhitelisted(plr) then
		if not tracked[plr] then
			resolveEntries(false)
		end
		return
	end
	if tracked[plr] and not force then return end
	if not notified[plr] then
		notified[plr] = true
		if NotifyJoin.Enabled then
			vape:CreateNotification('Stream Sniper', plr.Name..' joined the server', 5)
		end
	end
	if not tracked[plr] then
		tracked[plr] = plr:GetAttributeChangedSignal('Searching'):Connect(function()
			if plr:GetAttribute('Searching') then
				if NotifyJoin.Enabled then
					vape:CreateNotification('Stream Sniper', plr.Name..' is searching', 5)
				end
				if AutoQueueToggle.Enabled and isWhitelisted(plr) then
					queueFor(plr)
				end
			end
		end)
		StreamSniper:Clean(tracked[plr])
	end
	if AutoQueueToggle.Enabled and plr:GetAttribute('Searching') then
		queueFor(plr)
	end
end

StreamSniper = vape.Categories.Utility:CreateModule({
	Name = 'Stream Sniper',
	Function = function(callback)
		if callback then
			loadCache()
			resolveEntries(true)
			StreamSniper:Clean(playersService.PlayerAdded:Connect(track))
			StreamSniper:Clean(playersService.PlayerRemoving:Connect(function(plr)
				if tracked[plr] then
					tracked[plr]:Disconnect()
					tracked[plr] = nil
				end
			end))
			for _, plr in playersService:GetPlayers() do
				if plr ~= lplr then
					track(plr)
				end
			end
		else
			table.clear(tracked)
			table.clear(notified)
		end
	end,
	Tooltip = 'Fetches whitelisted users from the Roblox Users API (usernames, display names or user IDs all work). Notifies when they join or start searching, and auto-queues when they queue if you are in the lobby or at the end screen.'
})
NotifyJoin = StreamSniper:CreateToggle({Name = 'Notify join', Default = true})
AutoQueueToggle = StreamSniper:CreateToggle({Name = 'Auto queue', Default = true})
WhitelistList = StreamSniper:CreateTextList({
	Name = 'Whitelist',
	Default = {},
	Tooltip = 'Add usernames, display names or user IDs',
	Function = function()
		if not WhitelistList then return end
		table.clear(resolvedEntries)
		table.clear(resolvedIds)
		table.clear(resolvedNames)
		resolveEntries(false)
	end
})

end)

run(function()
local FastBreak
local Value
local InstaBreak
local old
local oldMine
local oldBlock

FastBreak = vape.Categories.World:CreateModule({
	Name = 'FastBreak',
	Function = function(callback)
		if callback then
			old = hookfunction(bw.BlockBreakConstants.CooldownFor, function(...)
				return old(...) * (Value.Value / 100)
			end)

			local events = game:GetService("ReplicatedStorage"):FindFirstChild("GameEvents")
			local bedwarsRemotes = events and events:FindFirstChild("BedWarsRemotes")

			local mineRemote = bedwarsRemotes and bedwarsRemotes:FindFirstChild("Mine_AttemptHit")
			if mineRemote then
				oldMine = hookfunction(mineRemote.FireServer, function(self, ...)
					local count = (InstaBreak and InstaBreak.Enabled) and 50 or 1
					for i = 1, count - 1 do
						oldMine(self, ...)
					end
					return oldMine(self, ...)
				end)
			end

			local blockRemote = bedwarsRemotes and bedwarsRemotes:FindFirstChild("Block_AttemptHit")
			if blockRemote then
				oldBlock = hookfunction(blockRemote.FireServer, function(self, ...)
					local count = (InstaBreak and InstaBreak.Enabled) and 50 or 1
					for i = 1, count - 1 do
						oldBlock(self, ...)
					end
					return oldBlock(self, ...)
				end)
			end
		else
			if old then
				hookfunction(bw.BlockBreakConstants.CooldownFor, old)
				old = nil
			end
			local events = game:GetService("ReplicatedStorage"):FindFirstChild("GameEvents")
			local bedwarsRemotes = events and events:FindFirstChild("BedWarsRemotes")
			if oldMine and bedwarsRemotes and bedwarsRemotes:FindFirstChild("Mine_AttemptHit") then
				hookfunction(bedwarsRemotes.Mine_AttemptHit.FireServer, oldMine)
				oldMine = nil
			end
			if oldBlock and bedwarsRemotes and bedwarsRemotes:FindFirstChild("Block_AttemptHit") then
				hookfunction(bedwarsRemotes.Block_AttemptHit.FireServer, oldBlock)
				oldBlock = nil
			end
		end
	end,
	Tooltip = 'Allow you to swing the pickaxe faster.'
})
Value = FastBreak:CreateSlider({
	Name = 'Break Speed Percent',
	Min = 0,
	Max = 100,
	Default = 50,
	Suffix = '%'
})
InstaBreak = FastBreak:CreateToggle({
	Name = 'InstaBreak',
	Tooltip = 'Sends 50 packets per swing to instantly break blocks.'
})
end)

run(function()
local Breaker
local Range
local BreakSpeed
local UpdateRate
local Custom
local Bed
local LuckyBlock
local IronOre
local Effect
local CustomHealth = {}
local Animation
local SelfBreak
local InstantBreak
local LimitItem
local customlist, parts = {}, {}

local function getPick()
	local inv = getInventory()
	for _, tool in inv do
		if tool:GetAttribute('Tier') then
			return tool
		end
	end
end

local function attemptBreak(tab, localPosition, tool)
	if not tab then return end
	for _, v in tab do
		if (v.Position - localPosition).Magnitude < Range.Value and v:GetAttribute('BedTeamId') ~= (lplr.Team and lplr.Team.Name or '') and (v:GetAttribute('HP') or 10) > 0 then
			if tool.Parent ~= lplr.Character then
				entitylib.character.Humanoid:EquipTool(tool)
			end

			if v:HasTag('BedWarsX_BedSpawn') then
				local notCovered = false
				for _, normal in Enum.NormalId:GetEnumItems() do
					if normal ~= Enum.NormalId.Bottom then
						if not blocks[v.Position // 3 + Vector3.fromNormalId(normal)] then
							notCovered = true
							break
						end
					end
				end

				if notCovered then
					bw.RemoteIndex.Block_AttemptHit:FireServer({
						camPos = localPosition,
						hitPos = v:GetClosestPointOnSurface(localPosition),
						blockInstance = v
					})
				else
					local aboveBlock = blocks[v.Position // 3 + Vector3.new(0, 1, 0)]

					if aboveBlock then
						bw.RemoteIndex.Block_AttemptHit:FireServer({
							camPos = localPosition,
							hitPos = aboveBlock:GetClosestPointOnSurface(localPosition),
							blockInstance = aboveBlock
						})
					end
				end

				task.wait(0.15)
			else
				bw.RemoteIndex.Mine_AttemptHit:FireServer(v)
			end

			task.wait(0.05)
			return true
		end
	end

	return false
end

Breaker = vape.Categories.Minigames:CreateModule({
	Name = 'Breaker',
	Function = function(callback)
		if callback then
			local beds = collection('BedWarsX_BedSpawn', Breaker)
			local generators = collection('BedWarsX_Resource', Breaker)

			repeat
				task.wait(1 / UpdateRate.Value)
				if not Breaker.Enabled then break end

				local tool = getPick()
				if entitylib.isAlive and tool and not isAttacking then
					local localPosition = bypassRoot and bypassRoot.Position or entitylib.character.RootPart.Position

					if attemptBreak(beds, localPosition, tool) then continue end
					if attemptBreak(generators, localPosition, tool) then continue end
				end
			until not Breaker.Enabled
		end
	end,
	Tooltip = 'Break blocks around you automatically'
})
Range = Breaker:CreateSlider({
	Name = 'Break range',
	Min = 1,
	Max = 12,
	Default = 12,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
BreakSpeed = Breaker:CreateSlider({
	Name = 'Break speed',
	Min = 0,
	Max = 0.3,
	Default = 0.25,
	Decimal = 100,
	Suffix = 'seconds'
})
UpdateRate = Breaker:CreateSlider({
	Name = 'Update rate',
	Min = 1,
	Max = 120,
	Default = 60,
	Suffix = 'hz'
})
end)

run(function()
local AutoBuy
local shops = {}
local requirements = {
	armor = {
		['Leather Armor'] = 'pickaxe_iron'
	},
	pickaxe = {
		['pickaxe_gold'] = 'Golden Armor',
		['pickaxe_diamond'] = 'Diamond Armor'
	}
}

local function buyCategory(ladder, default)
	local tierItems = {}
	for _, item in bw.ShopConfig.Items do
		if item.ladder == ladder then
			table.insert(tierItems, item)
		end
	end

	table.sort(tierItems, function(a, b)
		return (a.tier or -1) < (b.tier or -1)
	end)

	local nextTier = default and tierItems[1] or nil
	for _, item in tierItems do
		if bw.Inventory.items[item.id] then
			nextTier = tierItems[table.find(tierItems, item) + 1]
			break
		end
	end

	if nextTier then
		for index, item in {'Block', 'Gold', 'Diamond'} do
			if (nextTier.cost and nextTier.cost[item] or 0) > (bw.Inventory[index == 1 and 'blocks' or item:lower()] or 0) then
				return false
			end
		end

		if requirements[ladder] and requirements[ladder][nextTier.id] and not bw.Inventory.items[requirements[ladder][nextTier.id]] then
			return false
		end

		bw.RemoteIndex.Shop_Purchase:InvokeServer({itemId = nextTier.id})
		return true
	end

	return false
end

AutoBuy = vape.Categories.Inventory:CreateModule({
	Name = 'AutoBuy',
	Function = function(callback)
		if callback then
			shops = collection('BedWarsX_ShopNPC')

			repeat
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for _, shop in shops do
						if (shop.Position - localPosition).Magnitude < 20 then
							if buyCategory('armor', true) then break end
							if buyCategory('pickaxe') then break end
							if buyCategory('sword') then break end
							break
						end
					end
				end

				task.wait(0.2)
			until not AutoBuy.Enabled
		end
	end,
	Tooltip = 'lol'
})

end)

-- restore saved profile (options, toggles) after module re-creation
pcall(function() vape:Load() end)
