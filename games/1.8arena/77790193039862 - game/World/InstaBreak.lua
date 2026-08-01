local InstaBreak
local old

InstaBreak = vape.Categories.World:CreateModule({
	Name = 'InstaBreak',
	Function = function(callback)
		if callback then
			old = hookfunction(arena.Client.showMiningProgress, function(progress)
				-- stack depth 3 = the pickaxe RenderStepped callback
				-- slot 5 = v5 (os.clock() - startTime), inflate it so v3 <= v5 is always true
				debug.setstack(3, 5, 99999)
				return old(1)
			end)
		else
			if old then
				hookfunction(arena.Client.showMiningProgress, old)
				old = nil
			end
		end
	end,
	Tooltip = 'Break any breakable block instantly on first swing.'
})
