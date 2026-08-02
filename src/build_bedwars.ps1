$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$privateDir = Join-Path $scriptDir "..\private"
$gamesDir = Join-Path $scriptDir "..\games"
$gameCompiledPath = Join-Path $scriptDir "..\build\6872274481.lua"
$gameSourceDir = Join-Path $privateDir "games\bedwars\6872274481 - game"
$lobbySourceDir = Join-Path $privateDir "games\bedwars\6872265039 - lobby"
$gameBaseDir = Join-Path $gamesDir "bedwars\6872274481 - game"

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

# Then compile feature modules from private and public games directories
$featureTypes = @("Combat", "Blatant", "Render", "Utility", "World", "Inventory", "Minigames", "Legit")
foreach ($type in $featureTypes) {
    $dirsToCompile = @(
        (Join-Path $gameBaseDir $type),
        (Join-Path $gameSourceDir $type)
    )
    
    foreach ($featureDir in $dirsToCompile) {
        if (Test-Path $featureDir) {
            Get-ChildItem -Path $featureDir -Filter "*.lua" -Recurse | ForEach-Object {
                $compiledGame += "`nrun(function()`n"
                $compiledGame += (Get-Content $_.FullName -Raw -Encoding UTF8)
                $compiledGame += "`nend)`n"
            }
        }
    }
}

# Compile lobby features (if any, though current focus is game)
$compiledLobby = ""
if (Test-Path $lobbySourceDir) {
    Get-ChildItem -Path $lobbySourceDir -Filter "*.lua" -Recurse | ForEach-Object {
        $compiledLobby += "`nrun(function()`n"
        $compiledLobby += (Get-Content $_.FullName -Raw -Encoding UTF8)
        $compiledLobby += "`nend)`n"
    }
}

# Write the compiled game features to a temporary file
Set-Content -Path $gameCompiledPath -Value $compiledGame -Encoding UTF8

Write-Host "[+] Compiled BedWars game features to -> $gameCompiledPath"
