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
                            -- Force momentum to 0 internally
                            self.momentum = 0
                            
                            -- Fire the UI event to visibly empty the bar
                            if MomentumBarUi and MomentumBarUi.momentumChanged then
                                MomentumBarUi.momentumChanged:Fire(0)
                            end
                            
                            return
                        end
                    end
                end)
            else
                if skaterController and oldUpdate then
                    skaterController.updateMomentum = oldUpdate
                    oldUpdate = nil
                end
            end
        end
    })
end)
