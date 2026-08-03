local Cape, Mode, Source, Texture
local part, motor, capesurface
local currentImage

local function getRangikuTexture()
	local path = "weedhack/cape/rangiku.png"
	if isfile(path) then
		return assetfunction(path)
	end
	return 'rbxassetid://14637958134'
end

local function resolveTexture()
	local mode = Mode.Value
	if mode == 'Rangiku' then
		return getRangikuTexture()
	elseif mode == 'Vape' then
		return 'rbxassetid://14637958134'
	end
	local input = Texture.Value
	if input == '' or input:find('rbxasset') then
		return input == '' and 'rbxassetid://14637958134' or input
	end
	local src = Source.Value
	if src == 'Local File' then
		return isfile(input) and assetfunction(input) or 'rbxassetid://14637958134'
	elseif src == 'GitHub URL' then
		local suc, data = pcall(game.HttpGet, game, input, true)
		if suc and data then
			local ext = input:match('%.(%w+)$') or 'png'
			local path = 'vape/cache/cape.' .. ext
			writefile(path, data)
			return isfile(path) and assetfunction(path) or 'rbxassetid://14637958134'
		end
		return 'rbxassetid://14637958134'
	end
	return assetfunction(input)
end

local function createMotor(char)
	if motor then
		motor:Destroy()
	end
	part.Parent = gameCamera
	motor = Instance.new('Motor6D')
	motor.MaxVelocity = 0.08
	motor.Part0 = part
	motor.Part1 = char.Character:FindFirstChild('UpperTorso') or char.RootPart
	motor.C0 = CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(-90), 0)
	motor.C1 = CFrame.new(0, motor.Part1.Size.Y / 2, 0.45) * CFrame.Angles(0, math.rad(90), 0)
	motor.Parent = part
end

local function refreshTexture()
	if capesurface and capesurface:FindFirstChildOfClass("ImageLabel") then
		capesurface:FindFirstChildOfClass("ImageLabel").Image = resolveTexture()
	end
end

Cape = vape.Legit:CreateModule({
	Name = 'Cape',
	Function = function(callback)
		if callback then
			part = Instance.new('Part')
			part.Size = Vector3.new(2, 4, 0.1)
			part.CanCollide = false
			part.CanQuery = false
			part.Massless = true
			part.Transparency = 0
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.new()
			part.CastShadow = false
			part.Parent = gameCamera

			capesurface = Instance.new('SurfaceGui')
			capesurface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			capesurface.Adornee = part
			capesurface.Face = Enum.NormalId.Front
			capesurface.Parent = part

			local decal = Instance.new('ImageLabel')
			decal.Image = resolveTexture()
			decal.Size = UDim2.fromScale(1, 1)
			decal.BackgroundTransparency = 1
			decal.Parent = capesurface
			currentImage = decal

			Cape:Clean(part)
			Cape:Clean(entitylib.Events.LocalAdded:Connect(createMotor))
			if entitylib.isAlive then
				createMotor(entitylib.character)
			end

			repeat
				if motor and entitylib.isAlive then
					local velo = math.min(entitylib.character.RootPart.Velocity.Magnitude, 90)
					motor.DesiredAngle = math.rad(6) + math.rad(velo) + (velo > 1 and math.abs(math.cos(tick() * 5)) / 3 or 0)
				end
				capesurface.Enabled = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6
				part.Transparency = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6 and 0 or 1
				task.wait()
			until not Cape.Enabled
		else
			part = nil
			motor = nil
			currentImage = nil
		end
	end,
	Tooltip = 'Add\'s a cape to your character'
})

Mode = Cape:CreateDropdown({
	Name = 'Mode',
	List = {'Rangiku', 'Vape', 'Custom'},
	Default = 1,
	Function = function()
		if Cape.Enabled then
			refreshTexture()
		end
	end
})
Source = Cape:CreateDropdown({
	Name = 'Source',
	List = {'rbxassetid', 'Local File', 'GitHub URL'},
	Default = 1
})
Texture = Cape:CreateTextBox({
	Name = 'Texture',
	Function = function()
		if Cape.Enabled then
			refreshTexture()
		end
	end
})

