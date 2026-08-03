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
