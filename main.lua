local args = {...}
if not game:IsLoaded() then game.Loaded:Wait() end
if shared.vape then shared.vape:Uninject() end

local vape

-- FIX 1: Bulletproof safe_loadstring wrapper
local original_loadstring = (getgenv and getgenv().loadstring) or loadstring
local function safe_loadstring(source, chunkname)
	if type(source) ~= "string" then
		return nil, "Invalid argument: expected string, got " .. type(source)
	end
	local res, err = original_loadstring(source, chunkname)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..tostring(err), 30, 'alert')
	end
	return res, err
end

local readfile = readfile or function() return nil end
local writefile = writefile or function() end
local makefolder = makefolder or function() end
local isfolder = isfolder or function() return false end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))

local function ezLog(msg)
	print('[ezvape] ' .. tostring(msg))
	pcall(function()
		local rf = readfile or function() return '' end
		local wf = writefile or function() end
		local old = ''
		pcall(function() old = rf('newvape/debug.log') or '' end)
		if type(old) ~= 'string' then old = '' end
		if #old > 20000 then old = old:sub(-15000) end
		wf('newvape/debug.log', old .. '\n[' .. tostring(os.time()) .. '] ' .. msg)
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
local function downloadFile(path, func)
	if not isfile(path) then
		local folder = path:match('^(.*)[/\\][^/\\]+$')
		if folder and not isfolder(folder) then
			makefolder(folder)
		end
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/xdxd09266-byte/ggman/main/'..select(1, path:gsub('newvape/', '')), true)
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

local function finishLoading()
	if not vape then return end
	vape.Init = nil
	ezLog('calling vape:Load()')
	local loadOk, loadErr = pcall(function()
		vape:Load()
	end)
	if not loadOk then
		ezError('vape:Load() crashed:\n' .. tostring(loadErr))
		return
	end
	ezStatus.Load = true
	ezLog('vape:Load() done')
	task.spawn(function()
		repeat
			vape:Save()
			task.wait(10)
		until not vape.Loaded
	end)

	local teleportedServers
	local lplr = playersService.LocalPlayer
	if lplr then
		vape:Clean(lplr.OnTeleport:Connect(function()
			if (not teleportedServers) and (not shared.VapeIndependent) then
				teleportedServers = true
				local teleportScript = [[
					shared.vapereload = true
					if shared.VapeDeveloper then
						loadstring(readfile('newvape/loader.lua'), 'loader')()
					elseif isfile('newvape/loader.lua') then
						loadstring(readfile('newvape/loader.lua'), 'loader')()
					else
						loadstring(game:HttpGet('https://raw.githubusercontent.com/xdxd09266-byte/ggman/main/loader.lua', true), 'loader')()
					end
				]]
				if shared.VapeDeveloper then
					teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
				end
				if shared.VapeCustomProfile then
					teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
				end
				vape:Save()
				if queue_on_teleport then queue_on_teleport(teleportScript) end
			end
		end))
	end

	if not shared.vapereload then
		pcall(function()
			local opt = vape.Categories and vape.Categories.Main and vape.Categories.Main.Options and vape.Categories.Main.Options['GUI bind indicator']
			if opt and opt.Enabled then
				vape:CreateNotification('Finished Loading', vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(vape.Keybind, ' + '):upper()..' to open GUI', 5)
			end
		end)
	end
end

if not isfolder('newvape') then makefolder('newvape') end
if not isfolder('newvape/profiles') then makefolder('newvape/profiles') end

if not isfile('newvape/profiles/gui.txt') then
	writefile('newvape/profiles/gui.txt', 'new')
end

local gui = readfile('newvape/profiles/gui.txt')
if type(gui) ~= "string" or gui == "" then gui = "new" end

if not isfolder('newvape/assets/'..gui) then
	makefolder('newvape/assets/'..gui)
end

local guiScript = downloadFile('newvape/guis/'..gui..'.lua')
local guiFunc

-- FIX 2: Bypassing Executor Short-Circuit bugs by explicitly checking strings
if type(guiScript) == "string" then
	guiFunc = safe_loadstring(guiScript, gui)
end

if guiFunc then
	local gok, gres = pcall(guiFunc)
	if not gok then
		ezError('GUI script crashed on load:\n' .. tostring(gres))
		return
	end
	vape = gres
	shared.vape = vape
	ezStatus.GUI = true
	ezLog('GUI script loaded: ' .. tostring(gui))
else
	ezError('Failed to load GUI script: ' .. tostring(gui) .. ' (file missing or network blocked)')
	return
end

if not shared.VapeIndependent then
	local universalScript = downloadFile('newvape/games/universal.lua')
	if type(universalScript) == "string" then
		local universalFunc, uerr = safe_loadstring(universalScript, "universal")
		if universalFunc then
			local ok, err = pcall(universalFunc)
			if not ok then
				ezError('universal.lua crashed:\n' .. tostring(err))
			else
				ezStatus.Universal = true
				ezLog('universal.lua loaded OK')
			end
		else
			ezLog('universal.lua compile error: ' .. tostring(uerr))
		end
	end
	
	local placeId = tostring(game.PlaceId)
	local gameScript = nil
	
	if isfile('newvape/games/'..placeId..'.lua') then
		gameScript = readfile('newvape/games/'..placeId..'.lua')
	else
		if not shared.VapeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/xdxd09266-byte/ggman/main/games/'..placeId..'.lua', true)
			end)
			if suc and res ~= '404: Not Found' then
				gameScript = downloadFile('newvape/games/'..placeId..'.lua')
			end
		end
	end

	if type(gameScript) == "string" then
		local gameFunc, gerr = safe_loadstring(gameScript, placeId)
		if gameFunc then
			local ok, err = pcall(function()
				gameFunc(unpack(args))
			end)
			if not ok then
				ezError('game script crashed:\n' .. tostring(err))
			else
				ezStatus.Game = true
				ezLog('game script loaded OK')
			end
		else
			ezLog('game script compile error: ' .. tostring(gerr))
		end
	end
	
	finishLoading()
	local done = {}
	if ezStatus.GUI then table.insert(done, 'GUI') end
	if ezStatus.Universal then table.insert(done, 'universal') end
	if ezStatus.Game then table.insert(done, 'game') end
	if ezStatus.Load then table.insert(done, 'vape:Load') end
	ezSuccess('main.lua chain complete: ' .. table.concat(done, ' + ') .. '\nOpen menu: top-right button (mobile) or RightShift (PC).')
else
	if vape then
		vape.Init = finishLoading
	end
	return vape
end