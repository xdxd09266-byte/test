$ErrorActionPreference = 'Stop'
$root = "C:\Users\Administrator\Downloads\ddddd"
$c = [IO.File]::ReadAllText("$root\build\ezvape_local.lua")
$sources = @{
	'weedhack/NewMainScript.lua'   = "$root\NewMainScript.lua"
	'weedhack/main.lua'            = "$root\main.lua"
	'weedhack/loader.lua'          = "$root\loader.lua"
	'weedhack/guis/new.lua'        = "$root\guis\new.lua"
	'weedhack/games/universal.lua' = "$root\games\universal.lua"
	'weedhack/games/6872274481.lua'= "$root\build_scripts\build\6872274481.lua"
	'weedhack/keys.json'           = "$root\keys.json"
}
$pattern = "'([^']+)'\] = \[(=*)\[([\s\S]*?)\n\](=*)\],"
$matches = [regex]::Matches($c, $pattern)
Write-Host "entries found: $($matches.Count) (expect 70)"
$okCount = 0; $failCount = 0
foreach ($m in $matches) {
	$name = $m.Groups[1].Value
	$openEq = $m.Groups[2].Value; $closeEq = $m.Groups[4].Value
	$content = $m.Groups[3].Value
	if ($content.StartsWith("`n")) { $content = $content.Substring(1) }
	if ($openEq -ne $closeEq) { Write-Host "FAIL delimiter mismatch: $name"; $failCount++; continue }
	if ($name.StartsWith('weedhack/assets/')) {
		$srcFile = "$root\assets\new\" + $name.Substring('weedhack/assets/new/'.Length)
		$srcBytes = [IO.File]::ReadAllBytes($srcFile)
		$decoded = [Convert]::FromBase64String($content)
		$same = $srcBytes.Length -eq $decoded.Length
		if ($same) {
			for ($i = 0; $i -lt $srcBytes.Length; $i++) { if ($srcBytes[$i] -ne $decoded[$i]) { $same = $false; break } }
		}
		if ($same) { $okCount++ } else { Write-Host "FAIL asset mismatch: $name"; $failCount++ }
	} elseif ($sources.ContainsKey($name)) {
		$src = [IO.File]::ReadAllText($sources[$name], [Text.Encoding]::UTF8)
		if ($src -eq $content) { $okCount++ } else { Write-Host "FAIL text mismatch: $name"; $failCount++ }
	} else {
		Write-Host "WARN unknown entry: $name"
	}
}
Write-Host "OK: $okCount  FAIL: $failCount"

