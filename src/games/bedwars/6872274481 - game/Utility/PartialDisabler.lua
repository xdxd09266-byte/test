run(function()
    local old

    vape.Categories.Utility:CreateModule({
        Tooltip = "Needs krystal equipped to work.",
        Name = 'Partial Disabler',
        Function = function(callback)
            if callback then
                bedwars.GlacialSkaterController:updateMomentum(9e9)
                old = bedwars.GlacialSkaterController.updateMomentum
                bedwars.GlacialSkaterController.updateMomentum = function(self)
                    self.momentum = 9e9
                    self.lastMomentumReport = 9e9
                    bedwars.Client:Get('MomentumUpdate'):SendToServer({
                        momentumValue = 9e9
                    })
                end
                bedwars.GlacialSkaterController:updateMomentum()
            else
                bedwars.GlacialSkaterController.updateMomentum = old
            end
        end
    })
end) 
