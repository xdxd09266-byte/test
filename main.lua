local args = {...}
if not game:IsLoaded() then game.Loaded:Wait() end
if shared.vape then pcall(function() shared.vape:Uninject() end) end

-- Modern Executor Environment Normalization
local getgenv = getgenv or function() return _G end
local setthreadidentity = setthreadidentity or setidentity or set_thread_identity or function() end
local cloneref = cloneref or function(obj) return obj end
local playersService = cloneref(game:GetService('Players'))
local lplr = playersService.LocalPlayer

-- Safe Loadstring Protocol
local original_loadstring = getgenv().loadstring or loadstring
local function safe_loadstring(source, chunkname)
	if type(source) ~= "string" then
		return nil, "Expected string source, got " .. type(source)
	end
	local res, err = original_loadstring(source, chunkname)
	if err and shared.vape and shared.vape.CreateNotification then
		pcall(function() shared.vape:CreateNotification('Vape Error', 'Compile failed: '..tostring(err), 10, 'alert') end)
	end
	return res, err
end

local readfile = readfile or function() return nil end
local writefile = writefile or function() end
local makefolder = makefolder or function() end
local isfolder = isfolder or function() return false end
local isfile = isfile or function(file)
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil and res ~= ''
end

local function ezLog(msg)
	print('[ezvape] ' .. tostring(msg))
	pcall(function()
		local old = isfile('weedhack/debug.log') and readfile('weedhack/debug.log') or ''
		if type(old) ~= 'string' then old = '' end
		if #old > 30000 then old = old:sub(-20000) end
		writefile('weedhack/debug.log', old .. '\n[' .. tostring(os.time()) .. '] ' .. msg)
	end)
end

local function ezError(msg)
	warn('[ezvape Error] ' .. tostring(msg))
	ezLog('[ERROR] ' .. tostring(msg))
end

local function downloadFile(path)
	if not isfile(path) then
		local folder = path:match('^(.*)[/\\][^/\\]+$')
		if folder and not isfolder(folder) then makefolder(folder) end
		local suc, res = pcall(function()
			local cleanPath = path:gsub('^weedhack/', '')
			return game:HttpGet('https://raw.githubusercontent.com/xdxd09266-byte/test/main/'..cleanPath..'?t='..tostring(os.time()), true)
		end)
		if not suc or type(res) ~= 'string' or res:match('^404') or res:match('^403') then
			return nil
		end
		if path:find('%.lua$') then
			res = '--[ezvape auto-sync header]\n'..res
		end
		writefile(path, res)
	end
	return readfile(path)
end

local function finishLoading()
	if not shared.vape then return end
	shared.vape.Init = nil
	ezLog('Initializing Vape UI & Module Loops...')
	local loadOk, loadErr = pcall(function() shared.vape:Load() end)
	if not loadOk then
		ezError('vape:Load() crashed: ' .. tostring(loadErr))
		return
	end

	-- Auto-Save Loop
	task.spawn(function()
		repeat
			task.wait(10)
			if shared.vape and shared.vape.Loaded then
				pcall(function() shared.vape:Save() end)
			end
		until not (shared.vape and shared.vape.Loaded)
	end)

	-- Teleport Queue Preservation
	if lplr then
		shared.vape:Clean(lplr.OnTeleport:Connect(function()
			if not shared.VapeIndependent then
				local teleportScript = [[
					shared.vapereload = true
					shared.VapeDeveloper = true
					if isfile('weedhack/main.lua') then
						loadstring(readfile('weedhack/main.lua'), 'main')()
					else
						loadstring(game:HttpGet('https://raw.githubusercontent.com/xdxd09266-byte/test/main/main.lua'), 'main')()
					end
				]]
				if queue_on_teleport then pcall(function() queue_on_teleport(teleportScript) end) end
			end
		end))
	end

	if not shared.vapereload then
		pcall(function()
			shared.vape:CreateNotification('ezvape Modern', 'Loaded successfully! Press button or RightShift.', 5)
		end)
	end
end

-- Directory Setup
for _, folder in ipairs({'weedhack', 'weedhack/profiles', 'weedhack/assets', 'weedhack/games', 'weedhack/guis'}) do
	if not isfolder(folder) then makefolder(folder) end
end

if not isfile('weedhack/profiles/gui.txt') then writefile('weedhack/profiles/gui.txt', 'new') end
local guiName = readfile('weedhack/profiles/gui.txt') or 'new'
if guiName == '' then guiName = 'new' end

-- Load GUI Script
local guiScript = downloadFile('weedhack/guis/'..guiName..'.lua')
if type(guiScript) == "string" then
	local guiFunc, gerr = safe_loadstring(guiScript, guiName)
	if guiFunc then
		local gok, gres = pcall(guiFunc)
		if gok and gres then
			shared.vape = gres
			ezLog('GUI engine loaded: ' .. tostring(guiName))
		else
			ezError('GUI initialization failed: ' .. tostring(gres))
			return
		end
	else
		ezError('GUI compile error: ' .. tostring(gerr))
		return
	end
end

if not shared.VapeIndependent then
	-- Universal Module Execution
	local universalScript = downloadFile('weedhack/games/universal.lua')
	if type(universalScript) == "string" then
		local universalFunc = safe_loadstring(universalScript, "universal")
		if universalFunc then pcall(universalFunc) end
	end

	-- Place-Specific Game Script Execution (Priority: Local Build > Github Download)
	local placeId = tostring(game.PlaceId)
	local gameScriptSource = nil

	if isfile('weedhack/games/'..placeId..'.lua') then
		gameScriptSource = readfile('weedhack/games/'..placeId..'.lua')
	elseif isfile('build/'..placeId..'.lua') then
		gameScriptSource = readfile('build/'..placeId..'.lua')
	else
		gameScriptSource = downloadFile('weedhack/games/'..placeId..'.lua')
	end

	if type(gameScriptSource) == "string" then
		local gameFunc, gerr = safe_loadstring(gameScriptSource, placeId)
		if gameFunc then
			local ok, err = pcall(function() gameFunc(unpack(args)) end)
			if ok then
				ezLog('Game module place ' .. placeId .. ' active!')
			else
				ezError('Game script execution error: ' .. tostring(err))
			end
		else
			ezError('Game script compile error: ' .. tostring(gerr))
		end
	end

	finishLoading()
else
	if shared.vape then shared.vape.Init = finishLoading end
	return shared.vape
end

