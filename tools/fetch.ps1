# 旧サイト(WordPress)から本文と画像を取り出す。一度だけ実行する移行用スクリプト。
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = Split-Path $PSScriptRoot -Parent
$utf8 = [Text.UTF8Encoding]::new($false)

$pages = [ordered]@{
  'home'        = 'https://kochistudio.com/'
  'recording'   = 'https://kochistudio.com/recording/'
  'a-square'    = 'https://kochistudio.com/recording/a%e3%80%80square%e3%80%80song%e3%80%80book/'
  'cooking'     = 'https://kochistudio.com/recording/cooking/'
  'monks'       = 'https://kochistudio.com/recording/monks-trio2/'
  'session2'    = 'https://kochistudio.com/recording/session2/'
  'oob2'        = 'https://kochistudio.com/recording/out-of-bouns2/'
  'vintage'     = 'https://kochistudio.com/recording/vintage-2/'
  'inspiration' = 'https://kochistudio.com/recording/inspiration/'
  'sukiyaki'    = 'https://kochistudio.com/recording/village-be-bup-quintet/'
  'delicious'   = 'https://kochistudio.com/recording/delicious/'
  'session'     = 'https://kochistudio.com/recording/session-santa/'
  'touch'       = 'https://kochistudio.com/recording/touch/'
  'delivery'    = 'https://kochistudio.com/recording/delivery/'
  'sweet'       = 'https://kochistudio.com/recording/sweet-lovely/'
  'oob'         = 'https://kochistudio.com/recording/out-of-bouns/'
  'mmi'         = 'https://kochistudio.com/recording/me-myself-i/'
  'open'        = 'https://kochistudio.com/recording/live-report/'
  'cd'          = 'https://kochistudio.com/%e5%8f%8e%e9%8c%b2cd/'
  'equipment'   = 'https://kochistudio.com/equipment/'
  'link'        = 'https://kochistudio.com/link/'
}

$rawDir = Join-Path $root 'source\pages'
$conDir = Join-Path $root 'source\content'
$imgDir = Join-Path $root 'images\old'
New-Item -ItemType Directory -Force $rawDir, $conDir, $imgDir | Out-Null

$images = @{}
foreach ($slug in $pages.Keys) {
  $r = Invoke-WebRequest -UseBasicParsing $pages[$slug]
  $ms = New-Object IO.MemoryStream; $r.RawContentStream.CopyTo($ms)
  $html = $utf8.GetString($ms.ToArray())
  [IO.File]::WriteAllText((Join-Path $rawDir "$slug.html"), $html, $utf8)

  $m = [regex]::Match($html, '(?s)class="entry-content">(.*?)</div><!-- \.entry-content -->')
  $body = if ($m.Success) { $m.Groups[1].Value } else { '' }
  [IO.File]::WriteAllText((Join-Path $conDir "$slug.html"), $body, $utf8)

  foreach ($im in [regex]::Matches($body, '(?:src|href)="(https?://kochistudio\.com/wp-content/uploads/[^"]+\.(?:jpe?g|gif|png))"', 'IgnoreCase')) {
    $images[$im.Groups[1].Value] = $true
  }
  Write-Output "page  $slug  $($body.Length) chars"
}

$ok = 0; $ng = @()
foreach ($u in $images.Keys) {
  $rel = [Uri]::UnescapeDataString(($u -replace '^https?://kochistudio\.com/wp-content/uploads/', ''))
  $safe = ($rel -replace '[\[\]]', '_') -replace '/', '\'
  $dest = Join-Path $imgDir $safe
  New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
  try { Invoke-WebRequest -UseBasicParsing $u -OutFile $dest; $ok++ } catch { $ng += $u }
}
Write-Output "images ok=$ok failed=$($ng.Count)"
$ng | ForEach-Object { Write-Output "  failed: $_" }
