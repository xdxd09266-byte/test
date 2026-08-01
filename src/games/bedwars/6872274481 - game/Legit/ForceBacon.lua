local ForceBacon

local function applyBacon(char)
	local bc = char:FindFirstChild("Body Colors")
	if bc then
		bc.HeadColor = BrickColor.new("Bright yellowish green")
		bc.TorsoColor = BrickColor.new("Bright blue")
		bc.LeftArmColor = BrickColor.new("Bright yellowish green")
		bc.RightArmColor = BrickColor.new("Bright yellowish green")
		bc.LeftLegColor = BrickColor.new("Bright blue")
		bc.RightLegColor = BrickColor.new("Bright blue")
	end
	local clothing = char:FindFirstChild("3DClothing")
	if clothing then
		clothing:ClearAllChildren()
	end
	for _, child in pairs(char:GetChildren()) do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") or child:IsA("CharacterMesh") then
			child:Destroy()
		end
	end
end

ForceBacon = vape.Legit:CreateModule({
	Name = 'Force Bacon',
	Function = function(callback)
		if callback then
			if entitylib.isAlive then
				applyBacon(entitylib.character.Character)
			end
			ForceBacon:Clean(entitylib.Events.LocalAdded:Connect(function(char)
				applyBacon(char)
			end))
		end
	end,
	Tooltip = 'Forces your kit model to default Bacon appearance'
})
