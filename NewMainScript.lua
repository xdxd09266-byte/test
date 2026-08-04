-- Safely get global functions, fallback to stubs if not available
local readfile = readfile or function() return "" end
local writefile = writefile or function() end
local makefolder = makefolder or function() end
local isfolder = isfolder or function() return false end
local listfiles = listfiles or function() return {} end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file)
	writefile(file, '')
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
	pcall(function()
		for _, child in ipairs(game:GetService('CoreGui'):GetChildren()) do
			if child:IsA('ScreenGui') and child.Name == 'ezvapeAuth' then
				child:Destroy()
			end
		end
	end)
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
			pcall(function()
				for _, child in ipairs(game:GetService('CoreGui'):GetChildren()) do
					if child:IsA('ScreenGui') and child.Name == 'ezvapeAuth' then
						child:Destroy()
					end
				end
			end)
			return true
		else
			print("[ezvape Auth] Saved key invalid: " .. tostring(msg))
		end
	end

	-- Self-contained auth UI (no external UI library required)
	local authenticated = false
	local authKey = savedKey or ""

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ezvapeAuth"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = game:GetService("CoreGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 340, 0, 190)
	frame.Position = UDim2.new(0.5, -170, 0.5, -95)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 32)
	title.Text = "ezvape Authentication"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.BackgroundTransparency = 1
	title.Parent = frame

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, 0, 0, 20)
	sub.Position = UDim2.new(0, 0, 0, 32)
	sub.Text = "by xdxd09266-byte"
	sub.TextColor3 = Color3.fromRGB(150, 150, 160)
	sub.TextSize = 12
	sub.BackgroundTransparency = 1
	sub.Parent = frame

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.9, 0, 0, 34)
	box.Position = UDim2.new(0.05, 0, 0, 64)
	box.PlaceholderText = "Enter your key"
	box.Text = savedKey
	box.TextColor3 = Color3.fromRGB(255, 255, 255)
	box.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
	box.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
	box.BorderSizePixel = 0
	box.TextSize = 14
	box.ClearTextOnFocus = false
	box.Parent = frame

	local realKey = savedKey or ""
	local MASK = "•"
	local function dotCount(s)
		local n = 0
		for _ in s:gmatch("•") do n = n + 1 end
		return n
	end
	local function stripDots(s)
		return (s:gsub("•", ""))
	end
	local function dots(n)
		return string.rep(MASK, n)
	end
	local function refreshMask()
		box.Text = dots(#realKey)
		box.CursorPosition = #realKey + 1
	end
	refreshMask()
	task.spawn(function()
		local rs = game:GetService("RunService")
		while screenGui.Parent do
			rs.RenderStepped:Wait()
			local shown = box.Text
			local shownDots = dotCount(shown)
			local shownReal = stripDots(shown)
			local curLen = #realKey
			if not (shownDots == curLen and shownReal == "") then
				if shownDots < curLen then
					realKey = realKey:sub(1, shownDots)
				end
				if shownReal ~= "" then
					if shownDots == curLen then
						realKey = realKey .. shownReal
					else
						realKey = shownReal
					end
				end
				refreshMask()
			end
		end
	end)

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(0.9, 0, 0, 22)
	status.Position = UDim2.new(0.05, 0, 0, 102)
	status.Text = ""
	status.TextColor3 = Color3.fromRGB(200, 200, 210)
	status.TextSize = 13
	status.BackgroundTransparency = 1
	status.Parent = frame

	local verifyBtn = Instance.new("TextButton")
	verifyBtn.Size = UDim2.new(0.44, 0, 0, 36)
	verifyBtn.Position = UDim2.new(0.05, 0, 0, 130)
	verifyBtn.Text = "Redeem Key"
	verifyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	verifyBtn.BackgroundColor3 = Color3.fromRGB(45, 130, 60)
	verifyBtn.BorderSizePixel = 0
	verifyBtn.TextSize = 14
	verifyBtn.Font = Enum.Font.GothamBold
	verifyBtn.Parent = frame

	local resetBtn = Instance.new("TextButton")
	resetBtn.Size = UDim2.new(0.44, 0, 0, 36)
	resetBtn.Position = UDim2.new(0.51, 0, 0, 130)
	resetBtn.Text = "Reset Key"
	resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	resetBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
	resetBtn.BorderSizePixel = 0
	resetBtn.TextSize = 14
	resetBtn.Font = Enum.Font.GothamBold
	resetBtn.Parent = frame

	local function cleanupAuthGuis()
		pcall(function() screenGui:Destroy() end)
		pcall(function()
			for _, child in ipairs(game:GetService('CoreGui'):GetChildren()) do
				if child:IsA('ScreenGui') and (child.Name:lower():find('rayfield') or child.Name:lower():find('sirius')) then
					pcall(function() child:Destroy() end)
				end
			end
		end)
		pcall(function()
			local robloxGui = game:GetService('CoreGui'):FindFirstChild('RobloxGui')
			if robloxGui then
				for _, layer in ipairs(robloxGui:GetChildren()) do
					if layer:IsA('ScreenGui') then
						for _, win in ipairs(layer:GetChildren()) do
							if win:IsA('ScreenGui') and win.Name:lower():find('ezvape') then
								pcall(function() win:Destroy() end)
							end
						end
					end
				end
			end
		end)
	end

	local verifying = false
	local function verify()
		if verifying then return end
		verifying = true
		local keyToVerify = realKey:gsub("%s+", "")
		if keyToVerify == "" then keyToVerify = savedKey end
		if not keyToVerify or keyToVerify == "" then
			status.Text = "[-] Please enter your key!"
			status.TextColor3 = Color3.fromRGB(255, 120, 120)
			return
		end
		status.Text = "[i] Verifying..."
		status.TextColor3 = Color3.fromRGB(200, 200, 210)
		local fetched = fetchKeys() or keyList
		local valid, msg, keyInfo = validateKey(keyToVerify, fetched)
		if valid then
			status.Text = "[+] Access Granted! Loading..."
			status.TextColor3 = Color3.fromRGB(120, 255, 140)
			pcall(function() writefile("weedhack/profiles/key.txt", keyToVerify) end)
			task.spawn(function()
				sendAnalyticsWebhook(keyInfo, keyToVerify)
			end)
			task.wait(0.6)
			authenticated = true
			cleanupAuthGuis()
		else
			status.Text = "[-] " .. tostring(msg)
			status.TextColor3 = Color3.fromRGB(255, 120, 120)
		end
		verifying = false
	end

	verifyBtn.MouseButton1Click:Connect(verify)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then verify() end
	end)
	local uis = game:GetService("UserInputService")
	uis.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.Return then
			verify()
		end
	end)
	resetBtn.MouseButton1Click:Connect(function()
		pcall(function()
			if isfile("weedhack/profiles/key.txt") then delfile("weedhack/profiles/key.txt") end
		end)
		savedKey = ""
		realKey = ""
		box.Text = ""
		status.Text = "[i] Key cleared! Enter a new key."
		status.TextColor3 = Color3.fromRGB(200, 200, 210)
	end)

	repeat task.wait() until authenticated
	pcall(function() screenGui:Destroy() end)
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
	local commit = nil
	local apiSuc, apiRes = pcall(function()
		return game:HttpGet('https://api.github.com/repos/xdxd09266-byte/test/commits/main?t='..tostring(os.time()), true)
	end)
	if apiSuc and type(apiRes) == 'string' and not apiRes:match('^%d%d%d:') then
		local sha = apiRes:match('"sha"%s*:%s*"([%x]+)"')
		if sha then commit = sha end
	end
	if not commit then
		local _, subbed = pcall(function()
			return game:HttpGet('https://github.com/xdxd09266-byte/test')
		end)
		if type(subbed) == 'string' and not subbed:match('^%d%d%d:') then
			local candidate = subbed:match('"currentOid"%s*:%s*"([%x]+)"')
			if candidate and #candidate == 40 then commit = candidate end
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
if not mainScriptSource or mainScriptSource == '' then
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

