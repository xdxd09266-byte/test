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

local function getTargets(limit)
	local e = vape.Libraries.entity
	local me = lplr.Character
	local myTeam = lplr.Team and lplr.Team.Name or ''
	local myPos = e.character.RootPart.Position
	local res = {}

	for _, ent in pairs(e.List) do
		if #res >= limit then
			break
		end

		local char = ent.Character
		if not char or char == me or not char.Parent then
			continue
		end

		local humanoid = char:FindFirstChild('Humanoid')
		if not humanoid or humanoid.Health <= 0 then
			continue
		end

		local teamId = char:GetAttribute('TeamId')
		if not teamId or teamId == myTeam then
			continue
		end

		local root = ent.RootPart
		if root then
			table.insert(res, {
				Character = char,
				RootPart = root
			})
		end
	end

	return res
end

local function attackTarget(tool, target)
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
						vape.Libraries.entity.character.Humanoid:EquipTool(tool)
					end

					local plrs = getTargets(Max.Value)

					if #plrs > 0 then
						isAttacking = true
						local e = vape.Libraries.entity
						local root = e.character.RootPart
						local startCF = root.CFrame

						for _, v in plrs do
							targetinfo.Targets[v] = tick() + 1
							if (os.clock() - (delayTable[v.Character] or 0)) < Rate.Value then
								continue
							end

							if Mode.Value == 'Teleport' then
								root.CFrame = CFrame.lookAt(v.RootPart.Position + Vector3.new(0, 1, 0), v.RootPart.Position)
								task.wait(0.05)
								attackTarget(tool, v)
								task.wait(0.05)
								root.CFrame = startCF
							else
								attackTarget(tool, v)
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
