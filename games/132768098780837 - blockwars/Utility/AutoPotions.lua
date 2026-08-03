local AutoPotions
local toggles = {}
local nextDrink = {}
local AutoBuyToggle
local potions = {
	potion_invis = {tool = 'InvisiblePotion', fallback = 15},
	potion_speed = {tool = 'SpeedPotion', fallback = 15},
	potion_jump = {tool = 'JumpPotion', fallback = 15}
}

for id, info in potions do
	local item = bw.ShopConfig.Items[id]
	info.duration = (item and item.stats and item.stats.duration) or info.fallback
end

local function findTool(id)
	local name = potions[id].tool
	for _, tool in getInventory() do
		if tool.Name == name or tool:GetAttribute('_BaseName') == name then
			return tool
		end
	end
	return nil
end

local function drink(id)
	local tool = findTool(id)
	if not tool then
		local item = bw.ShopConfig.Items[id]
		local cost = item and item.cost and item.cost.Block or 0
		if AutoBuyToggle.Enabled and cost > 0 and (bw.Inventory.blocks or 0) >= cost then
			bw.RemoteIndex.Shop_Purchase:InvokeServer({itemId = id})
			tool = findTool(id)
		end
		if not tool then
			return
		end
	end

	if tool.Parent ~= entitylib.character then
		entitylib.character.Humanoid:EquipTool(tool)
	end
	tool:Activate()
	nextDrink[id] = workspace:GetServerTimeNow() + potions[id].duration + 1
end

AutoPotions = vape.Categories.Utility:CreateModule({
	Name = 'AutoPotions',
	Function = function(callback)
		if callback then
			task.spawn(function()
				repeat
					if entitylib.isAlive then
						local now = workspace:GetServerTimeNow()
						for id, toggle in toggles do
							if toggle.Enabled and (nextDrink[id] or 0) < now then
								drink(id)
							end
						end
					end
					task.wait(0.5)
				until not AutoPotions.Enabled
				table.clear(nextDrink)
			end)
		end
	end,
	Tooltip = 'Buys and drinks potions as soon as their effect wears off: permanent invisibility, speed and jump.'
})
toggles.potion_invis = AutoPotions:CreateToggle({Name = 'Invis', Default = true})
toggles.potion_speed = AutoPotions:CreateToggle({Name = 'Speed'})
toggles.potion_jump = AutoPotions:CreateToggle({Name = 'Jump'})
AutoBuyToggle = AutoPotions:CreateToggle({Name = 'Auto buy', Default = true})
