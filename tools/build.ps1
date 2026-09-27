# サイトを組み立てる: data/works.json と旧サイトの本文(source/content)から docs/ にHTMLを書き出す。
# 使い方: powershell -ExecutionPolicy Bypass -File tools\build.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'clean.ps1')
$utf8 = [Text.UTF8Encoding]::new($false)
function Read-Text($p) { [IO.File]::ReadAllText((Join-Path $root $p), [Text.Encoding]::UTF8) }
function Write-Page($rel, $html) {
  $path = Join-Path $root "docs\$rel"
  New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
  [IO.File]::WriteAllText($path, $html, $utf8)
}
function E($s) { [Net.WebUtility]::HtmlEncode([string]$s) }

$works = Read-Text 'data\works.json' | ConvertFrom-Json
$layout = Read-Text 'templates\layout.html'

# 旧サイトのURL → 新しいページ
$oldPath = @{
  'a-square'='recording/a%e3%80%80square'; 'cooking'='recording/cooking'; 'monks'='recording/monks-trio2';
  'session2'='recording/session2'; 'oob2'='recording/out-of-bouns2'; 'vintage'='recording/vintage';
  'inspiration'='recording/inspiration'; 'sukiyaki'='recording/village-be-bup'; 'delicious'='recording/delicious';
  'session'='recording/session-santa'; 'touch'='recording/touch'; 'delivery'='recording/delivery';
  'sweet'='recording/sweet-lovely'; 'oob'='recording/out-of-bouns/'; 'mmi'='recording/me-myself'; 'open'='recording/live-report'
}
$linkMap = [ordered]@{}
foreach ($w in $works) { if ($w.report -and $oldPath[$w.report]) { $linkMap[$oldPath[$w.report]] = "{{ROOT}}works/$($w.id)/" } }

# CDページをブロックに分け、各ブロックの先頭画像をジャケットとして取り出す
$cdBlocks = (Clean-OldHtml (Read-Text 'source\content\cd.html') $linkMap) -split '<hr>'
foreach ($w in $works) {
  $w | Add-Member -NotePropertyName cover -NotePropertyValue $null -Force
  $w | Add-Member -NotePropertyName cdHtml -NotePropertyValue $null -Force
  if ($null -ne $w.cd) {
    $b = $cdBlocks[$w.cd]
    $m = [regex]::Match($b, '<img src="([^"]+)"[^>]*>(<br>)?')
    if ($m.Success) { $w.cover = $m.Groups[1].Value; $b = $b.Remove($m.Index, $m.Length) }
    $b = $b -replace '<p>\s*</p>', '' -replace '<div class="photos">\s*</div>', ''
    $w.cdHtml = $b.Trim()
  }
}

function Cover-Tag($w, $root) {
  if ($w.cover) { '<img class="cover" src="' + ($w.cover -replace '\{\{ROOT\}\}', $root) + '" alt="' + (E "$($w.title) ジャケット") + '" loading="lazy">' }
  else { '<div class="cover none" aria-hidden="true">' + $(if ($w.kind -eq 'event') { 'LIVE' } else { 'CD' }) + '</div>' }
}
function Badges($w) {
  if (-not $w.press) { return '' }
  '<div class="badges">' + (($w.press | ForEach-Object { '<span class="badge">' + (E $_) + '</span>' }) -join '') + '</div>'
}
function Quote($w) {
  if (-not $w.quote) { return '' }
  '<blockquote>「' + (E $w.quote) + '」<cite>' + (E $w.quoteBy) + '</cite></blockquote>'
}
function Fill($body, $title, $desc, $rootPath) {
  $html = $layout.Replace('{{BODY}}', $body).Replace('{{TITLE}}', (E $title)).Replace('{{DESC}}', (E $desc))
  $html.Replace('{{ROOT}}', $rootPath)
}

$dated = @($works | Where-Object { $null -ne $_.t } | Sort-Object t -Descending)
$undated = @($works | Where-Object { $null -eq $_.t })
$ordered = $dated + $undated

