$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$privateDir = Join-Path $scriptDir "..\private"
$gamesDir = Join-Path $scriptDir "..\games"
$gameCompiledPath = Join-Path $scriptDir "..\build\inject_blockwars.lua"
$gameSourceDir = Join-Path $privateDir "games\132768098780837 - blockwars"
$gameBaseDir = Join-Path $gamesDir "132768098780837 - blockwars"

# Ensure the build directory exists
if (-not (Test-Path (Join-Path $scriptDir "..\build"))) {
    New-Item -ItemType Directory -Path (Join-Path $scriptDir "..\build") | Out-Null
}

# Compile game features
$compiledGame = ""

# First, include base.lua if it exists (essential setup code) - check both private and games directories
$baseFile = Join-Path $gameBaseDir "base.lua"
if (-not (Test-Path $baseFile)) {
    $baseFile = Join-Path $gameSourceDir "base.lua"
}
if (Test-Path $baseFile) {
    $compiledGame += (Get-Content $baseFile -Raw -Encoding UTF8)
    $compiledGame += "`n"
}

# Then compile feature modules from both private and public directories
$featureTypes = @("Blatant", "Legit", "Utility", "Visuals", "World", "Minigames", "Inventory", "Combat", "Render")
foreach ($type in $featureTypes) {
    # Public directory
    $publicFeatureDir = Join-Path $gameBaseDir $type
    if (Test-Path $publicFeatureDir) {
        Get-ChildItem -Path $publicFeatureDir -Filter "*.lua" -Recurse | ForEach-Object {
            $compiledGame += "`nrun(function()`n"
            $compiledGame += (Get-Content $_.FullName -Raw -Encoding UTF8)
            $compiledGame += "`nend)`n"
        }
    }

    # Private directory
    $featureDir = Join-Path $gameSourceDir $type
    if (Test-Path $featureDir) {
        Get-ChildItem -Path $featureDir -Filter "*.lua" -Recurse | ForEach-Object {
            $compiledGame += "`nrun(function()`n"
            $compiledGame += (Get-Content $_.FullName -Raw -Encoding UTF8)
            $compiledGame += "`nend)`n"
        }
    }
}

# Write the compiled game features to a temporary file (UTF-8 WITHOUT BOM)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Re-apply saved config after module (re)creation so re-executing the game file never resets user settings
$compiledGame += "`n-- restore saved profile (options, toggles) after module re-creation`npcall(function() vape:Load() end)`n"

[System.IO.File]::WriteAllText($gameCompiledPath, $compiledGame, $utf8NoBom)

# Also write the deployed game file (served as weedhack/games/132768098780837.lua)
$deployedGamePath = Join-Path $scriptDir "..\games\132768098780837.lua"
[System.IO.File]::WriteAllText($deployedGamePath, $compiledGame, $utf8NoBom)
Write-Host "[+] Wrote deployed game file -> $deployedGamePath"

# Also copy to local workspace if we have real/workspace setup
$localWorkspace = "$env:LOCALAPPDATA\Real\workspace\build"
if (Test-Path $localWorkspace) {
    Copy-Item $gameCompiledPath -Destination (Join-Path $localWorkspace "inject_blockwars.lua") -Force
    Write-Host "[+] Copied to Executor Workspace: $localWorkspace\inject_blockwars.lua"
}

Write-Host "[+] Compiled BlockWars game features to -> $gameCompiledPath"
