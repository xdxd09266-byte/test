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
                    
                    if skaterController and not oldUpdate then
                        oldUpdate = skaterController.updateMomentum
                        skaterController.updateMomentum = function(self, ...)
                            -- Intercept and cancel updateMomentum entirely
                            -- This prevents SprintController:setSpeed() from being forced back down
                            -- and stops the MomentumUpdate remote from firing.
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
