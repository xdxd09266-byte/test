local FastBreak
local Value
local InstaBreak
local old
local oldMine
local oldBlock

FastBreak = vape.Categories.World:CreateModule({
	Name = 'FastBreak',
	Function = function(callback)
		if callback then
			old = hookfunction(bw.BlockBreakConstants.CooldownFor, function(...)
				return old(...) * (Value.Value / 100)
			end)

			local events = game:GetService("ReplicatedStorage"):FindFirstChild("GameEvents")
			local bedwarsRemotes = events and events:FindFirstChild("BedWarsRemotes")

			local mineRemote = bedwarsRemotes and bedwarsRemotes:FindFirstChild("Mine_AttemptHit")
			if mineRemote then
				oldMine = hookfunction(mineRemote.FireServer, function(self, ...)
					local count = (InstaBreak and InstaBreak.Enabled) and 50 or 1
					for i = 1, count - 1 do
						oldMine(self, ...)
					end
					return oldMine(self, ...)
				end)
			end

			local blockRemote = bedwarsRemotes and bedwarsRemotes:FindFirstChild("Block_AttemptHit")
			if blockRemote then
				oldBlock = hookfunction(blockRemote.FireServer, function(self, ...)
					local count = (InstaBreak and InstaBreak.Enabled) and 50 or 1
					for i = 1, count - 1 do
						oldBlock(self, ...)
					end
					return oldBlock(self, ...)
				end)
			end
		else
			if old then
				hookfunction(bw.BlockBreakConstants.CooldownFor, old)
				old = nil
			end
			local events = game:GetService("ReplicatedStorage"):FindFirstChild("GameEvents")
			local bedwarsRemotes = events and events:FindFirstChild("BedWarsRemotes")
			if oldMine and bedwarsRemotes and bedwarsRemotes:FindFirstChild("Mine_AttemptHit") then
				hookfunction(bedwarsRemotes.Mine_AttemptHit.FireServer, oldMine)
				oldMine = nil
			end
			if oldBlock and bedwarsRemotes and bedwarsRemotes:FindFirstChild("Block_AttemptHit") then
				hookfunction(bedwarsRemotes.Block_AttemptHit.FireServer, oldBlock)
				oldBlock = nil
			end
		end
	end,
	Tooltip = 'Allow you to swing the pickaxe faster.'
})
Value = FastBreak:CreateSlider({
	Name = 'Break Speed Percent',
	Min = 0,
	Max = 100,
	Default = 50,
	Suffix = '%'
})
InstaBreak = FastBreak:CreateToggle({
	Name = 'InstaBreak',
	Tooltip = 'Sends 50 packets per swing to instantly break blocks.'
})