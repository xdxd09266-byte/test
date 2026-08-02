run(function()
    local oldSpeedUpdate
    local oldJumpUpdate
    local windWalkerController
    
    vape.Categories.Utility:CreateModule({
        Tooltip = "Overrides Zephyr stack logic to give you permanent max stacks for movement.",
        Name = 'Zephyr Disabler',
        Function = function(callback)
            if callback then
                pcall(function()
                    local Knit = require(game:GetService("ReplicatedStorage").rbxts_include.node_modules["@easy-games"].knit.src).KnitClient
                    windWalkerController = Knit.Controllers.WindWalkerController
                    
                    if windWalkerController then
                        if not oldSpeedUpdate then
                            oldSpeedUpdate = windWalkerController.updateSpeed
                            windWalkerController.updateSpeed = function(self, ...)
                                -- Overwrite the incoming multiplier argument to force max speed 
                                -- The server sends multiplier based on orb count, but we force max local modifier.
                                -- Max orbs speed is roughly ~1.7 to 2.0 depending on the current balance update, 
                                -- but we can force it to whatever if the server allows, or just pass a solid high value.
                                -- Let's use 5 (max stacks) equivalent which triggers max boost.
                                local args = {...}
                                -- The server passes a multiplier as the first argument, we can manually apply it or spoof it.
                                -- Zephyr max is usually around 5 stacks.
                                return oldSpeedUpdate(self, 2.0) -- max multiplier bypass
                            end
                        end

                        if not oldJumpUpdate then
                            oldJumpUpdate = windWalkerController.updateJump
                            windWalkerController.updateJump = function(self, ...)
                                -- Force jump update to always think we have 5 orbs (double jump unlocked)
                                return oldJumpUpdate(self, 5)
                            end
                            -- Trigger it immediately to unlock double jump
                            windWalkerController:updateJump(5)
                        end
                        
                        -- Also trick the UI sync event if it exists
                        local ClientSyncEvents = require(game:GetService("ReplicatedStorage").TS["client-sync-events"]).ClientSyncEvents
                        if ClientSyncEvents and ClientSyncEvents.WindWalkerOrbUpdate then
                            ClientSyncEvents.WindWalkerOrbUpdate:fire(5)
                        end
                    end
                end)
            else
                if windWalkerController then
                    if oldSpeedUpdate then
                        windWalkerController.updateSpeed = oldSpeedUpdate
                        oldSpeedUpdate = nil
                    end
                    if oldJumpUpdate then
                        windWalkerController.updateJump = oldJumpUpdate
                        oldJumpUpdate = nil
                    end
                    -- Reset UI
                    pcall(function()
                        local ClientSyncEvents = require(game:GetService("ReplicatedStorage").TS["client-sync-events"]).ClientSyncEvents
                        if ClientSyncEvents and ClientSyncEvents.WindWalkerOrbUpdate then
                            ClientSyncEvents.WindWalkerOrbUpdate:fire(0)
                        end
                    end)
                end
            end
        end
    })
end)
