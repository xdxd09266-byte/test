local DarkMode
local darkConn = {}
local saved = {}

local darkBg = Color3.fromHex('#141413')
local dimText = Color3.fromRGB(200, 200, 200)

local function isMidtone(r, g, b)
	local avg = (r + g + b) / 3
	return avg > 15 and avg < 200
end

local function darken(col)
	local r, g, b = col.R * 255, col.G * 255, col.B * 255
	local avg = (r + g + b) / 3
	local factor = avg / 255
	local reduced = math.max(0.35, factor * 0.6)
	return Color3.new(col.R * reduced, col.G * reduced, col.B * reduced)
end

local function applyTo(inst)
	for _, v in pairs(inst:GetDescendants()) do
		if v:IsA("Frame") and not v:IsA("TextBox") and v.BackgroundTransparency < 0.9 then
			local r, g, b = v.BackgroundColor3.R * 255, v.BackgroundColor3.G * 255, v.BackgroundColor3.B * 255
			if isMidtone(r, g, b) then
				if not saved[v] then saved[v] = {bg = v.BackgroundColor3, tr = v.BackgroundTransparency} end
				v.BackgroundColor3 = darkBg
				v.BackgroundTransparency = 0
			end
		end

		if (v:IsA("TextLabel") or v:IsA("TextButton")) and v.Text ~= "" then
			local r, g, b = v.TextColor3.R * 255, v.TextColor3.G * 255, v.TextColor3.B * 255
			if isMidtone(r, g, b) or (r + g + b) / 3 > 200 then
				if not saved[v] then saved[v] = {tc = v.TextColor3} end
				v.TextColor3 = dimText
			end
		end

		if v:IsA("ImageLabel") then
			if v.BackgroundTransparency < 0.9 then
				local r, g, b = v.BackgroundColor3.R * 255, v.BackgroundColor3.G * 255, v.BackgroundColor3.B * 255
				if isMidtone(r, g, b) then
					if not saved[v] then saved[v] = {bg = v.BackgroundColor3, tr = v.BackgroundTransparency} end
					v.BackgroundColor3 = darkBg
					v.BackgroundTransparency = 0
				end
			end
			local ir, ig, ib = v.ImageColor3.R * 255, v.ImageColor3.G * 255, v.ImageColor3.B * 255
			local iavg = (ir + ig + ib) / 3
			if iavg > 10 and iavg < 230 then
				if not saved[v] then saved[v] = {ic = v.ImageColor3} end
				if iavg < 50 then
					v.ImageColor3 = Color3.fromRGB(60, 60, 60)
				else
					v.ImageColor3 = darken(v.ImageColor3)
				end
			end
		end

		if v:IsA("ScrollingFrame") and v.BackgroundTransparency < 0.9 then
			local r, g, b = v.BackgroundColor3.R * 255, v.BackgroundColor3.G * 255, v.BackgroundColor3.B * 255
			if isMidtone(r, g, b) then
				if not saved[v] then saved[v] = {bg = v.BackgroundColor3, tr = v.BackgroundTransparency} end
				v.BackgroundColor3 = darkBg
				v.BackgroundTransparency = 0
			end
		end
	end
end

local function restore()
	for v, cols in pairs(saved) do
		if v and v.Parent then
			if cols.bg then pcall(function() v.BackgroundColor3 = cols.bg end) end
			if cols.tr then pcall(function() v.BackgroundTransparency = cols.tr end) end
			if cols.tc then pcall(function() v.TextColor3 = cols.tc end) end
			if cols.ic then pcall(function() v.ImageColor3 = cols.ic end) end
		end
	end
	table.clear(saved)
end

DarkMode = vape.Legit:CreateModule({
	Name = 'Dark Mode',
	Function = function(callback)
		if callback then
			for _, gui in pairs(lplr.PlayerGui:GetChildren()) do
				if gui:IsA("ScreenGui") and gui.Name ~= "SettingsAppGui" then applyTo(gui) end
			end
			darkConn[#darkConn + 1] = lplr.PlayerGui.ChildAdded:Connect(function(gui)
				if gui:IsA("ScreenGui") and gui.Name ~= "SettingsAppGui" then
					task.wait(0.2)
					applyTo(gui)
				end
			end)
			task.spawn(function()
				while DarkMode and DarkMode.Enabled do
					task.wait(1.5)
					for _, gui in pairs(lplr.PlayerGui:GetChildren()) do
						if gui:IsA("ScreenGui") and gui.Name ~= "SettingsAppGui" then applyTo(gui) end
					end
				end
			end)
		else
			for _, c in darkConn do
				pcall(function() c:Disconnect() end)
			end
			table.clear(darkConn)
			restore()
		end
	end,
	Tooltip = 'Changes BedWars HUD to dark mode (#141413)'
})
