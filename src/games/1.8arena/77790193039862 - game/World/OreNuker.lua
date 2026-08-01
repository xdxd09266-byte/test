local OreNuker
local Range
local Delay
local TargetCoal
local TargetIron
local TargetGold
local TargetDiamond
local TargetPlayerBlocks

local nukerThread = nil

-- maps toggle refs to block type strings
local function getTargetTypes()
	local t = {}
	if TargetCoal.Enabled       then t["coal_ore"]    = true end
	if TargetIron.Enabled       then t["iron_ore"]    = true end
	if TargetGold.Enabled       then t["gold_ore"]    = true end
	if TargetDiamond.Enabled    then t["diamond_ore"] = true end
	if TargetPlayerBlocks.Enabled then t["tempblock"] = true end
	return t
end

OreNuker = vape.Categories.World:CreateModule({
	Name = 'OreNuker',
	Function = function(callback)
		if callback then
			nukerThread = task.spawn(function()
				while OreNuker.Enabled do
					local targets = getTargetTypes()
					local playerPos = entitylib.character
						and entitylib.character.RootPart
						and entitylib.character.RootPart.Position
						or gameCamera.CFrame.Position

					for _, block in workspace.World:GetChildren() do
						if not OreNuker.Enabled then break end

						local blockType = block:GetAttribute("BlockType")
						if not blockType or not targets[blockType] then continue end

						-- distance check
						local hrp = block.PrimaryPart or block:FindFirstChildOfClass("BasePart")
						if not hrp then continue end
						if (hrp.Position - playerPos).Magnitude > Range.Value then continue end

						-- bypass client-side unbreakable check, let server decide
						block.Parent = replicatedStorage
						local ok = replicatedStorage.Remotes.DestroyCallback:InvokeServer(block)
						if ok then
							block:Destroy()
						else
							-- server rejected (no pickaxe / truly unbreakable) — put back
							if block and block.Parent == replicatedStorage then
								block.Parent = workspace.World
							end
						end

						task.wait(Delay.Value)
					end

					task.wait(0.1) -- scan interval
				end
			end)
		else
			nukerThread = nil
		end
	end,
	Tooltip = 'Auto-mines ores and player-placed blocks within range.\nRequires a pickaxe in hand for ore types.'
})

Range = OreNuker:CreateSlider({
	Name   = 'Range',
	Min    = 1,
	Max    = 64,
	Default = 16,
	Suffix = function(val) return val == 1 and 'stud' or 'studs' end
})
Delay = OreNuker:CreateSlider({
	Name    = 'Break delay',
	Min     = 0,
	Max     = 1,
	Default = 0,
	Decimal = 100,
	Suffix  = function(val) return 's' end
})
TargetCoal         = OreNuker:CreateToggle({ Name = 'Coal ore',    Default = true })
TargetIron         = OreNuker:CreateToggle({ Name = 'Iron ore',    Default = true })
TargetGold         = OreNuker:CreateToggle({ Name = 'Gold ore',    Default = true })
TargetDiamond      = OreNuker:CreateToggle({ Name = 'Diamond ore', Default = true })
TargetPlayerBlocks = OreNuker:CreateToggle({ Name = 'Player blocks', Tooltip = 'Also instabreak enemy-placed blocks (wool/planks).' })
