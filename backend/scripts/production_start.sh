#!/bin/bash
# =============================================================================
# LLM_QUOTATION 后端服务 - 生产环境启动脚本
# 用于 systemd 服务调用
# =============================================================================

set -e

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="${BACKEND_DIR}/venv"
LOG_DIR="${BACKEND_DIR}/logs"
PID_FILE="${BACKEND_DIR}/gunicorn.pid"

# 默认配置（可通过环境变量覆盖）
WORKERS=${GUNICORN_WORKERS:-4}
WORKER_CLASS=${GUNICORN_WORKER_CLASS:-"uvicorn.workers.UvicornWorker"}
BIND_HOST=${BIND_HOST:-"0.0.0.0"}
BIND_PORT=${BIND_PORT:-8000}
TIMEOUT=${GUNICORN_TIMEOUT:-120}
GRACEFUL_TIMEOUT=${GUNICORN_GRACEFUL_TIMEOUT:-30}
KEEPALIVE=${GUNICORN_KEEPALIVE:-5}
MAX_REQUESTS=${GUNICORN_MAX_REQUESTS:-10000}
MAX_REQUESTS_JITTER=${GUNICORN_MAX_REQUESTS_JITTER:-1000}

# 日志配置
ACCESS_LOG="${LOG_DIR}/access.log"
ERROR_LOG="${LOG_DIR}/error.log"

# 颜色输出
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

# 确保目录存在
ensure_directories() {
    mkdir -p "$LOG_DIR"
    log_info "日志目录已就绪: $LOG_DIR"
}

# 切换到项目目录
cd "$BACKEND_DIR"

# 激活虚拟环境
if [ -d "$VENV_DIR" ]; then
    source "${VENV_DIR}/bin/activate"
    log_info "虚拟环境已激活"
else
    log_error "虚拟环境不存在: $VENV_DIR"
    exit 1
fi

# 检查 .env 文件
if [ ! -f "${BACKEND_DIR}/.env" ]; then
    log_error ".env 配置文件不存在"
    exit 1
fi

# 确保目录存在
ensure_directories

# 设置 Python 环境变量
export PYTHONPATH="${BACKEND_DIR}:${PYTHONPATH}"
export PYTHONUNBUFFERED=1

log_info "启动 Gunicorn 服务..."
log_info "Workers: $WORKERS"
log_info "绑定地址: ${BIND_HOST}:${BIND_PORT}"

# 使用 Gunicorn 启动应用
gunicorn main:app \
    --workers "$WORKERS" \
    --worker-class "$WORKER_CLASS" \
    --bind "${BIND_HOST}:${BIND_PORT}" \
    --timeout "$TIMEOUT" \
    --graceful-timeout "$GRACEFUL_TIMEOUT" \
    --keep-alive "$KEEPALIVE" \
    --max-requests "$MAX_REQUESTS" \
    --max-requests-jitter "$MAX_REQUESTS_JITTER" \
    --access-logfile "$ACCESS_LOG" \
    --error-logfile "$ERROR_LOG" \
    --capture-output \
    --enable-stdio-inheritance \
    --preload \
    --log-level info
