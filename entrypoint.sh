#!/bin/sh
# ==============================
# CLIProxyAPI Choreo entrypoint
# Web Application + Postgres store + /tmp
# ==============================

set -e

KOMARI_SERVER="${KOMARI_SERVER:-}"
KOMARI_SECRET="${KOMARI_SECRET:-}"

export HOME="${HOME:-/tmp}"
export TZ="${TZ:-Asia/Shanghai}"

# Choreo 只读根 FS：本地缓存与管理静态资源必须可写
export MANAGEMENT_STATIC_PATH="${MANAGEMENT_STATIC_PATH:-/tmp}"
export PGSTORE_LOCAL_PATH="${PGSTORE_LOCAL_PATH:-/tmp}"
export GITSTORE_LOCAL_PATH="${GITSTORE_LOCAL_PATH:-/tmp}"
export OBJECTSTORE_LOCAL_PATH="${OBJECTSTORE_LOCAL_PATH:-/tmp}"

# ==============================
# 1. 可写目录（Choreo 只读 FS → /tmp）
# ==============================
echo "[Init] Preparing /tmp paths..."
mkdir -p \
    /tmp/.cli-proxy-api \
    /tmp/.config \
    /tmp/.local/share \
    /tmp/cli-proxy-api/logs \
    /tmp/cli-proxy-api/plugins \
    "$MANAGEMENT_STATIC_PATH" \
    "$PGSTORE_LOCAL_PATH" \
    "$GITSTORE_LOCAL_PATH" \
    "$OBJECTSTORE_LOCAL_PATH"

# ==============================
# 2. 远程存储检查（不打印密钥）
# ==============================
if [ -n "${PGSTORE_DSN:-}" ]; then
    dsn_shape=$(printf '%s' "$PGSTORE_DSN" | sed -E 's#://[^@/]+@#://***:***@#')
    echo "[Store] PGSTORE_DSN set shape=${dsn_shape}"
    echo "[Store] PGSTORE_LOCAL_PATH=${PGSTORE_LOCAL_PATH} schema=${PGSTORE_SCHEMA:-public}"
elif [ -n "${OBJECTSTORE_ENDPOINT:-}" ] && [ -n "${OBJECTSTORE_BUCKET:-}" ]; then
    echo "[Store] Object store endpoint=${OBJECTSTORE_ENDPOINT} bucket=${OBJECTSTORE_BUCKET}"
    echo "[Store] OBJECTSTORE_LOCAL_PATH=${OBJECTSTORE_LOCAL_PATH}"
elif [ -n "${GITSTORE_GIT_URL:-}" ]; then
    echo "[Store] Git store url=${GITSTORE_GIT_URL}"
    echo "[Store] GITSTORE_LOCAL_PATH=${GITSTORE_LOCAL_PATH}"
else
    echo "[WARN] No remote store configured (PGSTORE_DSN / OBJECTSTORE_* / GITSTORE_*)."
    echo "[WARN] Auth tokens under /tmp are ephemeral on Choreo; set PGSTORE_DSN for production."
fi

if [ -z "${MANAGEMENT_PASSWORD:-}" ]; then
    echo "[WARN] MANAGEMENT_PASSWORD is empty; management WebUI may reject login."
fi

echo "[Init] MANAGEMENT_STATIC_PATH=${MANAGEMENT_STATIC_PATH}"
echo "[Init] HOME=${HOME}"

# ==============================
# 3. KOMARI_SERVER + KOMARI_SECRET 都非空时启动
# ==============================
if [ -n "$KOMARI_SERVER" ] && [ -n "$KOMARI_SECRET" ]; then
    if [ -x /app/komari-agent ]; then
        echo "[Komari] Starting agent -> ${KOMARI_SERVER}"
        /app/komari-agent \
            -e "$KOMARI_SERVER" \
            -t "$KOMARI_SECRET" \
            --disable-auto-update >/dev/null 2>&1 &
    else
        echo "[Komari] WARN: /app/komari-agent missing or not executable, skip."
    fi
else
    echo "[Komari] Not configured (need KOMARI_SERVER + KOMARI_SECRET), skip."
fi

# ==============================
# 4. 启动 CLIProxyAPI
# ==============================
cd /CLIProxyAPI

echo "[CPA] Starting CLIProxyAPI on :8317..."

if [ "$#" -gt 0 ]; then
    exec "$@"
fi

if [ -x ./CLIProxyAPI ]; then
    exec ./CLIProxyAPI
fi

if [ -x /CLIProxyAPI/CLIProxyAPI ]; then
    exec /CLIProxyAPI/CLIProxyAPI
fi

echo "[ERROR] CLIProxyAPI binary not found under /CLIProxyAPI"
ls -la /CLIProxyAPI || true
exit 1
