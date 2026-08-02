run(function()
    local oldUpdate
    local skaterController
    
    vape.Categories.Utility:CreateModule({
        Tooltip = "Disables Glacial Skater momentum override so you can fly with Heatseeker.",
        Name = 'Partial Disabler',
        Function = function(callback)
            if callback then
                pcall(function()
                    local Knit = require(game:GetService("ReplicatedStorage").rbxts_include.node_modules["@easy-games"].knit.src).KnitClient
                    skaterController = Knit.Controllers.GlacialSkaterController
                    
                    local MomentumBarUi = require(game:GetService("Players").LocalPlayer.PlayerScripts.TS.controllers.games.bedwars.kit.kits["glacial-skater"]["momentum-bar-ui"])
                    
                    if skaterController and not oldUpdate then
                        oldUpdate = skaterController.updateMomentum
                        skaterController.updateMomentum = function(self, ...)
                            self.momentum = 0
                            if MomentumBarUi and MomentumBarUi.momentumChanged then
                                MomentumBarUi.momentumChanged:Fire(0)
                            end
                            return
                        end
                        
                        -- Also remove the blockSprint modifier that Krystal applies on respawns
                        local SprintController = Knit.Controllers.SprintController
                        if SprintController then
                            local RunService = game:GetService("RunService")
                            KrystalModifierLoop = RunService.Heartbeat:Connect(function()
                                local mod = SprintController:getMovementStatusModifier()
                                if mod and mod.modifiers then
                                    for i = #mod.modifiers, 1, -1 do
                                        if type(mod.modifiers[i]) == "table" and mod.modifiers[i].blockSprint then
                                            mod:removeModifier(mod.modifiers[i])
                                        end
                                    end
                                end
                            end)
                        end
                    end
                end)
            else
                if skaterController and oldUpdate then
                    skaterController.updateMomentum = oldUpdate
                    oldUpdate = nil
                end
                if KrystalModifierLoop then
                    KrystalModifierLoop:Disconnect()
                    KrystalModifierLoop = nil
                end
            end
            end
        end
    })
end)
