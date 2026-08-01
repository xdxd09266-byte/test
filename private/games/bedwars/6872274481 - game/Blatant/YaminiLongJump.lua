local PounceBoost
local BoostDuration
local BoostPower
local WallCheck
local AutoJump
local AlwaysJump

local rayCheck = RaycastParams.new()
rayCheck.RespectCanCollide = true

PounceBoost = vape.Categories.Blatant:CreateModule({
    Name = 'Pounce Boost',
    Function = function(callback)
   
        if callback then

            local originalLeap = bedwars.CatController.leap
            

            bedwars.CatController.leap = function(self, character, direction)

                self.midLeap = true
                self.jumpMaid:GiveTask(function()
                    self.midLeap = false
                end)
                
                local hrp = character.HumanoidRootPart
                if not hrp then return end
                
                local mass = hrp.AssemblyMass or 1
                local boostActive = true
                local startTime = tick()
                local duration = BoostDuration.Value -- 1.5 seconds
                local power = BoostPower.Value -- Boost strength
                
    
                character.Humanoid.JumpHeight = 0.5
                character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                
                local boostDirection = direction.Unit * Vector3.new(1, 0, 1)
                
  
                local bodyForce = Instance.new("BodyForce")
                bodyForce.Force = Vector3.new(0, 0, 0)
                bodyForce.Parent = hrp
                

                self.jumpMaid:GiveTask(function()
                    boostActive = false
                    bodyForce:Destroy()
                end)
                
          
                local connection
                connection = runService.Heartbeat:Connect(function(deltaTime)
                    if not boostActive or not hrp.Parent then
                        connection:Disconnect()
                        return
                    end
                    
                    local elapsed = tick() - startTime
                    
                    if elapsed >= duration then
                        boostActive = false
                        bodyForce:Destroy()
                        connection:Disconnect()
                        return
                    end
                    
           
                    local remainingPercent = 1 - (elapsed / duration)
                    local currentForce = mass * power * remainingPercent
             
                    local moveDirection = AntiFallDirection or character.Humanoid.MoveDirection
                    local finalDirection = moveDirection.Magnitude > 0 and moveDirection.Unit or boostDirection
                    
             
                    if WallCheck.Enabled then
                        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
                        rayCheck.CollisionGroup = hrp.CollisionGroup
                        
                        local destination = finalDirection * currentForce * dt
                        local ray = workspace:Raycast(hrp.Position, destination, rayCheck)
                        if ray then
                            destination = ((ray.Position + ray.Normal) - hrp.Position)
               
                            bodyForce.Force = destination / dt
                        else
                            bodyForce.Force = finalDirection * currentForce
                        end
                    else
                        bodyForce.Force = finalDirection * currentForce
                    end
                
                    bodyForce.Force = bodyForce.Force + Vector3.new(0, mass * 30, 0)
                    
           
                    if AutoJump.Enabled then
                        local state = character.Humanoid:GetState()
                        if (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and 
                           moveDirection ~= Vector3.zero and 
                           (Attacking or AlwaysJump.Enabled) then
                            character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                        end
                    end
                end)
                
    
                SoundManager:playSound(RandomUtil.fromList(unpack({
                    GameSound.CAT_POUNCE_1, 
                    GameSound.CAT_POUNCE_2, 
                    GameSound.CAT_POUNCE_3
                })), {
                    position = hrp.Position
                })
                
                KnitClient.Controllers.ViewmodelController:playAnimation(AnimationType.DAGGER_CHARGE)
                KnitClient.Controllers.ViewmodelController:playAnimation(AnimationType.FP_USE_ITEM)
                
       
                PounceBoost:Clean(function()
                    boostActive = false
                    if bodyForce then bodyForce:Destroy() end
                    if connection then connection:Disconnect() end
                    
                    bedwars.CatController.leap = originalLeap
                end)
            end
        else
            
            if originalLeap then
                bedwars.CatController.leap = originalLeap
            end
        end
    end,
    ExtraText = function()
        return 'Heatseeker'
    end,
    Tooltip = 'Boosts your Cat pounce for 1.5 seconds with continuous momentum.'
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
    Max = 150,
    Default = 70,
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

-- Additional options
local FalloffMode = PounceBoost:CreateDropdown({
    Name = 'Falloff Mode',
    Options = {'Linear', 'Exponential', 'None'},
    Default = 'Linear'
})

local VerticalBoost = PounceBoost:CreateSlider({
    Name = 'Vertical Boost',
    Min = 0,
    Max = 100,
    Default = 30,
    Suffix = function(val)
        return val == 1 and 'force' or 'force'
    end
})