#!/bin/bash
# =============================================================================
# LLM_QUOTATION 前端服务管理脚本
# 
# 用法: ./service_manager.sh [命令]
#
# 命令:
#   install   - 安装并配置 systemd 服务
#   uninstall - 卸载服务
#   start     - 启动服务
#   stop      - 停止服务
#   restart   - 重启服务
#   status    - 查看服务状态
#   logs      - 查看实时日志
#   deploy    - 完整部署（安装依赖 + 安装服务 + 启动）
# =============================================================================

set -e

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$(dirname "$SCRIPT_DIR")"
SERVICE_NAME="llm-quotation-frontend"
SERVICE_FILE="${SCRIPT_DIR}/${SERVICE_NAME}.service"
SYSTEMD_DIR="/etc/systemd/system"
LOGROTATE_FILE="${SCRIPT_DIR}/llm-quotation-frontend-logrotate"
LOGROTATE_DIR="/etc/logrotate.d"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 打印函数
print_header() {
    echo -e "${CYAN}"
    echo "=============================================="
    echo "  LLM_QUOTATION 前端服务管理"
    echo "=============================================="
    echo -e "${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否以 root 运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用 sudo 运行此脚本"
        exit 1
    fi
}

# 安装服务
install_service() {
    check_root
    print_info "安装前端 systemd 服务..."
    
    # 复制服务文件
    if [ -f "$SERVICE_FILE" ]; then
        cp "$SERVICE_FILE" "${SYSTEMD_DIR}/${SERVICE_NAME}.service"
        print_success "服务文件已复制到 ${SYSTEMD_DIR}"
    else
        print_error "服务文件不存在: $SERVICE_FILE"
        exit 1
    fi
    
    # 设置启动脚本权限
    chmod +x "${SCRIPT_DIR}/production_start.sh"
    print_success "启动脚本权限已设置"
    
    # 安装日志轮转配置
    if [ -f "$LOGROTATE_FILE" ]; then
        cp "$LOGROTATE_FILE" "${LOGROTATE_DIR}/llm-quotation-frontend"
        print_success "日志轮转配置已安装"
    fi
    
    # 重新加载 systemd
    systemctl daemon-reload
    print_success "systemd 配置已重新加载"
    
    # 启用开机自启
    systemctl enable "$SERVICE_NAME"
    print_success "服务已设置为开机自启"
    
    print_success "前端服务安装完成！"
    echo ""
    print_info "使用以下命令管理服务:"
    echo "  启动: sudo systemctl start $SERVICE_NAME"
    echo "  停止: sudo systemctl stop $SERVICE_NAME"
    echo "  状态: sudo systemctl status $SERVICE_NAME"
    echo "  日志: sudo journalctl -u $SERVICE_NAME -f"
}

# 卸载服务
uninstall_service() {
    check_root
    print_info "卸载前端 systemd 服务..."
    
    # 停止服务
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
        print_success "服务已停止"
    fi
    
    # 禁用开机自启
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl disable "$SERVICE_NAME"
        print_success "已禁用开机自启"
    fi
    
    # 删除服务文件
    if [ -f "${SYSTEMD_DIR}/${SERVICE_NAME}.service" ]; then
        rm "${SYSTEMD_DIR}/${SERVICE_NAME}.service"
        print_success "服务文件已删除"
    fi
    
    # 删除日志轮转配置
    if [ -f "${LOGROTATE_DIR}/llm-quotation-frontend" ]; then
        rm "${LOGROTATE_DIR}/llm-quotation-frontend"
        print_success "日志轮转配置已删除"
    fi
    
    # 重新加载 systemd
    systemctl daemon-reload
    print_success "前端服务卸载完成"
}

# 启动服务
start_service() {
    check_root
    print_info "启动前端服务..."
    systemctl start "$SERVICE_NAME"
    sleep 2
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "前端服务已启动"
        show_status
    else
        print_error "前端服务启动失败"
        systemctl status "$SERVICE_NAME" --no-pager
        exit 1
    fi
}

# 停止服务
stop_service() {
    check_root
    print_info "停止前端服务..."
    systemctl stop "$SERVICE_NAME"
    print_success "前端服务已停止"
}

# 重启服务
restart_service() {
    check_root
    print_info "重启前端服务..."
    systemctl restart "$SERVICE_NAME"
    sleep 2
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "前端服务已重启"
        show_status
    else
        print_error "前端服务重启失败"
        exit 1
    fi
}

# 显示状态
show_status() {
    echo ""
    print_info "前端服务状态:"
    systemctl status "$SERVICE_NAME" --no-pager || true
    echo ""
}

# 查看日志
show_logs() {
    print_info "显示前端实时日志 (按 Ctrl+C 退出)..."
    journalctl -u "$SERVICE_NAME" -f
}

# 完整部署
full_deploy() {
    check_root
    print_header
    
    print_info "开始前端完整部署..."
    echo ""
    
    # 1. 进入前端目录
    cd "$FRONTEND_DIR"
    
    # 2. 创建日志目录
    mkdir -p logs
    print_success "日志目录已创建"
    
    # 3. 安装依赖
    if [ ! -d "node_modules" ] || [ -z "$(ls -A node_modules 2>/dev/null)" ]; then
        print_info "安装前端依赖..."
        npm install --silent
        print_success "依赖安装完成"
    else
        print_info "依赖已存在，跳过安装"
    fi
    
    # 4. 构建前端（可选，如果是生产模式）
    print_info "构建前端应用..."
    npm run build 2>/dev/null || print_warning "构建跳过或失败"
    
    # 5. 安装服务
    install_service
    
    # 6. 启动服务
    start_service
    
    echo ""
    print_success "前端部署完成！"
    echo ""
    print_info "服务信息:"
    echo "  - 访问地址: http://服务器IP:3000"
    echo "  - 代理后端API: http://服务器IP:8000/api/v1"
    echo ""
    print_info "管理命令:"
    echo "  - 状态:   sudo $0 status"
    echo "  - 重启:   sudo $0 restart"
    echo "  - 日志:   sudo $0 logs"
}

# 显示帮助
show_help() {
    print_header
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  install   - 安装并配置 systemd 服务"
    echo "  uninstall - 卸载服务"
    echo "  start     - 启动服务"
    echo "  stop      - 停止服务"
    echo "  restart   - 重启服务"
    echo "  status    - 查看服务状态"
    echo "  logs      - 查看实时日志"
    echo "  deploy    - 完整部署（安装依赖 + 安装服务 + 启动）"
    echo ""
    echo "示例:"
    echo "  sudo $0 deploy    # 首次完整部署"
    echo "  sudo $0 restart   # 重启服务"
    echo "  $0 status         # 状态检查（无需 sudo）"
}

# 主函数
main() {
    case "${1:-}" in
        install)
            install_service
            ;;
        uninstall)
            uninstall_service
            ;;
        start)
            start_service
            ;;
        stop)
            stop_service
            ;;
        restart)
            restart_service
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        deploy)
            full_deploy
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"