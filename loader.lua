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
		local folder = path:match('^(.*)[/\\][^/\\]+$')
		if folder and not isfolder(folder) then
			makefolder(folder)
		end
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/xdxd09266-byte/ggman/main/'..select(1, path:gsub('newvape/', '')), true)
		end)
		if not suc or type(res) ~= 'string' or res == '404: Not Found' then
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
		if file:find('loader') then continue end
		if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
			delfile(file)
		end
	end
end

for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'} do
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
if not shared.VapeDeveloper then
	local _, subbed = pcall(function()
		return game:HttpGet('https://github.com/xdxd09266-byte/ggman')
	end)
	local commit = type(subbed) == 'string' and subbed:find('currentOid') or nil
	commit = commit and subbed:sub(commit + 13, commit + 52) or nil
	commit = commit and #commit == 40 and commit or 'main'
	if commit == 'main' or (isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or '') ~= commit then
		wipeFolder('newvape')
		wipeFolder('newvape/games')
		wipeFolder('newvape/guis')
		wipeFolder('newvape/libraries')
	end
	writefile('newvape/profiles/commit.txt', commit)
end

local mainSource = downloadFile('newvape/main.lua')
if type(mainSource) == 'string' then
	local mainFunc, err = loadstring(mainSource, 'main')
	if type(mainFunc) == 'function' then
		ezLog('loader: main.lua compiled, executing')
		local ok, runtimeErr = pcall(mainFunc)
		if not ok then
			ezError('main.lua crashed:\n' .. tostring(runtimeErr))
		else
			ezLog('loader: main.lua finished without error')
			ezSuccess('ezvape finished loading (teleport reload).\nOpen menu: top-right button (mobile) or RightShift (PC).')
		end
	else
		ezError('Syntax error in main.lua:\n' .. tostring(err))
	end
else
	ezError('Failed to download newvape/main.lua (network blocked?)')
end