local TexturePack
local Mode
local currentConnection
local loadedPacks = {}

local packAssets = {
	Acidic = 'rbxassetid://14245759641',
	Devourer = 'rbxassetid://14258977192',
	Enlightened = 'rbxassetid://14261862180',
	FatCat = 'rbxassetid://100570768622198',
	Fury = 'rbxassetid://14331255019',
	Makima = 'rbxassetid://14335043180',
	['Marin-Kitsawaba'] = 'rbxassetid://14405573385',
	Moon4Real = 'rbxassetid://14271708146',
	Nebula = 'rbxassetid://14654171957',
	Onyx = 'rbxassetid://14334779267',
	Prime = 'rbxassetid://14479023830',
	Simply = 'rbxassetid://117028342668949',
	Vile = 'rbxassetid://14247192725',
	VioletsDreams = 'rbxassetid://14248304333',
	Wichtiger = 'rbxassetid://14320382383'
}

local function applyTexturePack(packName)
	if currentConnection then
		currentConnection:Disconnect()
		currentConnection = nil
	end

	local assetId = packAssets[packName]
	if not assetId then return end

	task.spawn(function()
		local import = loadedPacks[packName]
		if not import then
			local success, objs = pcall(function()
				return game:GetObjects(assetId)
			end)
			if success and objs and objs[1] then
				import = objs[1]
				import.Parent = replicatedStorage
				for _, part in pairs(import:GetDescendants()) do
					if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
						pcall(function() part.CanCollide = false; part.CanQuery = false end)
					end
				end
				loadedPacks[packName] = import
			end
		end

		if not import then return end

		local viewmodel = gameCamera:WaitForChild("Viewmodel", 5)
		if not viewmodel then return end

		local items = import:GetChildren()

		local function handleTool(tool)
			if not tool or not TexturePack.Enabled then return end

			local targetModel = nil
			local offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90))

			local toolLower = tool.Name:lower()
			for _, v in pairs(items) do
				if v.Name:lower() == toolLower then
					targetModel = v
					if v.Name:find("axe") then
						offset = CFrame.new(0, 0.45, 0) * CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95))
					end
					break
				end
			end

			if not targetModel then
				local nameMap = {
					wood_sword = "Wood_Sword",
					stone_sword = "Stone_Sword",
					iron_sword = "Iron_Sword",
					diamond_sword = "Diamond_Sword",
					emerald_sword = "Emerald_Sword"
				}
				local mapped = nameMap[toolLower]
				if mapped then
					targetModel = import:FindFirstChild(mapped)
				end
			end

			if not targetModel then
				for _, v in pairs(items) do
					if toolLower:find("sword") and v.Name:lower():find("sword") then
						targetModel = v
						break
					end
				end
			end

			if targetModel then
				for _, existing in pairs(tool:GetChildren()) do
					if existing:IsA("WeldConstraint") or existing:IsA("Model") then
						existing:Destroy()
					end
				end

				for _, part in pairs(tool:GetDescendants()) do
					if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
						part.Transparency = 1
						pcall(function() part.CanCollide = false; part.CanQuery = false end)
					end
				end

				local handle = tool:WaitForChild("Handle", 2)
				if handle then
					local clone = targetModel:Clone()
					for _, part in pairs(clone:GetDescendants()) do
						if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
							pcall(function() part.CanCollide = false; part.CanQuery = false end)
						end
					end
					clone.CFrame = handle.CFrame * offset * CFrame.Angles(0, math.rad(-50), 0)
					clone.Size *= Vector3.new(1.375, 1.375, 1.375)
					clone.Parent = tool

					local weld = Instance.new("WeldConstraint", clone)
					weld.Part0 = clone
					weld.Part1 = handle
				end
			end
		end

		local function onToolAdded(child)
			if child:IsA("Accessory") or child:IsA("Tool") then
				handleTool(child)
				child:GetPropertyChangedSignal("Name"):Connect(function()
					handleTool(child)
				end)
			end
		end

		currentConnection = viewmodel.ChildAdded:Connect(onToolAdded)

		viewmodel.ChildRemoved:Connect(function(child)
			for _, v in pairs(child:GetChildren()) do
				if v:IsA("WeldConstraint") or v:IsA("MeshPart") or v:IsA("Part") then
					v:Destroy()
				end
			end
		end)

		for _, child in pairs(viewmodel:GetChildren()) do
			onToolAdded(child)
		end

		task.spawn(function()
			while TexturePack.Enabled and viewmodel and viewmodel.Parent do
				task.wait(0.5)
				for _, child in pairs(viewmodel:GetChildren()) do
					if child:IsA("Accessory") or child:IsA("Tool") then
						handleTool(child)
					end
				end
			end
		end)
	end)
end

TexturePack = vape.Legit:CreateModule({
	Name = 'Texture Pack',
	Function = function(callback)
		if callback then
			applyTexturePack(Mode.Value)
		else
			if currentConnection then
				currentConnection:Disconnect()
				currentConnection = nil
			end
		end
	end,
	Tooltip = 'Custom BedWars Texture Packs'
})

Mode = TexturePack:CreateDropdown({
	Name = 'Mode',
	List = {
		'Acidic', 'Devourer', 'Enlightened', 'FatCat', 'Fury',
		'Makima', 'Marin-Kitsawaba', 'Moon4Real', 'Nebula', 'Onyx',
		'Prime', 'Simply', 'Vile', 'VioletsDreams', 'Wichtiger'
	},
	Function = function(val)
		if TexturePack.Enabled then
			applyTexturePack(val)
		end
	end
})
