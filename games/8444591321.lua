local vape = shared.vape
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/xdxd09266-byte/test/main/'..select(1, path:gsub('weedhack/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

vape.Place = 6872274481
local function runGameModule()
	local fileSource = ''
	if isfile('build/'..vape.Place..'.lua') then
		fileSource = readfile('build/'..vape.Place..'.lua')
	elseif isfile('weedhack/games/'..vape.Place..'.lua') then
		fileSource = readfile('weedhack/games/'..vape.Place..'.lua')
	else
		if not shared.VapeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/xdxd09266-byte/test/main/games/'..vape.Place..'.lua', true)
			end)
			if suc and res ~= '404: Not Found' then
				fileSource = downloadFile('weedhack/games/'..vape.Place..'.lua')
			end
		end
	end

	if fileSource ~= '' then
		local func = loadstring(fileSource, 'bedwars')
		if type(func) == "function" then
			func()
		end
	end
end

runGameModule()

