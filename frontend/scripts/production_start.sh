#!/bin/bash
# =============================================================================
# LLM_QUOTATION 前端服务 - 生产环境启动脚本
# 用于 systemd 服务调用
# =============================================================================

set -e

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${FRONTEND_DIR}/logs"
PID_FILE="${FRONTEND_DIR}/frontend.pid"

# 默认配置（可通过环境变量覆盖）
PORT=${FRONTEND_PORT:-3000}
HOST=${FRONTEND_HOST:-"0.0.0.0"}

# 确保目录存在
mkdir -p "$LOG_DIR"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 日志目录已就绪: $LOG_DIR"

# 切换到前端目录
cd "$FRONTEND_DIR"

# 检查 Node.js 是否安装
if ! command -v node &> /dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Node.js 未安装"
    exit 1
fi

# 检查 npm 是否安装
if ! command -v npm &> /dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] npm 未安装"
    exit 1
fi

# 安装依赖（如果需要）
if [ ! -d "node_modules" ] || [ -z "$(ls -A node_modules 2>/dev/null)" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 安装前端依赖..."
    npm install --silent
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] 依赖安装完成"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 启动前端开发服务器..."
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 监听地址: ${HOST}:${PORT}"

# 首先构建前端应用
npm run build

# 使用 Express 代理服务器启动前端应用
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 启动前端代理服务器..."
node server.js