#!/bin/bash
# Modern Art - VPS 初期セットアップスクリプト (Rocky Linux)
# 既存の elefolo2.com サーバーに追加する形でセットアップします
#
# 前提条件:
#   - Nginx が稼働中で elefolo2.com の HTTPS が設定済み
#   - Python 3 がインストール済み
#
# 使い方:
#   root または sudo 権限で実行: bash setup-vps.sh

set -euo pipefail

# === 設定 (環境に合わせて変更) ===
REPO_URL="${REPO_URL:-https://github.com/YOUR_USER/modern-art_elefolo2.git}"
APP_DIR="/opt/modern-art"
APP_USER="modern-art"
NGINX_CONF_DIR="${NGINX_CONF_DIR:-/etc/nginx}"

echo "============================================"
echo " Modern Art VPS セットアップ"
echo " URL: https://elefolo2.com/games/modern-art"
echo "============================================"

# === 1. 追加パッケージのインストール ===
echo ""
echo "=== 1/7 パッケージの確認 ==="
dnf install -y python3 python3-pip git policycoreutils-python-utils rsync

# === 2. アプリケーションユーザーの作成 ===
echo ""
echo "=== 2/7 アプリケーションユーザーの作成 ==="
if ! id "$APP_USER" &>/dev/null; then
    useradd --system --shell /sbin/nologin --home-dir "$APP_DIR" "$APP_USER"
    echo "  ユーザー '$APP_USER' を作成しました"
else
    echo "  ユーザー '$APP_USER' は既に存在します"
fi

# === 3. リポジトリのクローン ===
echo ""
echo "=== 3/7 リポジトリのクローン ==="
mkdir -p "$APP_DIR"
if [ ! -d "$APP_DIR/repo/.git" ]; then
    git clone "$REPO_URL" "$APP_DIR/repo"
    echo "  リポジトリをクローンしました"
else
    cd "$APP_DIR/repo" && git pull origin main
    echo "  リポジトリを更新しました"
fi

# === 4. ファイルの配置 ===
echo ""
echo "=== 4/7 ファイルの配置 ==="
mkdir -p "$APP_DIR"/{server,export}
rsync -av --delete "$APP_DIR/repo/server/" "$APP_DIR/server/"
rsync -av --delete "$APP_DIR/repo/export/" "$APP_DIR/export/"

# === 5. Python 仮想環境のセットアップ ===
echo ""
echo "=== 5/7 Python 仮想環境のセットアップ ==="
if [ ! -d "$APP_DIR/venv" ]; then
    python3 -m venv "$APP_DIR/venv"
    echo "  仮想環境を作成しました"
fi
"$APP_DIR/venv/bin/pip" install --upgrade pip
"$APP_DIR/venv/bin/pip" install -r "$APP_DIR/server/requirements.txt"

# === 6. 所有権と SELinux ===
echo ""
echo "=== 6/7 所有権と SELinux の設定 ==="
chown -R "$APP_USER":"$APP_USER" "$APP_DIR"

if command -v getenforce &>/dev/null && [ "$(getenforce)" != "Disabled" ]; then
    # Nginx がバックエンドサーバーに接続できるようにする
    setsebool -P httpd_can_network_connect 1
    # 静的ファイルに正しいコンテキストを設定
    semanage fcontext -a -t httpd_sys_content_t "$APP_DIR/export(/.*)?" 2>/dev/null || true
    restorecon -Rv "$APP_DIR/export"
    echo "  SELinux を設定しました"
else
    echo "  SELinux は無効です (スキップ)"
fi

# === 7. systemd サービスの設定 ===
echo ""
echo "=== 7/7 systemd サービスと Nginx の設定 ==="
cp "$APP_DIR/repo/deploy/modern-art.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable modern-art
systemctl start modern-art
echo "  サービスを起動しました"

# Nginx 設定を配置
cp "$APP_DIR/repo/deploy/nginx-modern-art.conf" "$NGINX_CONF_DIR/conf.d/modern-art.conf"
nginx -t && systemctl reload nginx
echo "  Nginx 設定を追加しました"

echo ""
echo "============================================"
echo " セットアップ完了!"
echo "============================================"
echo ""
echo "サーバー状態:"
systemctl status modern-art --no-pager || true
echo ""
echo "アクセス URL: https://elefolo2.com/games/modern-art"
echo ""
echo "次のステップ:"
echo "  1. 既存の Nginx server ブロック内に modern-art.conf を include:"
echo "     server {"
echo "         listen 443 ssl;"
echo "         server_name elefolo2.com;"
echo "         ..."
echo "         include /etc/nginx/conf.d/modern-art.conf;"
echo "     }"
echo "  2. nginx -t && systemctl reload nginx"
echo "  3. ブラウザで https://elefolo2.com/games/modern-art にアクセス"
echo "  4. ログ確認: journalctl -u modern-art -f"
