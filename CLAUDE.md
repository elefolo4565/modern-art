# Claude Code 設定

## 言語
- ユーザーへの応答は日本語で行う
- ツール実行（Bashコマンド等）の確認時には、何を行おうとしているかを日本語で要約表示すること
- Bashコマンドの description フィールドも日本語で記述すること
- ユーザーに選択肢を提示する場合（AskUserQuestion等）、選択肢のラベルと説明を日本語で記述すること

## バージョン
v1.4

## プロジェクト概要
ライナー・クニツィアのカードゲーム「モダンアート」のオンライン対戦ゲーム。
スマホブラウザ（縦画面）でプレイ可能。

## 技術スタック
- **クライアント**: Godot 4.6 (GDScript), Web Export (HTML5/WASM)
- **サーバー**: Python 3 + aiohttp (WebSocket)
- **通信**: WebSocket (JSON)
- **対応言語**: 日本語・英語（切替可能）
- **ホスティング**: クライアント=GitHub Pages / サーバー=Render

## フォルダ構成
```
client/          Godotプロジェクト（720×1280 縦画面）
├── scripts/
│   ├── autoload/    network.gd, game_state.gd, locale.gd（シングルトン）
│   ├── title/       タイトル画面
│   ├── lobby/       ロビー・待機室
│   ├── game/        ゲーム本体（game_board, auction_panel, card, market_board, result）
│   └── components/  共通UI（player_info, hand_area）
├── scenes/          対応する .tscn ファイル群
└── assets/          フォント・画像・テーマ
server/          Pythonサーバー
├── main.py          エントリーポイント（HTTP + WebSocket, ポート8080）
├── lobby.py         部屋管理
├── game.py          ゲーム進行・ターン管理
├── auction.py       5種オークションロジック
├── cards.py         カード定義・デッキ・配布
├── ai_player.py     AI対戦（AIBrain + AIPlayerController）
└── protocol.py      メッセージプロトコル
export/          Godot Web Export 出力先
```

## ゲームルール要点
- プレイヤー: 3〜5人（人間+AI混合可）
- カード: 全70枚、5アーティスト（Orange Tarou:12, Green Tarou:13, Blue Tarou:14, Yellow Tarou:15, Red Tarou:16）
- オークション: 公開競り, 順競り, 入札, 指値, ダブルの5種
- 4ラウンド制、同一アーティスト5枚目でラウンド終了
- 上位3アーティストに価値付与（30K/20K/10K）、価値は累積
- 初期所持金: 100K、最終的に最も現金の多いプレイヤーが勝利

## サーバー起動
```bash
cd server && python main.py --port 8080
```

## 注意点
- locale.gd の翻訳関数は `t()` / `tf()`（Nodeの組み込み `tr()` との衝突を回避）
- AI処理は `_ai_processing` フラグで再帰防止（whileループ方式）
- WebSocket接続は `network.gd` で状態チェック後に `connect_to_url()` を呼ぶ

## 開発メモ（実装済み）
- **入札K単位**: SpinBoxは1〜999のK単位で入力、送信時に×1000。SpinBoxのsuffixプロパティは値変更で消えるバグがあるため、隣接Labelで"K"を表示
- **手札ソート**: ARTISTS配列順（色順） → 同アーティストならオークション種低レア順（open=0, once_around=1, sealed=2, fixed_price=3, double=4）
- **カードプレビュー**: 右からスライドイン。VBoxContainer内のレイアウトがposition.xを上書きするため、`await get_tree().process_frame`後にアニメーション開始。`_preview_gen`カウンタで非同期キャンセル制御
- **プレイヤー情報**: 横並び（HBoxContainer）、各セルは縦（VBoxContainer: 名前/所持金/枚数）。ターン表示は名前色で判別（黄=現在ターン、青=自分）
- **アーティスト名**: 色名ベース（Orange/Green/Blue/Yellow/Red Tarou）。定義箇所: server/cards.py, client/game_state.gd, locale.gd, market_board.gd
- **手札表示（Slay the Spire風）**: ScrollContainerではなくControl+clip_contentsで全カード表示。カード枚数に応じて自動的に重なり調整。選択カードは上にポップアップ（-12y, z_index=100）
- **アクティブプレイヤー枠**: PanelContainer+StyleBoxFlatで黄色い丸みを帯びた枠。Tweenで透明度パルスアニメーション（0.9秒周期, SINE）
- **取引ログ**: 相場ボード左の「ログ」ボタン→全画面オーバーレイ表示。GameState.auction_logにオークション結果を蓄積。タイトルバー右の「x」で閉じる
- **ダブルプレイUI表示**: サーバーからcard_playedに`is_double`フラグ送信。オークションパネルのタイプ表示に「[x2 ダブル]」追記。取引ログにもダブル表記。ターンラベルにダブルプレイ通知表示
- **直近ログ表示**: 相場ボードの上にRecentLog（VBoxContainer）で直近3件のオークション結果を常時表示。font_size=12、アーティスト色付き
- **所持絵画表示**: player_infoにアーティスト色付きの絵画数を表示（O1 G2形式）。相場ボードの「絵画」ボタンで全画面オーバーレイの詳細一覧を表示
- **ダブルカード手札フィルタ**: ダブル選択時、同じアーティストのカードのみ選択可能。hand_area.set_filter()/clear_filter()で制御

## デプロイ構成
- **クライアント**: GitHub Pages（`.github/workflows/deploy-pages.yml` で `export/` を自動デプロイ）
- **サーバー**: Render（`server/render.yaml` で Python WebSocket サーバーをデプロイ）
- **WebSocket接続**: `network.gd` の `server_url` に Render の URL をハードコード。ローカル開発時は自動的に `ws://127.0.0.1:8080/ws` に切替
- **フォント**: NotoSansJP-Bold.ttf をデフォルトテーマに設定（Web Export で日本語表示に必須）

## バージョン管理ルール
- 機能追加・バグ修正・UIの変更など、何らかの更新を行った場合は CLAUDE.md のバージョン番号をインクリメントする（パッチ: +0.1）
- クライアント変更を含む場合は `export/` を再エクスポートしてコミットに含めること
- クライアント変更時: Godot で Web Export を再実行 → `export/` をコミット → プッシュで GitHub Pages が自動更新
- サーバー変更時: コミット＆プッシュで Render が自動デプロイ。ローカルサーバーも再起動する

## Git運用
- 機能実装やバグ修正のたびにgitコミットを行う
- サーバー（server/）に変更があるコミット後は、即座にサーバーを再起動する（既存プロセスをkill→再起動）
