run(function()
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")

	local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	
	local Settings = {
		Width = 170,
		Height = 34,
		ExpandedWidth = 270,
		YPos = 12,
		Colors = {
			Background = Color3.fromRGB(0, 0, 0),
			Stroke = Color3.fromRGB(40, 40, 40),
			Success = Color3.fromRGB(48, 209, 88), -- Permanent Apple Green
			Error = Color3.fromRGB(255, 69, 58)    -- Permanent Apple Red
		}
	}

	local ActiveNotifs = {}
	
	-- Snappy 1:1 Apple Easing
	local function AppleTween(inst, props, dur)
		local info = TweenInfo.new(dur or 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		local t = TweenService:Create(inst, info, props)
		t:Play()
		return t
	end

	local GUI = Instance.new("ScreenGui")
	GUI.Name = "DynamicIsland"; GUI.ResetOnSpawn = false; GUI.IgnoreGuiInset = true
	GUI.Parent = lplr:WaitForChild("PlayerGui")

	-- Main Container (CanvasGroup for perfect fading)
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

	local List = Instance.new("UIListLayout")
	List.Parent = NotifLayer; List.Padding = UDim.new(0, 6); List.HorizontalAlignment = Enum.HorizontalAlignment.Center; List.VerticalAlignment = Enum.VerticalAlignment.Center
	List.SortOrder = Enum.SortOrder.LayoutOrder

	local function UpdateIsland()
		local count = #ActiveNotifs
		
		if count > 0 then
			CompactLayer.Visible = false
			NotifLayer.Visible = true
			
			-- Snappy Expansion Animation
			AppleTween(Island, {
				Size = UDim2.new(0, Settings.ExpandedWidth, 0, 38 + (count * 10)),
				Position = UDim2.new(0.5, -Settings.ExpandedWidth/2, 0, Settings.YPos)
			})
			AppleTween(Corner, {CornerRadius = UDim.new(0, 22)})
		else
			NotifLayer.Visible = false
			AppleTween(Island, {
				Size = UDim2.new(0, Settings.Width, 0, Settings.Height),
				Position = UDim2.new(0.5, -Settings.Width/2, 0, Settings.YPos)
			})
			AppleTween(Corner, {CornerRadius = UDim.new(0, 100)})
			
			task.delay(0.3, function()
				if #ActiveNotifs == 0 then CompactLayer.Visible = true end
			end)
		end
	end

	function ShowNotif(text, isEnabled)
		-- Create the item
		local item = Instance.new("Frame")
		item.Size = UDim2.new(0.9, 0, 0, 24)
		item.BackgroundTransparency = 1
		item.Parent = NotifLayer

		-- Determine Permanent Color
		local statusColor = isEnabled and Settings.Colors.Success or Settings.Colors.Error
		local colorHex = isEnabled and "#30D158" or "#FF453A"
-- Permanent Status Dot
local dot = Instance.new("Frame")
dot.Size = UDim2.new(0, 6, 0, 6); dot.Position = UDim2.new(0, 4, 0.5, -3)
dot.BackgroundColor3 = statusColor
dot.BorderSizePixel = 0; dot.Parent = item
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

local lockConn
lockConn = dot:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
	if dot.BackgroundColor3 ~= statusColor then
		dot.BackgroundColor3 = statusColor
	end
end)
dot.AncestryChanged:Connect(function(_, parent)
	if not parent and lockConn then
		lockConn:Disconnect()
	end
end)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -20, 1, 0); lbl.Position = UDim2.new(0, 18, 0, 0)
		lbl.Text = text .. " <font color='" .. colorHex .. "'>" .. (isEnabled and "Enabled" or "Disabled") .. "</font>"
		lbl.RichText = true; lbl.TextColor3 = Color3.new(1,1,1); lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 14; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = item

		table.insert(ActiveNotifs, item)
		UpdateIsland()

		-- CLEANUP LOGIC (Prevents "Staying Forever")
		task.delay(3, function()
			-- Remove from table first
			for i, v in ipairs(ActiveNotifs) do
				if v == item then
					table.remove(ActiveNotifs, i)
					break
				end
			end
			
			-- Animate out and destroy
			local out = AppleTween(item, {Position = UDim2.new(0, 0, 0, -20)}, 0.3)
			out.Completed:Wait()
			item:Destroy()
			UpdateIsland()
		end)
	end

	task.spawn(function()
		while task.wait(1) do Clock.Text = os.date("%H:%M") end
	end)

	NotificationIsland = vape.Categories.Render:CreateModule({
		Name = 'Notification Island',
		Function = function(callback)
			if callback then
				Island.Visible = true
				local old = vape.CreateNotification
				vape.CreateNotification = function(_, title, text, dur, t)
					if title == 'Module Toggled' then
						local clean = text:gsub("<[^>]+>", "")
						local name = clean:match("(.+) has been ")
						local enabled = clean:find("Enabled")
						if name then ShowNotif(name, enabled) end
						return
					end
					return old(_, title, text, dur, t)
				end
				NotificationIsland:Clean(function() 
					vape.CreateNotification = old
					Island.Visible = false 
				end)
			else
				Island.Visible = false
			end
		end
	})
end)