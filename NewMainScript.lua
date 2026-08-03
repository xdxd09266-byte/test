-- Safely get global functions, fallback to stubs if not available
local readfile
local success = pcall(function() readfile = readfile end)
if not success or type(readfile) ~= "function" then
	readfile = function() return "" end
end

local writefile
success = pcall(function() writefile = writefile end)
if not success or type(writefile) ~= "function" then
	writefile = function() end
end

local makefolder
success = pcall(function() makefolder = makefolder end)
if not success or type(makefolder) ~= "function" then
	makefolder = function() end
end

local isfolder
success = pcall(function() isfolder = isfolder end)
if not success or type(isfolder) ~= "function" then
	isfolder = function() return false end
end

local listfiles
success = pcall(function() listfiles = listfiles end)
if not success or type(listfiles) ~= "function" then
	listfiles = function() return {} end
end

local isfile
success = pcall(function() isfile = isfile end)
if not success or type(isfile) ~= "function" then
	isfile = function(file)
		local suc, res = pcall(function()
			return readfile(file)
		end)
		return suc and res ~= nil and res ~= ''
	end
end

local delfile
success = pcall(function() delfile = delfile end)
if not success or type(delfile) ~= "function" then
	delfile = function(file)
		writefile(file, '')
	end
end

local function downloadFile(path, func)
	if not isfile(path) then
		local targetPath = tostring(path):gsub('^weedhack/', '')
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/xdxd09266-byte/test/main/'..targetPath..'?t='..tostring(os.time()), true)
		end)
		if not suc or type(res) ~= 'string' or res:match('^%d%d%d:') then
			return nil
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if file:find('owner') then continue end
		if isfile(file) then delfile(file) else wipeFolder(file) end
	end
end

