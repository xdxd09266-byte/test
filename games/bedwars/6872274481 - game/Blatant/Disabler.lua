local Disabler = {Enabled = false}

run(function()
    local bedwars = shared.bedwars
    if not bedwars then return end

    Disabler = GuiLibrary.ObjectsThatCanBeSaved.BlatantWindow.Api.CreateOptionsButton({
        Name = "Disabler",
        Function = function(callback)
            if callback then
                task.spawn(function()
                    repeat
                        local net = shared.bedwars.Client:GetNamespace("MomentumUpdate")
                        if net then
                            pcall(function()
                                net:SendToServer({
                                    momentumValue = 1e15/math.random()
                                })
                            end)
                        end
                        task.wait()
                    until not Disabler.Enabled
                end)
            end
        end,
        HoverText = "Bypasses Anticheat checks using MomentumUpdate"
    })
end)