# ---------- 作品ページ ----------
for ($i = 0; $i -lt $ordered.Count; $i++) {
  $w = $ordered[$i]; $r = '../../'
  $sb = New-Object Text.StringBuilder
  [void]$sb.Append("<div class=""wrap""><p class=""crumb""><a href=""{{ROOT}}"">トップ</a> › <a href=""{{ROOT}}#records"">録音作品</a></p>`n")
  [void]$sb.Append('<div class="work-head">' + (Cover-Tag $w '{{ROOT}}') + '<div>')
  if ($w.date) { [void]$sb.Append('<p class="date">' + (E $w.date) + ' 河内スタヂオ録音</p>') }
  [void]$sb.Append('<h1>' + (E $w.title) + '</h1><p class="who">' + (E $w.artist) + '<small>' + (E $w.members) + '</small></p>')
  [void]$sb.Append((Badges $w) + (Quote $w) + "</div></div>`n")
  if ($w.cdHtml) {
    [void]$sb.Append("<div class=""part""><p class=""eyebrow"">About the Album</p><h2>作品紹介</h2><div class=""prose"">`n$($w.cdHtml)`n</div></div>`n")
  }
  if ($w.report) {
    $rep = Clean-OldHtml (Read-Text "source\content\$($w.report).html") $linkMap
    [void]$sb.Append("<div class=""part""><p class=""eyebrow"">Recording Report</p><h2>レコーディングレポート</h2><div class=""prose"">`n$rep`n</div></div>`n")
  }
  if ($w.related) {
    $rw = $works | Where-Object { $_.id -eq $w.related }
    [void]$sb.Append("<div class=""part""><p>レコーディングの様子は「<a href=""{{ROOT}}works/$($rw.id)/"">$(E $rw.title)</a>」のページで紹介しています。</p></div>`n")
  }
  $prev = if ($i -gt 0) { $ordered[$i-1] } else { $null }
  $next = if ($i -lt $ordered.Count-1) { $ordered[$i+1] } else { $null }
  [void]$sb.Append('<nav class="pager" aria-label="前後の作品">')
  [void]$sb.Append($(if ($prev) { "<a href=""{{ROOT}}works/$($prev.id)/"">← 前の作品<b>$(E $prev.title)</b></a>" } else { '<span></span>' }))
  [void]$sb.Append($(if ($next) { "<a href=""{{ROOT}}works/$($next.id)/"" style=""text-align:right"">次の作品 →<b>$(E $next.title)</b></a>" } else { '<span></span>' }))
  [void]$sb.Append("</nav></div>")
  $desc = "$($w.artist)「$($w.title)」。秋田県大潟村の河内スタヂオで録音。"
  Write-Page "works\$($w.id)\index.html" (Fill $sb.ToString() "$($w.title) | 河内スタヂオ" $desc $r)
}

# ---------- トップページ ----------
$y0 = 1998.8; $y1 = 2008.5
function X($t) { '{0:0.00}%' -f (($t - $y0) / ($y1 - $y0) * 100) }
$tl = (1999..2008 | ForEach-Object { "<span class=""yr"" style=""left:$(X $_)"">$_</span>" }) -join "`n"
$tl += "`n" + (($dated | ForEach-Object {
  $cls = if ($_.press) { 'dot hot' } else { 'dot' }
  "<a class=""$cls"" href=""#$($_.id)"" style=""left:$(X $_.t)"" title=""$(E $_.title)($(E $_.date))"" aria-label=""$(E $_.title) $(E $_.date)""></a>"
}) -join "`n")

$datedHtml = ($dated | ForEach-Object {
  "<li class=""rec"" id=""$($_.id)""><div class=""date"">$(E $_.date)</div>$(Cover-Tag $_ '{{ROOT}}')<div>" +
  "<h3><a href=""works/$($_.id)/"">$(E $_.title)</a></h3><p class=""who"">$(E $_.artist)<small>$(E $_.members)</small></p>" +
  (Quote $_) + (Badges $_) +
  "<a class=""more"" href=""works/$($_.id)/"">$(if ($_.report) { 'レコーディングレポートを読む' } else { '作品について読む' })</a></div></li>"
}) -join "`n"

$undatedHtml = ($undated | ForEach-Object {
  "<a href=""works/$($_.id)/"">$(Cover-Tag $_ '{{ROOT}}')<b>$(E $_.title)</b><span>$(E $_.artist)</span></a>"
}) -join "`n"

$pressHtml = (($dated | Where-Object { $_.press }) | ForEach-Object {
  $w = $_
  $w.press | ForEach-Object {
    $score = if ($_ -match '(\d\.\d)点') { $Matches[1] + ' 点' } elseif ($_ -match 'ベスト・アルバム') { 'ベスト・アルバム' } elseif ($_ -match 'ベスト10') { 'ベスト10' } else { '掲載' }
    "<li><span class=""what"">$(E $_)</span><span class=""score"">$score</span><span class=""work""><a href=""works/$($w.id)/"">$(E $w.title)</a>  $(E $w.artist)</span></li>"
  }
}) -join "`n"

