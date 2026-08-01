local UICleanup
local OpenInv
local KillFeed
local OldTabList
local noHotbarNumsConn, resizeHealthConn
local HotbarOpenInventory = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
local oldkillfeed

UICleanup = vape.Legit:CreateModule({
	Name = 'UI Cleanup',
	Function = function(callback)
		if callback then
			if OpenInv.Enabled then
				oldinvrender = HotbarOpenInventory.render
				HotbarOpenInventory.render = function()
					return bedwars.Roact.createElement('TextButton', {Visible = false}, {})
				end
			end

			if KillFeed.Enabled then
				oldkillfeed = bedwars.KillFeedController.addToKillFeed
				bedwars.KillFeedController.addToKillFeed = function() end
			end

			if OldTabList.Enabled then
				starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
			end
		else
			if oldinvrender then
				HotbarOpenInventory.render = oldinvrender
				oldinvrender = nil
			end

			if KillFeed.Enabled then
				bedwars.KillFeedController.addToKillFeed = oldkillfeed
				oldkillfeed = nil
			end

			if OldTabList.Enabled then
				starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			end
		end
	end,
	Tooltip = 'Cleans up the UI for kits & main'
})
UICleanup:CreateToggle({
	Name = 'No Hotbar Numbers',
	Function = function(callback)
		if callback then
			noHotbarNumsConn = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui").ChildAdded:Connect(function(inst)
				if inst.Name:find("hotbar") or inst.Name:find("Hotbar") then
					task.spawn(function()
						task.wait(0.5)
						for _, label in pairs(inst:GetDescendants()) do
							if label:IsA("TextLabel") and label.Text:match("^[1-9]$") then
								label:GetPropertyChangedSignal("Text"):Connect(function()
									if label.Text:match("^[1-9]$") then label.Text = "" end
								end)
								if label.Text:match("^[1-9]$") then label.Text = "" end
							end
						end
					end)
				end
			end)
			task.wait(0.5)
			for _, inst in pairs(lplr.PlayerGui:GetChildren()) do
				if inst.Name:find("hotbar") or inst.Name:find("Hotbar") then
					for _, label in pairs(inst:GetDescendants()) do
						if label:IsA("TextLabel") and label.Text:match("^[1-9]$") then
							label.Text = ""
						end
					end
				end
			end
		elseif noHotbarNumsConn then
			noHotbarNumsConn:Disconnect()
			noHotbarNumsConn = nil
		end
	end,
	Default = true
})
UICleanup:CreateToggle({
	Name = 'Resize Health',
	Function = function(callback)
		if callback then
			resizeHealthConn = lplr.PlayerGui.ChildAdded:Connect(function(inst)
				if inst.Name:find("health") or inst.Name:find("Health") or inst.Name:find("hotbar") or inst.Name:find("Hotbar") then
					task.spawn(function()
						task.wait(0.5)
						for _, label in pairs(inst:GetDescendants()) do
							if label:IsA("TextLabel") and label.Text:match("^%d+$") and label.Text:len() <= 4 then
								label.TextSize = label.TextSize + 2
							end
						end
					end)
				end
			end)
			task.wait(0.5)
			for _, inst in pairs(lplr.PlayerGui:GetChildren()) do
				if inst.Name:find("health") or inst.Name:find("Health") or inst.Name:find("hotbar") or inst.Name:find("Hotbar") then
					for _, label in pairs(inst:GetDescendants()) do
						if label:IsA("TextLabel") and label.Text:match("^%d+$") and label.Text:len() <= 4 then
							label.TextSize = label.TextSize + 2
						end
					end
				end
			end
		elseif resizeHealthConn then
			resizeHealthConn:Disconnect()
			resizeHealthConn = nil
		end
	end,
	Default = true
})
OpenInv = UICleanup:CreateToggle({
	Name = 'No Inventory Button',
	Function = function(callback)
		if UICleanup.Enabled then
			if callback then
				oldinvrender = HotbarOpenInventory.render
				HotbarOpenInventory.render = function()
					return bedwars.Roact.createElement('TextButton', {Visible = false}, {})
				end
			else
				HotbarOpenInventory.render = oldinvrender
				oldinvrender = nil
			end
		end
	end,
	Default = true
})
KillFeed = UICleanup:CreateToggle({
	Name = 'No Kill Feed',
	Function = function(callback)
		if UICleanup.Enabled then
			if callback then
				oldkillfeed = bedwars.KillFeedController.addToKillFeed
				bedwars.KillFeedController.addToKillFeed = function() end
			else
				bedwars.KillFeedController.addToKillFeed = oldkillfeed
				oldkillfeed = nil
			end
		end
	end,
	Default = true
})
OldTabList = UICleanup:CreateToggle({
	Name = 'Old Player List',
	Function = function(callback)
		if UICleanup.Enabled then
			starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, callback)
		end
	end,
	Default = true
})
UICleanup:CreateToggle({
	Name = 'Fix Queue Card',
	Function = function(callback)
		if callback then
			bedwars.QueueCard.render = function()
				return bedwars.Roact.createElement('Frame', {Visible = false, Size = UDim2.new(0, 0, 0, 0)}, {})
			end
		end
	end,
	Default = true
})