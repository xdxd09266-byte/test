$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$gameCompiledPath = "$PSScriptRoot\build\6872274481.lua"
$outPath = "$PSScriptRoot\build\inject_bedwars.lua"

if (-not (Test-Path $gameCompiledPath)) {
    Write-Error "Compiled BedWars game file missing. Run build_bedwars.ps1 first."
    exit 1
}

$gameCompiled = [System.IO.File]::ReadAllText($gameCompiledPath, [System.Text.Encoding]::UTF8)

$authScriptPath = "$PSScriptRoot\..\NewMainScript.lua"
$authScript = [System.IO.File]::ReadAllText($authScriptPath, [System.Text.Encoding]::UTF8)

$inject = @"
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
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/xdxd09266-byte/test/main/'..select(1, path:gsub('weedhack/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			-- Only wipe and fallback if it's a critical file (not assets)
			if not path:find('assets/') then
				-- Redownload everything except assets (preserve custom assets)
				for _, folder in {'weedhack', 'weedhack/games', 'weedhack/profiles', 'weedhack/libraries', 'weedhack/guis'} do
					wipeFolder(folder)
					makefolder(folder)
				end
				-- Ensure assets folder exists but don't wipe it
				if not isfolder('weedhack/assets') then
					makefolder('weedhack/assets')
				end
				local injSuc, injData = pcall(function()
					return game:HttpGet('https://raw.githubusercontent.com/xdxd09266-byte/test/main/build/inject_bedwars.lua', true)
				end)
				if injSuc and injData and #injData > 1000 then
					writefile('weedhack/inject_bedwars.lua', injData)
					local func = loadstring(injData)
					if func then func() end
					return
				end
				error('Failed to download: ' .. tostring(res))
			end
			-- For assets, just return nil on 404 (don't error)
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

-- Download cape from GitHub raw (only if not exists)
if not isfile("weedhack/cape/rangiku.png") then
	local capeOk, capeData = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/xdxd09266-byte/test/main/assets/cape.png", true)
	if capeOk and capeData and #capeData > 100 then
		writefile("weedhack/cape/rangiku.png", capeData)
	end
end

-- Auto-download configs from GitHub
local configIds = {"6872265039", "6872274481", "8444591321", "8560631822"}
for _, placeId in ipairs(configIds) do
	local configName = "blatant" .. placeId
	local configPath = "weedhack/profiles/" .. configName .. ".gui.txt"
	if not isfile(configPath) then
		local suc, res = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/xdxd09266-byte/test/main/profiles/" .. configName .. ".gui.txt", true)
		if suc and res and #res > 10 then
			writefile(configPath, res)
		end
	end
end

-- Write essential profiles (only if not exists)
if not isfile('weedhack/profiles/commit.txt') then
	writefile('weedhack/profiles/commit.txt', '71f871ed64df5695cef5b6d2e3a94b717eb6c32e')
end
if not isfile('weedhack/profiles/gui.txt') then
	writefile('weedhack/profiles/gui.txt', 'new')
end
if not isfile('weedhack/profiles/metacommit.txt') then
	writefile('weedhack/profiles/metacommit.txt', 'a109a0a4441e42d497fa7e3cdc04d770dd853a15')
end

-- Write compiled private game features
writefile("weedhack/games/6872274481.lua", [===[${gameCompiled}]===])

-- Redirect scripts for sub-places (point to local file instead of GitHub)
local redirectScript = 'loadstring(readfile("weedhack/games/6872274481.lua"))()'
writefile("weedhack/games/8444591321.lua", redirectScript)
writefile("weedhack/games/8560631822.lua", redirectScript)

-- Dynamic Place ID fallback: auto-bind current place ID to game script if in main game
if game.PlaceId == 6872274481 or game.PlaceId == 8444591321 or game.PlaceId == 8560631822 then
	local placeId = tostring(game.PlaceId)
	if not isfile("weedhack/games/" .. placeId .. ".lua") then
		writefile("weedhack/games/" .. placeId .. ".lua", redirectScript)
	end
end

-- Run authentication and main script
${authScript}
"@

$inject = $inject -replace '\$\{gameCompiled\}', $gameCompiled
$inject = $inject -replace '\$\{authScript\}', $authScript

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outPath, $inject, $utf8NoBom)

Write-Host "[+] Generated inject_bedwars.lua -> $outPath"


