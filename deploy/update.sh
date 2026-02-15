#!/bin/bash
# Modern Art - アプリケーション更新スクリプト
# VPS 上でコードを最新版に更新してサーバーを再起動します
#
# 使い方: bash /opt/modern-art/repo/deploy/update.sh

set -euo pipefail

APP_DIR="/opt/modern-art"
REPO_DIR="$APP_DIR/repo"

echo "=== Modern Art 更新開始 ==="

# リポジトリの更新
echo "[1/4] リポジトリを更新中..."
cd "$REPO_DIR"
git fetch origin main
git reset --hard origin/main

# サーバーファイルの同期
echo "[2/4] サーバーファイルを同期中..."
rsync -av --delete "$REPO_DIR/server/" "$APP_DIR/server/"

# クライアントファイルの同期
echo "[3/4] クライアントファイルを同期中..."
rsync -av --delete "$REPO_DIR/export/" "$APP_DIR/export/"

# 依存パッケージの更新
"$APP_DIR/venv/bin/pip" install -q -r "$APP_DIR/server/requirements.txt"

# 所有権の再設定
chown -R modern-art:modern-art "$APP_DIR/server" "$APP_DIR/export"

# SELinux コンテキストの再適用
if command -v restorecon &>/dev/null; then
    restorecon -Rv "$APP_DIR/export" > /dev/null 2>&1 || true
fi

# サーバーの再起動
echo "[4/4] サーバーを再起動中..."
systemctl restart modern-art

echo ""
echo "=== 更新完了 ==="
systemctl status modern-art --no-pager
