run(function()
    local oldUpdate
    local skaterController
    local Knit
    local KrystalHeartbeat
    
    vape.Categories.Utility:CreateModule({
        Tooltip = "Disables Krystal (Glacial Skater) anticheat by forcing max momentum server-side.",
        Name = 'Partial Disabler',
        Function = function(callback)
            if callback then
                pcall(function()
                    Knit = require(game:GetService("ReplicatedStorage").rbxts_include.node_modules["@easy-games"].knit.src).KnitClient
                    skaterController = Knit.Controllers.GlacialSkaterController
                    
                    if skaterController and not oldUpdate then
                        oldUpdate = skaterController.updateMomentum
                        
                        -- Hook updateMomentum: always proxy to original with MAX momentum (100)
                        -- This makes the original code:
                        --   1. Set self.momentum = clamp(100, 0, 100) = 100
                        --   2. Fire momentumChanged(100) for UI
                        --   3. Send MomentumUpdate packet to server with {momentumValue = 100}
                        --   4. Apply HIGH_SPEED_SKATING status effect (momentum >= 95)
                        --   5. Set SprintController speed to getMomentumSpeed(100) = 27
                        skaterController.updateMomentum = function(self, p2, p3)
                            return oldUpdate(self, 100, "newValue")
                        end
                        
                        local SprintController = Knit.Controllers.SprintController
                        local RunService = game:GetService("RunService")
                        
                        KrystalHeartbeat = RunService.Heartbeat:Connect(function()
                            -- Remove blockSprint modifiers that Krystal re-applies on every respawn
                            if SprintController then
                                local mod = SprintController:getMovementStatusModifier()
                                if mod and mod.modifiers then
                                    for i = #mod.modifiers, 1, -1 do
                                        if type(mod.modifiers[i]) == "table" and mod.modifiers[i].blockSprint then
                                            mod:removeModifier(mod.modifiers[i])
                                        end
                                    end
                                end
                            end
                            
                            -- Force momentum update every frame so packets keep flowing
                            -- even when the original Heartbeat bails (speed > 100 studs/sec while flying)
                            if skaterController and oldUpdate then
                                pcall(oldUpdate, skaterController, 100, "newValue")
                            end
                        end)
                    end
                end)
            else
                if skaterController and oldUpdate then
                    skaterController.updateMomentum = oldUpdate
                    oldUpdate = nil
                end
                if KrystalHeartbeat then
                    KrystalHeartbeat:Disconnect()
                    KrystalHeartbeat = nil
                end
            end
        end
    })
end)
