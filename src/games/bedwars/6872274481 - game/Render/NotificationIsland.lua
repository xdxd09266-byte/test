run(function()
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")

	local Settings = {
		Width = 170,
		Height = 34,
		ExpandedWidth = 270,
		YPos = 12,
		Colors = {
			Background = Color3.fromRGB(0, 0, 0),
			Stroke = Color3.fromRGB(40, 40, 40),
			Success = Color3.fromRGB(48, 209, 88),
			Error = Color3.fromRGB(255, 69, 58)
		}
	}

	-- Dictionary tracking active modules: [ModuleName] = {Frame, Dot, Label, Scale, Thread}
	local ActiveNotifs = {} 
	local LayoutIndex = 0
	
	-- Snappy 1:1 Apple Easing
	local function AppleTween(inst, props, dur)
		local info = TweenInfo.new(dur or 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		local t = TweenService:Create(inst, info, props)
		t:Play()
		return t
	end

	local function GetNotifCount()
		local count = 0
		for _ in pairs(ActiveNotifs) do count += 1 end
		return count
	end

	local GUI = Instance.new("ScreenGui")
	GUI.Name = "DynamicIsland"; GUI.ResetOnSpawn = false; GUI.IgnoreGuiInset = true
	GUI.Parent = lplr:WaitForChild("PlayerGui")

	-- Main Container
	local Island = Instance.new("CanvasGroup")
	Island.Size = UDim2.new(0, Settings.Width, 0, Settings.Height)
	Island.Position = UDim2.new(0.5, -Settings.Width/2, 0, Settings.YPos)
	Island.BackgroundColor3 = Settings.Colors.Background
	Island.BorderSizePixel = 0
	Island.ClipsDescendants = true
	Island.Visible = false
	Island.Parent = GUI

	local Corner = Instance.new("UICorner"); Corner.CornerRadius = UDim.new(0, 100); Corner.Parent = Island
	local Stroke = Instance.new("UIStroke"); Stroke.Color = Settings.Colors.Stroke; Stroke.Thickness = 1; Stroke.Parent = Island

	-- COMPACT LAYER (Logo/Clock)
	local CompactLayer = Instance.new("Frame")
	CompactLayer.Size = UDim2.new(1, 0, 1, 0)
	CompactLayer.BackgroundTransparency = 1
	CompactLayer.Parent = Island

	local Logo = Instance.new("TextLabel")
	Logo.Size = UDim2.new(0, 60, 1, 0); Logo.Position = UDim2.new(0, 20, 0, 0)
	Logo.BackgroundTransparency = 1; Logo.Text = "VAPE"; Logo.TextColor3 = Color3.new(1,1,1)
	Logo.TextSize = 11; Logo.Font = Enum.Font.GothamBold; Logo.TextXAlignment = Enum.TextXAlignment.Left; Logo.Parent = CompactLayer

	local Clock = Instance.new("TextLabel")
	Clock.Size = UDim2.new(0, 60, 1, 0); Clock.Position = UDim2.new(1, -80, 0, 0)
	Clock.BackgroundTransparency = 1; Clock.Text = os.date("%H:%M"); Clock.TextColor3 = Color3.fromRGB(140, 140, 140)
	Clock.TextSize = 11; Clock.Font = Enum.Font.GothamBold; Clock.TextXAlignment = Enum.TextXAlignment.Right; Clock.Parent = CompactLayer

	-- NOTIFICATION LAYER
	local NotifLayer = Instance.new("Frame")
	NotifLayer.Size = UDim2.new(1, 0, 1, 0)
	NotifLayer.BackgroundTransparency = 1
	NotifLayer.Visible = false
	NotifLayer.Parent = Island

	-- UIPadding simulates the HTML 12px top/bottom padding
	local Padding = Instance.new("UIPadding")
	Padding.PaddingTop = UDim.new(0, 12); Padding.PaddingBottom = UDim.new(0, 12); Padding.Parent = NotifLayer

	local List = Instance.new("UIListLayout")
	List.Parent = NotifLayer; List.Padding = UDim.new(0, 6); List.HorizontalAlignment = Enum.HorizontalAlignment.Center
	List.SortOrder = Enum.SortOrder.LayoutOrder

	local function UpdateIsland()
		local count = GetNotifCount()
		
		if count > 0 then
			CompactLayer.Visible = false
			NotifLayer.Visible = true
			
			-- Calculate exact height required based on active rows
			local dynamicHeight = 24 + (count * 24) + (math.max(0, count - 1) * 6)
			
			AppleTween(Island, {
				Size = UDim2.new(0, Settings.ExpandedWidth, 0, dynamicHeight),
				Position = UDim2.new(0.5, -Settings.ExpandedWidth/2, 0, Settings.YPos)
			})
			AppleTween(Corner, {CornerRadius = UDim.new(0, 22)})
		else
			-- Shrink back to Compact mode
			AppleTween(Island, {
				Size = UDim2.new(0, Settings.Width, 0, Settings.Height),
				Position = UDim2.new(0.5, -Settings.Width/2, 0, Settings.YPos)
			})
			AppleTween(Corner, {CornerRadius = UDim.new(0, 100)})
			
			task.delay(0.3, function()
				if GetNotifCount() == 0 then 
					CompactLayer.Visible = true 
					NotifLayer.Visible = false
				end
			end)
		end
	end

	local function RemoveNotif(moduleName)
		local data = ActiveNotifs[moduleName]
		if not data then return end

		-- Untrack immediately so UpdateIsland shrinks the main CanvasGroup
		ActiveNotifs[moduleName] = nil
		UpdateIsland()

		-- Smoothly collapse the row inside the ListLayout
		AppleTween(data.Frame, {Size = UDim2.new(0.9, 0, 0, 0)}, 0.3)
		AppleTween(data.Label, {TextTransparency = 1}, 0.2)

		task.delay(0.3, function()
			if data.Frame then data.Frame:Destroy() end
		end)
	end

	function ShowNotif(moduleName, isEnabled)
		local statusColor = isEnabled and Settings.Colors.Success or Settings.Colors.Error
		local colorHex = isEnabled and "#30D158" or "#FF453A"
		local statusText = isEnabled and "Enabled" or "Disabled"
		local fullText = moduleName .. " <font color='" .. colorHex .. "'>" .. statusText .. "</font>"

		-- IF NOTIFICATION IS ALREADY VISIBLE (Morph Update)
		if ActiveNotifs[moduleName] then
			local data = ActiveNotifs[moduleName]
			
			-- Cancel the existing destruction thread to keep it alive
			if data.Thread then task.cancel(data.Thread) end

			-- 1. Tween Dot Color
			AppleTween(data.Dot, {BackgroundColor3 = statusColor}, 0.3)

			-- 2. Frame Pop Animation
			AppleTween(data.Scale, {Scale = 1.03}, 0.15).Completed:Connect(function()
				AppleTween(data.Scale, {Scale = 1}, 0.15)
			end)

			-- 3. Text Slide Fade out -> Change Text -> Slide Fade In
			AppleTween(data.Label, {TextTransparency = 1, Position = UDim2.new(0, 18, 0, -8)}, 0.15)
			task.delay(0.15, function()
				if not data.Label.Parent then return end
				data.Label.Text = fullText
				data.Label.Position = UDim2.new(0, 18, 0, 8) -- Prep slide in from bottom
				AppleTween(data.Label, {TextTransparency = 0, Position = UDim2.new(0, 18, 0, 0)}, 0.15)
			end)

			-- Restart death timer
			data.Thread = task.delay(3, function() RemoveNotif(moduleName) end)
			return
		end

		-- OTHERWISE, CREATE A NEW ROW
		LayoutIndex += 1

		local item = Instance.new("Frame")
		item.Size = UDim2.new(0.9, 0, 0, 24)
		item.BackgroundTransparency = 1
		item.ClipsDescendants = true -- Crucial for collapse animation
		item.LayoutOrder = LayoutIndex
		item.Parent = NotifLayer

		local scale = Instance.new("UIScale"); scale.Parent = item

		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 6, 0, 6); dot.Position = UDim2.new(0, 4, 0.5, -3)
		dot.BackgroundColor3 = statusColor
		dot.BorderSizePixel = 0; dot.Parent = item
		Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -20, 1, 0); lbl.Position = UDim2.new(0, 18, 0, 0)
		lbl.Text = fullText
		lbl.RichText = true; lbl.TextColor3 = Color3.new(1,1,1); lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 14; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = item

		-- Save references to the dictionary
		ActiveNotifs[moduleName] = {
			Frame = item,
			Dot = dot,
			Label = lbl,
			Scale = scale,
			Thread = task.delay(3, function() RemoveNotif(moduleName) end)
		}

		UpdateIsland()
	end

	-- Real-time Clock Update
	task.spawn(function()
		while task.wait(1) do Clock.Text = os.date("%H:%M") end
	end)

	NotificationIsland = vape.Categories.Render:CreateModule({
		Name = 'Notification Island',
		Function = function(callback)
			if callback then
				Island.Visible = true
				local old = vape.CreateNotification
				
				-- Override Vape's notification behavior
				vape.CreateNotification = function(_, title, text, dur, t)
					if title == 'Module Toggled' then
						local clean = text:gsub("<[^>]+>", "")
						local name = clean:match("(.+) has been ")
						local enabled = clean:find("Enabled")
						
						if name then 
							ShowNotif(name, enabled ~= nil) 
						end
						return
					end
					return old(_, title, text, dur, t)
				end
				
				NotificationIsland:Clean(function() 
					vape.CreateNotification = old
					Island.Visible = false 
					
					-- Clear active trackers on module disable
					for mod, _ in pairs(ActiveNotifs) do
						RemoveNotif(mod)
					end
				end)
			else
				Island.Visible = false
			end
		end
	})
end)