for _, folder in {'weedhack', 'weedhack/games', 'weedhack/profiles', 'weedhack/assets', 'weedhack/libraries', 'weedhack/guis'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

local function ezLog(msg)
	print('[ezvape] ' .. tostring(msg))
	pcall(function()
		local rf = readfile or function() return '' end
		local wf = writefile or function() end
		local old = ''
		pcall(function() old = rf('weedhack/debug.log') or '' end)
		if type(old) ~= 'string' then old = '' end
		if #old > 20000 then old = old:sub(-15000) end
		wf('weedhack/debug.log', old .. '\n[' .. tostring(os.time()) .. '] ' .. msg)
	end)
end

local function ezError(msg)
	warn('[ezvape Error] ' .. tostring(msg))
	ezLog('[ERROR] ' .. tostring(msg))
end

local function ezSuccess(msg)
	ezLog(msg)
end

local ezStatus = {}
-- ============================================================
-- SECURE SHA-256 KEY AUTH SYSTEM & DISCORD ANALYTICS WEBHOOK
-- ============================================================
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local WEBHOOK_URL = ""
if isfile and isfile('weedhack/profiles/secrets_config.lua') then
	local suc, res = pcall(function()
		return HttpService:JSONDecode(readfile('weedhack/profiles/secrets_config.lua'))
	end)
	if suc and type(res) == 'table' and res.WEBHOOK_URL then
		WEBHOOK_URL = res.WEBHOOK_URL
	end
end

local function getExecutorName()
	local exec = (identifyexecutor and identifyexecutor()) or (getexecutorname and getexecutorname()) or (getgenv and getgenv().Krnl and "KRNL") or (getgenv and getgenv().Synapse and "Synapse X")
	if type(exec) == "table" then
		return tostring(exec[1] or "Unknown Executor")
	end
	return tostring(exec or "Unknown Executor")
end

local function sendAnalyticsWebhook(matchedKeyInfo, inputKey)
	if WEBHOOK_URL == "" then return end
	pcall(function()
		local getG = getgenv and getgenv() or _G
		local reqFunc = (getG.syn and getG.syn.request) or (getG.http and getG.http.request) or http_request or (getG.fluxus and getG.fluxus.request) or request
		if not reqFunc then return end

		local player = Players.LocalPlayer
		local username = player and player.Name or "Unknown Player"
		local userId = player and player.UserId or 0
		local executorName = getExecutorName()
		local placeId = tostring(game.PlaceId)
		local note = (matchedKeyInfo and matchedKeyInfo.note) or "N/A"
		local discordUser = (matchedKeyInfo and matchedKeyInfo.discord) or "N/A"

		local embedData = {
			["title"] = "ðŸš€ ezvape Execution & Key Analytics",
			["color"] = 7506394, -- Discord Blurple
			["fields"] = {
				{ ["name"] = "ðŸ‘¤ Roblox Player", ["value"] = username .. " (" .. tostring(userId) .. ")", ["inline"] = true },
				{ ["name"] = "âš¡ Executor", ["value"] = executorName, ["inline"] = true },
				{ ["name"] = "ðŸŽ® Place ID", ["value"] = placeId, ["inline"] = true },
				{ ["name"] = "ðŸ”‘ Key Note / User", ["value"] = note, ["inline"] = true },
				{ ["name"] = "ðŸ’¬ Discord Tag", ["value"] = discordUser ~= "" and discordUser or "N/A", ["inline"] = true },
				{ ["name"] = "ðŸ”‘ Entered Key", ["value"] = "`" .. tostring(inputKey):sub(1, 14) .. "...`", ["inline"] = true }
			},
			["footer"] = { ["text"] = "ezvape Security & Telemetry System" },
			["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
		}

		local payload = HttpService:JSONEncode({
			["username"] = "ezvape Security Logger",
			["embeds"] = { embedData }
		})

		reqFunc({
			Url = WEBHOOK_URL,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = payload
		})
	end)
end

local function sha256(str)
	local bit = bit32 or (getgenv and getgenv().bit)
	local band, bor, bxor, bnot = bit.band, bit.bor, bit.bxor, bit.bnot
	local rshift, lshift = bit.rshift, bit.lshift
	local rrotate = bit.rrotate or function(w, r)
		return bor(rshift(w, r), lshift(w, 32 - r))
	end

	local K = {
		0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
		0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
		0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
		0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
		0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
		0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
		0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
		0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
	}
	local H = {
		0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
	}

	local bytes = {str:byte(1, #str)}
	local len = #bytes * 8
	table.insert(bytes, 0x80)
	while (#bytes % 64) ~= 56 do
		table.insert(bytes, 0x00)
	end
	for i = 7, 0, -1 do
		table.insert(bytes, band(rshift(len, i * 8), 0xFF))
	end

	local W = {}
	for chunk = 1, #bytes, 64 do
		for i = 0, 15 do
			W[i + 1] = bor(
				lshift(bytes[chunk + i * 4], 24),
				lshift(bytes[chunk + i * 4 + 1], 16),
				lshift(bytes[chunk + i * 4 + 2], 8),
				bytes[chunk + i * 4 + 3]
			)
		end
		for i = 16, 63 do
			local s0 = bxor(rrotate(W[i - 15 + 1], 7), rrotate(W[i - 15 + 1], 18), rshift(W[i - 15 + 1], 3))
			local s1 = bxor(rrotate(W[i - 2 + 1], 17), rrotate(W[i - 2 + 1], 19), rshift(W[i - 2 + 1], 10))
			W[i + 1] = band(W[i - 16 + 1] + s0 + W[i - 7 + 1] + s1, 0xFFFFFFFF)
		end

		local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
		for i = 0, 63 do
			local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
			local ch = bxor(band(e, f), band(bnot(e), g))
			local temp1 = band(h + S1 + ch + K[i + 1] + W[i + 1], 0xFFFFFFFF)
			local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
			local maj = bxor(band(a, b), band(a, c), band(b, c))
			local temp2 = band(S0 + maj, 0xFFFFFFFF)

			h = g
			g = f
			f = e
			e = band(d + temp1, 0xFFFFFFFF)
			d = c
			c = b
			b = a
			a = band(temp1 + temp2, 0xFFFFFFFF)
		end

		H[1] = band(H[1] + a, 0xFFFFFFFF)
		H[2] = band(H[2] + b, 0xFFFFFFFF)
		H[3] = band(H[3] + c, 0xFFFFFFFF)
		H[4] = band(H[4] + d, 0xFFFFFFFF)
		H[5] = band(H[5] + e, 0xFFFFFFFF)
		H[6] = band(H[6] + f, 0xFFFFFFFF)
		H[7] = band(H[7] + g, 0xFFFFFFFF)
		H[8] = band(H[8] + h, 0xFFFFFFFF)
	end

	return string.format("%08x%08x%08x%08x%08x%08x%08x%08x", H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8])
end

local function fetchKeys()
	if isfile and isfile('weedhack/keys.json') then
		local localSuc, localData = pcall(function()
			return HttpService:JSONDecode(readfile('weedhack/keys.json'))
		end)
		if localSuc and localData and localData.keys then
			return localData.keys
		end
	end
	local suc, res = pcall(function()
		return game:HttpGet('https://raw.githubusercontent.com/xdxd09266-byte/test/main/keys.json?t='..tostring(os.time()), true)
	end)
	if suc and res and not res:match('^%d%d%d:') then
		local jsonSuc, data = pcall(function()
			return HttpService:JSONDecode(res)
		end)
		if jsonSuc and data and data.keys then
			return data.keys
		end
	end
	return nil
end

local function validateKey(enteredKey, keyList)
	if not enteredKey or enteredKey == "" or not keyList then return false, "Invalid parameters", nil end
	local inputHash = sha256(enteredKey)
	local currentTime = os.time()
	for _, k in ipairs(keyList) do
		if k.hash == inputHash or k.key == enteredKey then
			if k.active == false then
				return false, "Key has been revoked!", k
			end
			if k.expires and tonumber(k.expires) and currentTime > tonumber(k.expires) then
				return false, "Key has expired!", k
			end
			return true, "Success", k
		end
	end
	return false, "Invalid Key", nil
end

local function authenticateUser()
	local keyList = fetchKeys()
	if not keyList then
		print("[ezvape Auth] Warning: Unable to fetch key database.")
	end

	local savedKey = isfile("weedhack/profiles/key.txt") and readfile("weedhack/profiles/key.txt"):gsub("%s+", "") or ""

	if savedKey ~= "" and keyList then
		local valid, msg, keyInfo = validateKey(savedKey, keyList)
		if valid then
			print("[ezvape Auth] Key verified automatically!")
			task.spawn(function()
				sendAnalyticsWebhook(keyInfo, savedKey)
			end)
			return true
		else
			print("[ezvape Auth] Saved key invalid: " .. tostring(msg))
		end
	end

	-- Load Rayfield Gen2 UI library
	local preRayfieldGuis = {}
	pcall(function()
		for _, child in ipairs(game:GetService('CoreGui'):GetChildren()) do
			preRayfieldGuis[child] = true
		end
		local player = game:GetService('Players').LocalPlayer
		if player then
			local playerGui = player:FindFirstChild('PlayerGui')
			if playerGui then
				for _, child in ipairs(playerGui:GetChildren()) do
					preRayfieldGuis[child] = true
				end
			end
		end
	end)
	local RayfieldSuc, Rayfield = pcall(function()
		return loadstring(game:HttpGet("https://sirius.menu/gen2"))()
	end)
	if not RayfieldSuc or not Rayfield then
		error("Failed to load Rayfield Gen2 UI library. Check your internet connection.")
	end
	
	-- Detect mobile and use simpler approach if needed
	local isMobile = game:GetService("UserInputService").TouchEnabled
	
	local Window
	local WindowSuc, WindowErr = pcall(function()
		return Rayfield:CreateWindow({
			name = "ezvape Authentication",
			subtitle = "by xdxd09266-byte"
		})
	end)
	
	if not WindowSuc then
		-- Fallback for mobile or if Rayfield window creation fails
		warn("[ezvape] Rayfield window creation failed: " .. tostring(WindowErr))
		if isMobile then
			warn("[ezvape] Mobile detected - using simple input fallback")
			-- Simple fallback: prompt user via console or simple GUI

			
			local key = ""
			-- Use a simple InputBox if available, otherwise use console
			local screenGui = Instance.new("ScreenGui")
			screenGui.Parent = game:GetService("CoreGui")
			
			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(0.5, 0, 0.3, 0)
			frame.Position = UDim2.new(0.25, 0, 0.35, 0)
			frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			frame.Parent = screenGui
			
			local textBox = Instance.new("TextBox")
		 textBox.Size = UDim2.new(0.8, 0, 0.3, 0)
			textBox.Position = UDim2.new(0.1, 0, 0.2, 0)
			textBox.PlaceholderText = "Enter your key"
			textBox.Text = ""
			textBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
			textBox.Parent = frame
			
			local submitButton = Instance.new("TextButton")
			submitButton.Size = UDim2.new(0.4, 0, 0.2, 0)
			submitButton.Position = UDim2.new(0.3, 0, 0.6, 0)
			submitButton.Text = "Submit"
			submitButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
			submitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			submitButton.Parent = frame
			
			local statusLabel = Instance.new("TextLabel")
			statusLabel.Size = UDim2.new(0.8, 0, 0.2, 0)
			statusLabel.Position = UDim2.new(0.1, 0, 0.8, 0)
			statusLabel.Text = "Enter your key to continue"
			statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			statusLabel.BackgroundTransparency = 1
			statusLabel.Parent = frame
			
			local authenticated = false
			
			submitButton.MouseButton1Click:Connect(function()
				key = textBox.Text:gsub("%s+", "")
				statusLabel.Text = "Verifying..."
				
				keyList = fetchKeys() or keyList
				local valid, msg, keyInfo = validateKey(key, keyList)
				
				if valid then
					statusLabel.Text = "[+] Success!"
					writefile("weedhack/profiles/key.txt", key)
					
					task.spawn(function()
						sendAnalyticsWebhook(keyInfo, key)
					end)
					
					task.wait(0.5)
					screenGui:Destroy()
					authenticated = true
				else
					statusLabel.Text = "[-] " .. tostring(msg)
				end
			end)
			
			repeat task.wait() until authenticated
			return authenticated
		else
			error("Rayfield window creation failed: " .. tostring(WindowErr))
		end
	end
	
	Window = WindowErr

	local authenticated = false
	local currentKeyInput = savedKey or ""

	local Tab = Window:CreateTab({
		name = "Authentication"
	})

	local keyInput = Tab:CreateInput({
		name = "Enter Key",
		value = savedKey ~= "" and savedKey or "",
		placeholder = "ezvape-XXXX-XXXX-XXXX",
		flag = "ezvape_key_input",
		callback = function(Text)
			currentKeyInput = Text:gsub("%s+", "")
		end
	})

	local function verify()
		local keyToVerify = currentKeyInput
		if keyToVerify == "" then
			keyToVerify = savedKey
		end

		if not keyToVerify or keyToVerify == "" then
			Window:Notify({
				title = "Error",
				content = "[-] Please enter your key!",
				duration = 3
			})
			return
		end
        
		Window:Notify({
			title = "Verifying",
			content = "[-] Verifying...",
			duration = 2
		})
		
		keyList = fetchKeys() or keyList
		local valid, msg, keyInfo = validateKey(keyToVerify, keyList)
		
		if valid then
			Window:Notify({
				title = "Success",
				content = "[+] Access Granted! Loading...",
				duration = 2
			})
			writefile("weedhack/profiles/key.txt", keyToVerify)
			
			task.spawn(function()
				sendAnalyticsWebhook(keyInfo, keyToVerify)
			end)
			
			task.wait(0.5)
			authenticated = true
			task.spawn(function()
				task.wait(1)
				pcall(function()
					if Rayfield and type(Rayfield.Destroy) == "function" then
						pcall(function() Rayfield:Destroy() end)
					end
					local destroyed = 0
					local function cleanGuis(parent)
						if not parent then return end
						for _, child in ipairs(parent:GetChildren()) do
							if child:IsA('ScreenGui') and (child.Name:lower():find('rayfield') or child.Name == "Sirius") and not preRayfieldGuis[child] then
								child:Destroy()
								destroyed = destroyed + 1
							end
						end
					end
					cleanGuis(game:GetService('CoreGui'))
					local player = game:GetService('Players').LocalPlayer
					if player and player:FindFirstChild('PlayerGui') then
						cleanGuis(player.PlayerGui)
					end
					print('[ezvape] rayfield cleanup: destroyed ' .. tostring(destroyed) .. ' leftover screen guis')
				end)
			end)
		else
			Window:Notify({
				title = "Error",
				content = "[-] " .. tostring(msg),
				duration = 5
			})
		end
	end

	Tab:CreateButton({
		name = "Verify & Unlock",
		callback = verify
	})

	Tab:CreateButton({
		name = "Reset Key",
		callback = function()
			if isfile("weedhack/profiles/key.txt") then
				delfile("weedhack/profiles/key.txt")
			end
			savedKey = ""
			currentKeyInput = ""
			keyInput:Set("", true)
			Window:Notify({
				title = "Success",
				content = "[+] Key cleared! Please enter a new key.",
				duration = 3
			})
		end
	})

	repeat task.wait() until authenticated
	return authenticated
end

-- Run key authentication check
print('[ezvape] running authentication...')
local authSuccess = authenticateUser()
print('[ezvape] authenticateUser returned: ' .. tostring(authSuccess))
if not authSuccess then
	ezError('[ezvape Auth] Authentication failed.')
	return
end

-- Proceed with standard loading
if not shared.VapeDeveloper and not isfile('weedhack/profiles/local.txt') then
	local _, subbed = pcall(function()
		return game:HttpGet('https://github.com/xdxd09266-byte/test')
	end)
	local commit = nil
	if type(subbed) == 'string' and not subbed:match('^%d%d%d:') then
		local idx = subbed:find('currentOid')
		if idx then
			local candidate = subbed:sub(idx + 13, idx + 52)
			if #candidate == 40 then commit = candidate end
		end
	end
	-- Only wipe when the repo is actually reachable (private/offline repos return 403/404 -> no wipe)
	if commit and commit ~= (isfile('weedhack/profiles/commit.txt') and readfile('weedhack/profiles/commit.txt') or '') then
		wipeFolder('weedhack')
		wipeFolder('weedhack/games')
		wipeFolder('weedhack/guis')
		wipeFolder('weedhack/libraries')
		-- Preserve assets folder - don't wipe it
		if not isfolder('weedhack/assets') then
			makefolder('weedhack/assets')
		end
	end
	if commit then
		writefile('weedhack/profiles/commit.txt', commit)
	end
end

-- Safely download and execute loader.lua
ezLog('inject: auth passed, downloading loader.lua')
local mainScriptSource = downloadFile('loader.lua') -- Download to workspace root
if not mainScriptSource then
    -- Try fetching directly if downloadFile failed (e.g., path mismatch)
    local suc, res = pcall(function()
        return game:HttpGet('https://raw.githubusercontent.com/xdxd09266-byte/test/main/loader.lua?t='..tostring(os.time()), true)
    end)
    if suc and type(res) == 'string' and not res:match('^%d%d%d:') then
        mainScriptSource = res
    end
end

if mainScriptSource then
	local mainFunc, err = loadstring(mainScriptSource, "loader")
	if type(mainFunc) == "function" then
		ezLog('inject: loader.lua compiled, executing')
		local success, runtimeErr = pcall(mainFunc)
		if not success then
			ezError('loader.lua crashed:\n' .. tostring(runtimeErr))
		else
			ezLog('inject: loader.lua finished without error')
			ezSuccess('ezvape loader finished.\nIf no menu appeared: press the button in the TOP RIGHT (mobile) or RightShift (PC).')
		end
	else
		ezError('Syntax error in loader.lua:\n' .. tostring(err))
	end
else
	ezError('Failed to download loader.lua (network blocked?)')
end

