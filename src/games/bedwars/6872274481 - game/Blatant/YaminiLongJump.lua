local PounceBoost
local BoostDuration
local BoostPower
local WallCheck
local AutoJump
local AlwaysJump
local rayCheck = RaycastParams.new()
rayCheck.RespectCanCollide = true

local bv
local oldLeap
local function leapHook(self, char, dir)
	local hrp = char and char.HumanoidRootPart
	if hrp and isnetworkowner(hrp) then
		local power = BoostPower.Value
		local horizontalDir = (dir * Vector3.new(1, 0, 1)).Unit
		if horizontalDir.Magnitude < 0.01 then
			horizontalDir = (gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
		end
		oldLeap(self, char, dir)
		local mass = hrp.AssemblyMass or 1
		hrp:ApplyImpulse(horizontalDir * mass * (power * 5.0))
		JumpDir = horizontalDir
		JumpSpeed = power * 5.0
		JumpTick = tick() + BoostDuration.Value
		if bv then
			bv.Parent = nil
			bv:Destroy()
		end
		bv = Instance.new("BodyVelocity")
		bv.Velocity = horizontalDir * JumpSpeed + Vector3.new(0, hrp.Velocity.Y, 0)
		bv.MaxForce = Vector3.new(9e9, 0, 9e9)
		bv.Parent = hrp
	else
		oldLeap(self, char, dir)
	end
end

PounceBoost = vape.Categories.Blatant:CreateModule({
    Name = 'YaminiLongJump',
    Function = function(callback)
        if callback then
			oldLeap = bedwars.CatController.leap
			bedwars.CatController.leap = leapHook
			PounceBoost:Clean(function()
				if bedwars.CatController.leap == leapHook then
					bedwars.CatController.leap = oldLeap
				end
			end)
            PounceBoost:Clean(vapeEvents.CatPounce.Event:Connect(function()
                vape:CreateNotification('YaminiLongJump', 'found cat_pounce boost 1.5sec', 3)
            end))
            PounceBoost:Clean(runService.PreSimulation:Connect(function(dt)
                local root = entitylib.isAlive and entitylib.character.RootPart or nil
                if not root or not isnetworkowner(root) then return end
                if JumpTick > tick() then
                    local remaining = (JumpTick - tick()) / BoostDuration.Value
                    local speed = JumpSpeed * remaining
                    local moveDir = entitylib.isAlive and entitylib.character.Humanoid.MoveDirection or Vector3.zero
                    local finalDir = moveDir.Magnitude > 0 and moveDir.Unit or JumpDir
                    if WallCheck.Enabled then
                        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
                        rayCheck.CollisionGroup = root.CollisionGroup
                        local destination = finalDir * speed * dt
                        local ray = workspace:Raycast(root.Position, destination, rayCheck)
                        if ray then
                            finalDir = ((ray.Position + ray.Normal) - root.Position).Unit
                        end
                    end
                    if bv and bv.Parent then
                        bv.Velocity = finalDir * speed + Vector3.new(0, 0, 0)
                    end
                    if entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air then
                        root.AssemblyLinearVelocity = finalDir * speed + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                        root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - 23), 0)
                    else
                        root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 15, root.AssemblyLinearVelocity.Z)
                    end
                    if AutoJump.Enabled then
                        local state = entitylib.character.Humanoid:GetState()
                        if (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and moveDir.Magnitude > 0 and (AlwaysJump.Enabled) then
                            entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                        end
                    end
                elseif bv and bv.Parent then
                    bv:Destroy()
                    bv = nil
                end
            end))
            if not bedwars.AbilityController:canUseAbility('CAT_POUNCE') then
                repeat task.wait() until bedwars.AbilityController:canUseAbility('CAT_POUNCE') or not PounceBoost.Enabled
            end
            if PounceBoost.Enabled then
                bedwars.AbilityController:useAbility('CAT_POUNCE')
            end
        else
            JumpTick = tick()
            JumpSpeed = 0
            if bv then
                bv:Destroy()
                bv = nil
            end
        end
    end,
    ExtraText = function()
        return 'Heatseeker'
    end,
    Tooltip = 'Boosts your Cat pounce using a BodyVelocity force override.'
})

BoostDuration = PounceBoost:CreateSlider({
    Name = 'Boost Duration',
    Min = 0.5,
    Max = 3.0,
    Default = 1.5,
    Decimal = true,
    Suffix = function(val)
        return val .. 's'
    end
})

BoostPower = PounceBoost:CreateSlider({
    Name = 'Boost Power',
    Min = 10,
    Max = 300,
    Default = 100,
    Suffix = function(val)
        return val == 1 and 'force' or 'force'
    end
})

WallCheck = PounceBoost:CreateToggle({
    Name = 'Wall Check',
    Default = true
})

AutoJump = PounceBoost:CreateToggle({
    Name = 'AutoJump',
    Function = function(callback)
        AlwaysJump.Object.Visible = callback
    end
})

AlwaysJump = PounceBoost:CreateToggle({
    Name = 'Always Jump',
    Visible = false,
    Darker = true
})
