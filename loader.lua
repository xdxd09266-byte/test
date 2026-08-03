-- ezvape universal loader
-- completely standalone, replaces NewMainScript and main.lua

local args = {...}
if not game:IsLoaded() then game.Loaded:Wait() end
if shared.vape then pcall(function() shared.vape:Uninject() end) end

-- Developer mode on by default for now to prevent caching issues
shared.VapeDeveloper = true

-- Modern Executor Environment Normalization
local getgenv = getgenv or function() return _G end
local setthreadidentity = setthreadidentity or setidentity or set_thread_identity or function() end
local cloneref = cloneref or function(obj) return obj end
local playersService = cloneref(game:GetService('Players'))
local lplr = playersService.LocalPlayer

-- File System Stubs
local readfile = readfile or function() return "" end
local writefile = writefile or function() end
local makefolder = makefolder or function() end
local isfolder = isfolder or function() return false end
local listfiles = listfiles or function() return {} end
local delfile = delfile or function(f) writefile(f, '') end
local isfile = isfile or function(file)
	local suc, res = pcall(readfile, file)
	return suc and res ~= nil and res ~= ''
end

-- Directory Setup
for _, folder in ipairs({'weedhack', 'weedhack/profiles', 'weedhack/assets', 'weedhack/games', 'weedhack/guis', 'weedhack/libraries'}) do
	if not isfolder(folder) then makefolder(folder) end
end

-- Logging
local function ezLog(msg)
	print('[ezvape] ' .. tostring(msg))
	pcall(function()
		local old = isfile('weedhack/debug.log') and readfile('weedhack/debug.log') or ''
		if type(old) ~= 'string' then old = '' end
		if #old > 20000 then old = old:sub(-15000) end
		writefile('weedhack/debug.log', old .. '\n[' .. tostring(os.time()) .. '] ' .. msg)
	end)
end

local function ezError(msg)
	warn('[ezvape Error] ' .. tostring(msg))
	ezLog('[ERROR] ' .. tostring(msg))
end

-- Clean Corrupted Cache (BOM sweeps)
-- This strips the UTF-8 BOM if it somehow sneaks in and breaks loadstring
local function stripBOM(str)
	if type(str) == "string" then
		return (str:gsub("\239\187\191", ""))
	end
	return str
end

-- File Downloader
local function downloadFile(path)
    local localPath = path
	
	if not isfile(localPath) then
		ezError("File not found locally: " .. tostring(localPath))
		return nil
	end
	
	local content = readfile(localPath)
	return stripBOM(content)
end

-- Safe Loadstring Protocol
local original_loadstring = getgenv().loadstring or loadstring
local function safe_loadstring(source, chunkname)
	if type(source) ~= "string" then
		return nil, "Expected string source, got " .. type(source)
	end
	source = stripBOM(source) -- one last check
	local res, err = original_loadstring(source, chunkname)
	if err then
		ezError("Compile failed in " .. tostring(chunkname) .. ": " .. tostring(err))
		if shared.vape and shared.vape.CreateNotification then
			pcall(function() shared.vape:CreateNotification('Vape Error', 'Compile failed: '..tostring(err), 10, 'alert') end)
		end
	end
	return res, err
end

-- Module Loader
local function loadModule(path, chunkname, ...)
    local source = downloadFile(path)
    if type(source) == "string" then
        local func, err = safe_loadstring(source, chunkname)
        if func then
            local success, result = pcall(func, ...)
            if success then
                return true, result
            else
                ezError("Execution error in " .. chunkname .. ": " .. tostring(result))
                return false, result
            end
        end
    else
        ezLog("Failed to download or read module: " .. path)
    end
    return false, nil
end

-- Load GUI
if not isfile('weedhack/profiles/gui.txt') then writefile('weedhack/profiles/gui.txt', 'new') end
local guiName = readfile('weedhack/profiles/gui.txt') or 'new'
if guiName == '' then guiName = 'new' end

local guiSuccess, vapeInstance = loadModule('weedhack/guis/'..guiName..'.lua', guiName)
if guiSuccess and vapeInstance then
    shared.vape = vapeInstance
    ezLog('GUI engine loaded: ' .. tostring(guiName))
else
    ezError('Critical: GUI engine failed to load!')
    return
end

if not shared.VapeIndependent then
	-- Universal Module
	loadModule('weedhack/games/universal.lua', 'universal')

	-- Place-Specific Game Script
	local placeId = tostring(game.PlaceId)
	if game.GameId == 2603217424 then
		placeId = "6872274481"
	end
    
    -- Local build override support (for fast dev without pushing to github)
    local localGamePath = 'build/'..placeId..'.lua'
    if isfile(localGamePath) then
        local source = readfile(localGamePath)
        source = stripBOM(source)
        local func = safe_loadstring(source, placeId)
        if func then
            pcall(func, unpack(args))
            ezLog('Loaded LOCAL BUILD for ' .. placeId)
        end
    else
        -- Normal github loader
	    local gameSuccess = loadModule('weedhack/games/'..placeId..'.lua', placeId, unpack(args))
        if gameSuccess then
            ezLog('Loaded cloud game module for ' .. placeId)
        end
    end

    -- Finish Loading
	if shared.vape then
        shared.vape.Init = nil
        ezLog('Initializing Vape UI & Module Loops...')
        local loadOk, loadErr = pcall(function() shared.vape:Load() end)
        if not loadOk then
            ezError('vape:Load() crashed: ' .. tostring(loadErr))
            return
        end

        -- Auto-Save
        task.spawn(function()
            repeat
                task.wait(10)
                if shared.vape and shared.vape.Loaded then
                    pcall(function() shared.vape:Save() end)
                end
            until not (shared.vape and shared.vape.Loaded)
        end)

        -- Teleport Queue
        if lplr then
            shared.vape:Clean(lplr.OnTeleport:Connect(function()
                if not shared.VapeIndependent then
                    local teleportScript = [[
                        shared.vapereload = true
                        shared.VapeDeveloper = true
                        if isfile("loader.lua") then
                            loadstring(readfile("loader.lua"))()
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
else
	if shared.vape then shared.vape.Init = function() end end
end

return shared.vape
