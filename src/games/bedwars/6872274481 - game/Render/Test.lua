run(function()
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")
	
	local TestModule
	local GUI
	local connection
	
	local function createUI()
		if GUI then GUI:Destroy() end
		
		GUI = Instance.new("ScreenGui")
		GUI.Name = "TestVapeUI"
		GUI.ResetOnSpawn = false
		GUI.IgnoreGuiInset = true
		GUI.DisplayOrder = 1000
		
		local success, parent = pcall(function() return lplr:WaitForChild("PlayerGui") end)
		if not success then parent = game:GetService("CoreGui") end
		GUI.Parent = parent
		
		-- Background dim
		local bg = Instance.new("Frame")
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		bg.BackgroundTransparency = 1
		bg.BorderSizePixel = 0
		bg.Parent = GUI
		
		-- 1. Splash Screen Layer
		local splashLayer = Instance.new("Frame")
		splashLayer.Size = UDim2.new(1, 0, 1, 0)
		splashLayer.BackgroundTransparency = 1
		splashLayer.Parent = GUI
		
		local helloText = Instance.new("TextLabel")
		helloText.Size = UDim2.new(1, 0, 1, 0)
		helloText.Position = UDim2.new(-1, 0, 1, 0) -- starts bottom left
		helloText.BackgroundTransparency = 1
		helloText.Text = "Hello!"
		helloText.TextColor3 = Color3.fromRGB(255, 255, 255)
		helloText.TextSize = 48
		helloText.Font = Enum.Font.GothamBold
		helloText.Parent = splashLayer
		
		local instructionText = Instance.new("TextLabel")
		instructionText.Size = UDim2.new(1, 0, 1, 0)
		instructionText.BackgroundTransparency = 1
		instructionText.Text = "To start your journey press Right Shift. Or press the logo if you're on mobile."
		instructionText.TextColor3 = Color3.fromRGB(255, 255, 255)
		instructionText.TextSize = 24
		instructionText.Font = Enum.Font.GothamMedium
		instructionText.TextTransparency = 1
		instructionText.Parent = splashLayer
		
		local mobileLogo = Instance.new("ImageButton")
		mobileLogo.Size = UDim2.new(0, 50, 0, 50)
		mobileLogo.Position = UDim2.new(0, 20, 0, 20)
		mobileLogo.BackgroundTransparency = 1
		mobileLogo.Image = "rbxassetid://10888331510" -- Example generic logo asset
		mobileLogo.ImageTransparency = 1
		mobileLogo.Parent = splashLayer
		
		-- Hide real clickgui if it's open
		local realClickGui
		pcall(function()
			realClickGui = vape.gui.ScaledGui.ClickGui
			if realClickGui.Visible then
				realClickGui.Visible = false
			end
		end)
		
		-- Splash Animations
		TweenService:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 0.5}):Play()
		local t1 = TweenService:Create(helloText, TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)})
		t1:Play()
		
		task.delay(2, function()
			TweenService:Create(helloText, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
			task.wait(0.5)
			TweenService:Create(instructionText, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
			TweenService:Create(mobileLogo, TweenInfo.new(0.5), {ImageTransparency = 0}):Play()
		end)
		
		local function startJourney()
			TweenService:Create(splashLayer, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
			TweenService:Create(instructionText, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
			TweenService:Create(mobileLogo, TweenInfo.new(0.5), {ImageTransparency = 1}):Play()
			task.delay(0.5, function()
				splashLayer:Destroy()
				showDeviceSelection()
			end)
		end
		
		-- Wait for input
		local inputConn
		inputConn = UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe then return end
			if input.KeyCode == Enum.KeyCode.RightShift then
				inputConn:Disconnect()
				startJourney()
			end
		end)
		mobileLogo.MouseButton1Click:Connect(function()
			inputConn:Disconnect()
			startJourney()
		end)
		
		-- 2. Device Selection Screen Layer
		function showDeviceSelection()
			local deviceLayer = Instance.new("Frame")
			deviceLayer.Size = UDim2.new(1, 0, 1, 0)
			deviceLayer.BackgroundTransparency = 1
			deviceLayer.Parent = GUI
			
			local heading = Instance.new("TextLabel")
			heading.Size = UDim2.new(1, 0, 0, 50)
			heading.Position = UDim2.new(0, 0, 0.3, 0)
			heading.BackgroundTransparency = 1
			heading.Text = "Select your device:"
			heading.TextColor3 = Color3.fromRGB(255, 255, 255)
			heading.TextSize = 32
			heading.Font = Enum.Font.GothamBold
			heading.TextTransparency = 1
			heading.Parent = deviceLayer
			
			local pcBtn = Instance.new("TextButton")
			pcBtn.Size = UDim2.new(0, 200, 0, 60)
			pcBtn.Position = UDim2.new(0.5, -220, 0.5, 0)
			pcBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			pcBtn.Text = "PC"
			pcBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			pcBtn.Font = Enum.Font.GothamMedium
			pcBtn.TextSize = 24
			pcBtn.BackgroundTransparency = 1
			pcBtn.TextTransparency = 1
			pcBtn.AutoButtonColor = false
			local pcc = Instance.new("UICorner", pcBtn)
			pcBtn.Parent = deviceLayer
			
			local mobBtn = Instance.new("TextButton")
			mobBtn.Size = UDim2.new(0, 200, 0, 60)
			mobBtn.Position = UDim2.new(0.5, 20, 0.5, 0)
			mobBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			mobBtn.Text = "MOBILE"
			mobBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			mobBtn.Font = Enum.Font.GothamMedium
			mobBtn.TextSize = 24
			mobBtn.BackgroundTransparency = 1
			mobBtn.TextTransparency = 1
			mobBtn.AutoButtonColor = false
			local mobc = Instance.new("UICorner", mobBtn)
			mobBtn.Parent = deviceLayer
			
			TweenService:Create(heading, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
			TweenService:Create(pcBtn, TweenInfo.new(0.5), {BackgroundTransparency = 0, TextTransparency = 0}):Play()
			TweenService:Create(mobBtn, TweenInfo.new(0.5), {BackgroundTransparency = 0, TextTransparency = 0}):Play()
			
			local function runTour()
				local targets = {
					{Name = "AimAssist", Category = "Combat", Desc = "Aim Assist\nIts pretty much self explaining."},
					{Name = "Killaura", Category = "Blatant", Desc = "Kill Aura\nWhen you enable it. It will attack players around you"},
					{Name = "Reach", Category = "Combat", Desc = "Reach\nMakes you attack players from a longer distance."}
				}
				
				local defaultScale = vape.guiscale and vape.guiscale.Scale or 1
				local camera = workspace.CurrentCamera
				
				for _, target in ipairs(targets) do
					local cat = vape.Categories[target.Category]
					if not cat then continue end
					local catWindow = cat.Object
					
					local scrollFrame = nil
					local modBtn = nil
					
					for _, v in catWindow:GetDescendants() do
						if (v:IsA("TextLabel") or v:IsA("TextButton")) then
							local cleanName = string.gsub(v.Text:lower(), "[^%w]", "")
							if cleanName == target.Name:lower() then
								local current = v
								while current and current.Parent and not current.Parent:IsA("ScrollingFrame") do
									if current.Parent == catWindow then break end
									current = current.Parent
								end
								modBtn = current
								if current and current.Parent and current.Parent:IsA("ScrollingFrame") then
									scrollFrame = current.Parent
								end
								break
							end
						end
					end
					
					if catWindow and modBtn then
						-- 1. Tween Category to Center
						local screenX = (camera.ViewportSize.X / defaultScale)
						local screenY = (camera.ViewportSize.Y / defaultScale)
						local targetPos = UDim2.fromOffset(screenX/2 - catWindow.AbsoluteSize.X/(2 * defaultScale), screenY/2 - catWindow.AbsoluteSize.Y/(2 * defaultScale))
						TweenService:Create(catWindow, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = targetPos}):Play()
						task.wait(0.6)
						
						-- 2. Scroll to Module (if in a scrolling frame)
						if scrollFrame then
							local btnY = modBtn.AbsolutePosition.Y - scrollFrame.AbsolutePosition.Y + scrollFrame.CanvasPosition.Y
							local targetCanvasY = btnY - (scrollFrame.AbsoluteSize.Y / 2) + (modBtn.AbsoluteSize.Y / 2)
							targetCanvasY = math.clamp(targetCanvasY, 0, math.max(0, scrollFrame.CanvasSize.Y.Offset - scrollFrame.AbsoluteSize.Y))
							
							TweenService:Create(scrollFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CanvasPosition = Vector2.new(0, targetCanvasY)}):Play()
							task.wait(0.6)
						end
						
						-- 3. Zoom In
						if vape.guiscale then
							TweenService:Create(vape.guiscale, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = defaultScale * 1.8}):Play()
						end
						
						-- Refine Center position after zoom (since AbsoluteSize changes)
						local zoomPos = UDim2.fromOffset((camera.ViewportSize.X / (defaultScale * 1.8))/2 - catWindow.AbsoluteSize.X/(2 * defaultScale * 1.8), (camera.ViewportSize.Y / (defaultScale * 1.8))/2 - catWindow.AbsoluteSize.Y/(2 * defaultScale * 1.8))
						TweenService:Create(catWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = zoomPos}):Play()
						task.wait(0.5)
						
						-- 4. Tooltip
						local tooltip = Instance.new("Frame")
						tooltip.Size = UDim2.new(0, 0, 0, 0)
						tooltip.Position = UDim2.new(1, 15, 0.5, -30)
						tooltip.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
						tooltip.BorderSizePixel = 0
						tooltip.ClipsDescendants = true
						Instance.new("UICorner", tooltip).CornerRadius = UDim.new(0, 8)
						local stroke = Instance.new("UIStroke", tooltip)
						stroke.Color = Color3.fromRGB(60, 60, 60)
						stroke.Thickness = 1.5
						
						local lbl = Instance.new("TextLabel")
						lbl.Size = UDim2.new(1, -16, 1, -16)
						lbl.Position = UDim2.new(0, 8, 0, 8)
						lbl.BackgroundTransparency = 1
						lbl.Text = target.Desc
						lbl.TextColor3 = Color3.new(1, 1, 1)
						lbl.TextWrapped = true
						lbl.Font = Enum.Font.GothamMedium
						lbl.TextSize = 14
						lbl.TextXAlignment = Enum.TextXAlignment.Left
						lbl.Parent = tooltip
						
						tooltip.Parent = modBtn
						
						TweenService:Create(tooltip, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 220, 0, 70)}):Play()
						
						task.wait(3.5)
						
						-- 5. Zoom Out & Cleanup
						TweenService:Create(tooltip, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)}):Play()
						task.wait(0.3)
						tooltip:Destroy()
						
						if vape.guiscale then
							TweenService:Create(vape.guiscale, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = defaultScale}):Play()
						end
						task.wait(0.5)
					end
				end
			end
			
			local function onDeviceSelected(device)
				TweenService:Create(deviceLayer, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
				TweenService:Create(heading, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
				TweenService:Create(pcBtn, TweenInfo.new(0.5), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
				TweenService:Create(mobBtn, TweenInfo.new(0.5), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
				TweenService:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
				
				task.delay(0.5, function()
					deviceLayer:Destroy()
					GUI:Destroy()
					GUI = nil
					
					-- 3. Animate Real ClickGui (Premium Animation)
					if realClickGui then
						realClickGui.Position = UDim2.new(0, 0, 0, 0)
						realClickGui.Visible = true
						
						local delayCounter = 0
						for _, cat in pairs(vape.Categories) do
							local window = cat.Object
							if window then
								local originalPos = window.Position
								window.Position = originalPos + UDim2.fromOffset(0, 300)
								
								local tInfo = TweenInfo.new(1.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, 0, false, delayCounter)
								TweenService:Create(window, tInfo, {Position = originalPos}):Play()
								
								delayCounter = delayCounter + 0.06
							end
						end
						
						if vape.guiscale then
							local targetScale = vape.guiscale.Scale
							vape.guiscale.Scale = targetScale * 0.85
							TweenService:Create(vape.guiscale, TweenInfo.new(1.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Scale = targetScale}):Play()
						end
						
						task.spawn(function()
							task.wait(delayCounter + 0.5)
							runTour()
						end)
					end
				end)
			end
			
			pcBtn.MouseButton1Click:Connect(function() onDeviceSelected("PC") end)
			mobBtn.MouseButton1Click:Connect(function() onDeviceSelected("Mobile") end)
		end
	end

	TestModule = vape.Categories.Render:CreateModule({
		Name = 'Test',
		Function = function(callback)
			if callback then
				createUI()
			else
				if GUI then GUI:Destroy() GUI = nil end
				if connection then connection:Disconnect() connection = nil end
			end
		end
	})
end)