$names = @(
  @('北村英治','cl'),@('Buddy DeFranco','cl'),@('Scott Hamilton','ts'),@('Eddie Higgins','p'),@('Vincent Herring','as'),
  @('和泉宏隆','p'),@('宮之上貴昭','g'),@('世良譲','p'),@('熱田修二','tp'),@('吉岡秀晃','p'),@('小林陽一','ds'),
  @('山田穣','as'),@('金子亜里紗','p'),@('大野めぐみ','vo'),@('小笠原千秋','vo'),@('さがゆき','vo'),@('角の りょう','vo'),
  @('宇多慶記','org'),@('高浜和英','p, vo'),@('竹下清志','p'),@('遠山晃司','b'),@('山口雄三','b'),@('稲垣護','b'),
  @('八城邦義','ds'),@('太田耕平','ds'),@('高橋信之介','ds'),@('榊原長紀','g')
)
$namesHtml = ($names | ForEach-Object { "<li>$(E $_[0])<small>$(E $_[1])</small></li>" }) -join "`n"

$gearAll = [ordered]@{
  'CONSOLE' = @('MIDAS XL200')
  'MONITOR' = @('UREI 813B','GENELEC 1030A','GENELEC 1029A')
  'MIC PREAMP' = @('Focusrite ISA428|×3','Focusrite ISA428 MkⅡ','John Hardy M-1 4ch','Apogee TRAK 2','MACKIE ONYX 800R','Focusrite ISA ONE')
  'DAW / INTERFACE' = @('Samplitude Pro X Suite','Pro Tools','Universal Audio UAD-2 Quad','RME HDSPe RayDAT','Apogee Big Ben (master clock)','RME Fireface 800')
  'AD / DA' = @('Apogee PSX-100','Apogee Mini-DAC 192k','Lucid 88192','Lucid 8824|×3')
  'OUTBOARD' = @('Lexicon 300L','YAMAHA Pro R2','UREI 1178','UREI LA-4','dbx 160SL','dbx 160X|×3')
  'MICROPHONE' = @('NEUMANN U87|×4','NEUMANN U87 Ai|×2','AKG C414 EB|×2','AKG Solid Tube|×2','SONY C-38B|×3','NEUMANN SM69 FET','SCHOEPS CMC64|×2','Earthworks TC30K|×2','DPA 4006|×2','DPA 4090|×2','Telefunken M221B','AKG C451E|×2','AKG C451EB','RCA 77','Electro-Voice RE20|×2','Sennheiser MD421|×5','Shure SM58|×2','Shure SM57|×2')
}
$gearMain = [ordered]@{
  'CONSOLE / MONITOR' = @('MIDAS XL200','UREI 813B','GENELEC 1030A / 1029A')
  'MIC PREAMP' = @('Focusrite ISA428|×3','Focusrite ISA428 MkⅡ','John Hardy M-1 4ch','Apogee TRAK 2')
  'MICROPHONE' = @('NEUMANN U87|×4','NEUMANN U87 Ai|×2','SCHOEPS CMC64|×2','DPA 4006|×2','RCA 77')
  'OUTBOARD' = @('Lexicon 300L','UREI 1178 / LA-4','dbx 160X|×3','Apogee PSX-100')
}
function Gear($g) {
  ($g.Keys | ForEach-Object {
    "<div><h5>$_</h5><ul>" + (($g[$_] | ForEach-Object { $p = $_ -split '\|'; "<li>$(E $p[0])" + $(if ($p.Count -gt 1) { "<span>$($p[1])</span>" } else { '' }) + '</li>' }) -join '') + '</ul></div>'
  }) -join "`n"
}

$cdCount = @($works | Where-Object { $null -ne $_.cd }).Count
$homeHtml = (Read-Text 'templates\home.html').Replace('{{TIMELINE}}', $tl).Replace('{{DATED}}', $datedHtml).Replace('{{UNDATED}}', $undatedHtml).
  Replace('{{PRESS}}', $pressHtml).Replace('{{NAMES}}', $namesHtml).Replace('{{GEAR_MAIN}}', (Gear $gearMain)).Replace('{{GEAR_ALL}}', (Gear $gearAll)).
  Replace('{{WORK_COUNT}}', "$cdCount")
Write-Page 'index.html' (Fill $homeHtml '河内スタヂオ | 秋田県大潟村のレコーディングスタジオ' '秋田県大潟村のプライベート・レコーディングスタジオ。1999年から、残響0.7秒の部屋とスタインウェイD-274でジャズの録音を手がけてきました。' '')

Write-Output "built: index + $($ordered.Count) work pages"
