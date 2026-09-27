# 河内スタヂオ ウェブサイト

秋田県大潟村のレコーディングスタジオ「河内スタヂオ」のサイトです。`docs/` がそのまま公開されます。

## 作品を追加・修正するとき

1. `data/works.json` を編集します(録音日 `date`、年表の位置 `t`、評価 `press` など)。
2. 次のコマンドでページを作り直します。

```
powershell -ExecutionPolicy Bypass -File tools\build.ps1
```

## フォルダ

- `data/works.json` … 作品の一覧
- `templates/` … ページのひな形
- `source/content/` … 旧サイト(WordPress)から移した本文
- `tools/build.ps1` … `docs/` を作るスクリプト
- `tools/serve.ps1` … 確認用サーバー(http://localhost:8080/)
- `docs/` … 公開されるファイル
