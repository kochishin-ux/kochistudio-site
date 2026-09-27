# 旧サイトの本文HTMLを、新サイト用のシンプルなHTMLに整える関数。
# build.ps1 から dot-source して使う。

function ConvertTo-LocalImage([string]$url) {
  $rel = [Uri]::UnescapeDataString(($url -replace '^https?://kochistudio\.com/wp-content/uploads/', ''))
  '{{ROOT}}images/old/' + ($rel -replace '[\[\]]', '_')
}

function Clean-OldHtml([string]$h, [hashtable]$linkMap) {
  # WordPress 管理画面の文字が紛れ込んでいる部分を除去
  $h = [regex]::Replace($h, '(?s)メインコンテンツへスキップ.*?ビジュアルテキスト', '')
  $h = [regex]::Replace($h, '(?s)文字数: \d+ 最後の編集:.*$', '')
  # アクセスカウンター、スクリプト、フォーム(旧カート)
  $h = [regex]::Replace($h, '(?s)<!--.*?-->', '')
  $h = [regex]::Replace($h, '(?s)<(script|noscript|style|form)\b.*?</\1>', '')
  $h = [regex]::Replace($h, '<img[^>]*ohugi\.com[^>]*>', '')
  $h = [regex]::Replace($h, 'OLYMPUS DIGITAL CAMERA', '')

  # 画像: src だけ残してローカルパスへ
  $h = [regex]::Replace($h, '<img\b[^>]*?\bsrc="([^"]+)"[^>]*>', {
    param($m)
    $src = $m.Groups[1].Value
    if ($src -notmatch 'kochistudio\.com/wp-content/uploads/') { return '' }
    if ($src -match 'tocargo\.gif') { return '' }
    '<img src="' + (ConvertTo-LocalImage $src) + '" alt="" loading="lazy">'
  })
  # リンク: href だけ残す。旧サイト内リンクは新しい場所へ
  $h = [regex]::Replace($h, '<a\b[^>]*?\bhref="([^"]*)"[^>]*>', {
    param($m)
    $href = [Net.WebUtility]::HtmlDecode($m.Groups[1].Value)
    if ($href -match '^https?://kochistudio\.com/wp-content/uploads/.+\.(jpe?g|gif|png)$') {
      $href = ConvertTo-LocalImage $href
    } else {
      foreach ($k in $linkMap.Keys) { if ($href -like "*$k*") { $href = $linkMap[$k]; break } }
    }
    if ($href -match '^https?://kochistudio\.com/') { $href = '{{ROOT}}' }
    $ext = if ($href -match '^https?://') { ' target="_blank" rel="noopener"' } else { '' }
    '<a href="' + [Net.WebUtility]::HtmlEncode($href) + '"' + $ext + '>'
  })

  # 装飾タグを外し、段落の区切りを <br> にそろえる
  $h = [regex]::Replace($h, '</?(span|font|b|strong|em|i|u|center|small|big|table|tbody|thead|tr|th|colgroup|col|select|option|input)\b[^>]*>', '')
  $h = [regex]::Replace($h, '</(div|td|h\d|li)>', '<br><br>')
  $h = [regex]::Replace($h, '<(div|td|h\d|ul|ol|li)\b[^>]*>', '')
  $h = [regex]::Replace($h, '</?(ul|ol)>', '')
  $h = [regex]::Replace($h, '<p\b[^>]*>', '')
  $h = $h -replace '</p>', '<br><br>'
  $h = [regex]::Replace($h, '<hr\b[^>]*>', '<br><br><hr><br><br>')
  $h = [regex]::Replace($h, '<br\s*/?>', '<br>')
  $h = $h -replace '&nbsp;', ' '
  $h = [regex]::Replace($h, '[ \t\r\n　]*<br>[ \t\r\n　]*', '<br>')

  # <br><br> 以上で段落に分ける。画像だけの段落は写真の並びとして扱う
  $out = New-Object Text.StringBuilder
  foreach ($block in ([regex]::Split($h, '(?:<br>){2,}'))) {
    $b = $block.Trim(" `t`r`n　".ToCharArray()) -replace '^(<br>)+|(<br>)+$', ''
    if (-not $b) { continue }
    if ($b -eq '<hr>') { [void]$out.Append("<hr>`n"); continue }
    $textOnly = ([regex]::Replace($b, '<img[^>]*>|<br>|<a[^>]*>|</a>|[\s　]', ''))
    if (-not $textOnly -and $b -match '<img') {
      [void]$out.Append('<div class="photos">' + ($b -replace '<br>', '') + "</div>`n")
    } elseif ($textOnly) {
      [void]$out.Append("<p>$b</p>`n")
    }
  }
  # 連続する <hr> をまとめる
  [regex]::Replace($out.ToString(), '(<hr>\n)+', "<hr>`n").Trim()
}
