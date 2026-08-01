$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$outDir = Join-Path $root 'build'
$outPath = Join-Path $outDir 'ezvape_local.lua'

if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

function Get-LuaLongString([string]$content) {
	$maxEq = 0
	foreach ($m in [regex]::Matches($content, '=+')) { if ($m.Length -gt $maxEq) { $maxEq = $m.Length } }
	$level = [Math]::Max($maxEq + 2, 2)
	$open = '[' + ('=' * $level) + '['
	$close = ']' + ('=' * $level) + ']'
	return $open + "`n" + $content + "`n" + $close
}

$files = @(
	@('newvape/NewMainScript.lua', "$root\NewMainScript.lua"),
	@('newvape/main.lua', "$root\main.lua"),
	@('newvape/loader.lua', "$root\loader.lua"),
	@('newvape/guis/new.lua', "$root\guis\new.lua"),
	@('newvape/games/universal.lua', "$root\games\universal.lua"),
	@('newvape/games/6872274481.lua', "$root\build_scripts\build\6872274481.lua"),
	@('newvape/keys.json', "$root\keys.json")
)

$assets = Get-ChildItem "$root\assets\new" -File | Where-Object { $_.Length -le 120000 }

$out = New-Object System.Collections.Generic.List[string]
$out.Add('-- ezvape LOCAL BUILD (fully offline, single file) - never upload this file to a public place')
$out.Add('-- Generated: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
$out.Add('print("[ezvape-local] starting...")')
$out.Add('local __files = {')
foreach ($f in $files) {
	$src = [IO.File]::ReadAllText($f[1], [Text.Encoding]::UTF8)
	if ([string]::IsNullOrEmpty($src)) { throw "Empty source: $($f[1])" }
	$out.Add("	['$($f[0])'] = " + (Get-LuaLongString $src) + ',')
}
$out.Add('}')
$out.Add('local __assets = {')
foreach ($a in $assets) {
	$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($a.FullName))
	$out.Add("	['newvape/assets/new/$($a.Name)'] = " + (Get-LuaLongString $b64) + ',')
}
$out.Add('}')
$out.Add('')
$out.Add('local __svc = game:GetService("HttpService")')
$out.Add('local function __writeFile(path, content)')
$out.Add('	local dir = path:match("^(.*)[/\\\\][^/\\\\]+$")')
$out.Add('	if dir and not isfolder(dir) then makefolder(dir) end')
$out.Add('	writefile(path, content)')
$out.Add('end')
$out.Add('for path, content in pairs(__files) do')
$out.Add('	pcall(__writeFile, path, content)')
$out.Add('end')
$out.Add('for path, b64 in pairs(__assets) do')
$out.Add('	pcall(function()')
$out.Add('		local bytes = __svc:JSONDecode("\"" .. b64 .. "\"")')
$out.Add('		if type(bytes) == "string" and #bytes > 0 then')
$out.Add('			__writeFile(path, bytes)')
$out.Add('		end')
$out.Add('	end)')
$out.Add('end')
$out.Add('pcall(function()')
$out.Add('	if not isfolder("newvape/profiles") then makefolder("newvape/profiles") end')
$out.Add('	writefile("newvape/profiles/local.txt", "")')
$out.Add('	writefile("newvape/profiles/key.txt", "ezvape-local-key")')
$out.Add('end)')
$out.Add('print("[ezvape-local] files ready, starting...")')
$out.Add('local ok, err = pcall(function()')
$out.Add('	local chunk, err2 = loadstring(readfile("newvape/NewMainScript.lua"), "ezvape-local")')
$out.Add('	if not chunk then error(err2) end')
$out.Add('	chunk()')
$out.Add('end)')
$out.Add('if not ok then')
$out.Add('	print("[ezvape-local] fatal: " .. tostring(err))')
$out.Add('end')
$out.Add('')

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($outPath, ($out -join "`n"), $utf8NoBom)

$bytes = [IO.File]::ReadAllBytes($outPath)
Write-Host "[+] Generated local build: $outPath"
Write-Host "    size: $($bytes.Length) bytes ($([Math]::Round($bytes.Length / 1024, 1)) KB)  files: $($files.Count)  assets: $($assets.Count)"
