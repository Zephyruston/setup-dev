#!/bin/bash

# =============================================================================
# 服务器初始化脚本
# 功能：安装和配置基础服务器环境
# 支持：fish shell, tmux, frp, SSH端口修改, nginx
# 作者：AI Assistant
# 版本：1.0
# =============================================================================

set -euo pipefail  # 严格错误处理

# =============================================================================
# 颜色定义和输出函数
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 彩色输出函数（同时输出到终端和日志文件）
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$LOG_FILE"
}

# =============================================================================
# 配置变量
# =============================================================================
SCRIPT_NAME=$(basename "$0")
BACKUP_DIR="/var/backups/server-setup"
LOG_FILE="/var/log/server-init.log"

# 创建日志文件（如果不存在）并设置权限
touch "$LOG_FILE" 2>/dev/null || true
chmod 644 "$LOG_FILE" 2>/dev/null || true

# 安装配置
SSH_NEW_PORT=5022
FRP_VERSION="0.65.0"
FRP_ARCH="linux_amd64"

# 获取执行脚本的用户主目录，而不是root用户目录
if [[ -n "${SUDO_USER:-}" ]]; then
    USER_HOME=$(eval echo ~"${SUDO_USER}")
else
    USER_HOME=$HOME
fi

# =============================================================================
# 帮助文档
# =============================================================================
usage() {
    cat << EOF
用法: $SCRIPT_NAME [选项]

服务器初始化脚本，用于安装和配置基础服务环境。

选项:
    -h, --help          显示此帮助信息
    -s, --skip-checks   跳过系统检查
    -d, --dry-run       模拟运行，不实际执行操作
    -b, --backup-only   仅创建备份，不进行安装
    -c, --config-only   仅进行配置，跳过安装
    -v, --verbose       详细输出
    --skip-fish         跳过 Fish Shell 安装
    --skip-tmux         跳过 Tmux 安装和配置
    --skip-frp          跳过 FRP 安装
    --skip-ssh          跳过 SSH 端口修改
    --skip-nginx        跳过 Nginx 安装
    --skip-frps         跳过 FRP 服务端配置

示例:
    $SCRIPT_NAME                    # 标准安装
    $SCRIPT_NAME --dry-run          # 模拟运行
    $SCRIPT_NAME --skip-checks      # 跳过系统检查
    $SCRIPT_NAME --skip-ssh         # 跳过 SSH 配置

支持的功能模块:
    1. Fish Shell 安装配置
    2. Tmux 安装和配置
    3. FRP 服务安装
    4. SSH 端口修改
    5. Nginx 安装
    6. FRP 服务端 (frps) 配置

注意: 此脚本需要 root 权限运行。
EOF
}

# =============================================================================
# 参数解析
# =============================================================================
SKIP_CHECKS=false
DRY_RUN=false
BACKUP_ONLY=false
CONFIG_ONLY=false
VERBOSE=false
SKIP_FISH=false
SKIP_TMUX=false
SKIP_FRP=false
SKIP_SSH=false
SKIP_NGINX=false
SKIP_FRPS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -s|--skip-checks)
            SKIP_CHECKS=true
            ;;
        -d|--dry-run)
            DRY_RUN=true
            ;;
        -b|--backup-only)
            BACKUP_ONLY=true
            ;;
        -c|--config-only)
            CONFIG_ONLY=true
            ;;
        -v|--verbose)
            VERBOSE=true
            ;;
        --skip-fish)
            SKIP_FISH=true
            ;;
        --skip-tmux)
            SKIP_TMUX=true
            ;;
        --skip-frp)
            SKIP_FRP=true
            ;;
        --skip-ssh)
            SKIP_SSH=true
            ;;
        --skip-nginx)
            SKIP_NGINX=true
            ;;
        --skip-frps)
            SKIP_FRPS=true
            ;;
        *)
            log_error "未知参数: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

# =============================================================================
# 通用函数
# =============================================================================

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        log_error "请使用 sudo 运行此脚本"
        exit 1
    fi
}

# 系统检查
system_checks() {
    log_info "执行系统检查..."

    # 检查系统版本
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法检测操作系统"
        exit 1
    fi

    # shellcheck disable=SC1091  # 忽略source检查
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        log_warning "此脚本主要针对 Ubuntu 系统测试，当前系统: $ID"
    fi

    # 检查Ubuntu版本
    if [[ "$VERSION_ID" != "22.04" ]]; then
        log_warning "此脚本在 Ubuntu 22.04 上测试，当前版本: $VERSION_ID"
    fi

    # 检查网络连接
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] 检查网络连接: ping -c 1 -W 3 github.com"
    else
        if ! ping -c 1 -W 3 github.com &> /dev/null; then
            log_warning "网络连接检查失败，请确保网络正常"
            log_warning "某些需要下载的功能可能无法正常工作"
        else
            log_success "网络连接正常"
        fi
    fi

    log_success "系统检查完成"
}

# 备份文件
backup_file() {
    local file="$1"
    local backup_path

    backup_path="$BACKUP_DIR/$(basename "$file").$(date +%Y%m%d_%H%M%S).bak"

    if [[ -f "$file" ]]; then
        run_cmd mkdir -p "$BACKUP_DIR"
        run_cmd cp "$file" "$backup_path"
        log_info "已备份 $file 到 $backup_path"
    fi
}

# 执行命令（支持dry-run模式）
run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] 执行: $*"
    else
        if [[ "$VERBOSE" == true ]]; then
            log_info "执行: $*"
        fi
        "$@"
    fi
}

# 执行shell命令（支持dry-run模式，用于管道、重定向等）
run_shell_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] 执行shell命令: $1"
    else
        if [[ "$VERBOSE" == true ]]; then
            log_info "执行shell命令: $1"
        fi
        eval "$1"
    fi
}

# 安装包
install_package() {
    local package="$1"
    log_info "安装包: $package"

    if dpkg -l | grep -q "^ii  $package "; then
        log_info "包 $package 已经安装"
        return 0
    fi

    run_cmd apt-get install -y "$package"
}

# =============================================================================
# 功能模块
# =============================================================================

# 模块1: 安装 Fish Shell
install_fish() {
    log_info "开始安装 Fish Shell..."

    # 添加 Fish Shell PPA
    log_info "添加 Fish Shell PPA 仓库..."
    run_cmd apt-add-repository -y ppa:fish-shell/release-4
    run_cmd apt update

    # 安装 Fish
    install_package fish

    log_success "Fish Shell 安装完成"
}

# 模块2: 安装和配置 Tmux
install_tmux() {
    log_info "开始安装和配置 Tmux..."

    install_package tmux
    install_package git

    # 使用 gpakosz 的 .tmux 配置
    local tmux_conf_dir="$USER_HOME/.tmux"
    local tmux_conf="$USER_HOME/.tmux.conf"

    # 备份现有配置（只有在配置存在时才备份）
    if [[ -f "$tmux_conf" ]] || [[ -d "$tmux_conf_dir" ]]; then
        backup_file "$tmux_conf"
        [[ -d "$tmux_conf_dir" ]] && backup_file "$tmux_conf_dir"
    fi

    # 克隆 gpakosz 的 .tmux 配置
    log_info "克隆 gpakosz 的 .tmux 配置..."
    run_cmd git clone --single-branch https://github.com/gpakosz/.tmux.git "$tmux_conf_dir"

    # 创建 .tmux.conf 符号链接
    log_info "创建 .tmux.conf 符号链接..."
    if [[ -L "$tmux_conf" || -f "$tmux_conf" ]]; then
        run_cmd rm -f "$tmux_conf"
    fi
    run_cmd ln -s -f "$tmux_conf_dir/.tmux.conf" "$tmux_conf"

    # 复制 .tmux.conf.local 示例配置
    log_info "复制 .tmux.conf.local 配置文件..."
    run_cmd cp "$tmux_conf_dir/.tmux.conf.local" "$USER_HOME/.tmux.conf.local"

    log_success "Tmux 安装配置完成"
}

# 模块3: 安装 FRP
install_frp() {
    log_info "开始安装 FRP..."

    local temp_dir="/tmp/frp_install"
    local frp_package="frp_${FRP_VERSION}_${FRP_ARCH}.tar.gz"
    local frp_url="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/$frp_package"

    # 创建临时目录
    run_cmd mkdir -p "$temp_dir"

    # 下载FRP
    log_info "下载 FRP v$FRP_VERSION"
    run_cmd wget -q "$frp_url" -O "/tmp/$frp_package"

    # 解压到临时目录
    log_info "解压 FRP 到临时目录"
    run_cmd tar -xzf "/tmp/$frp_package" -C "$temp_dir"

    # 获取实际的解压目录名称
    local extracted_dir="$temp_dir/frp_${FRP_VERSION}_${FRP_ARCH}"

    # 复制二进制文件到 /usr/local/bin
    run_cmd cp "$extracted_dir/frps" "/usr/local/bin/frps"
    run_cmd cp "$extracted_dir/frpc" "/usr/local/bin/frpc"

    # 清理临时文件
    run_cmd rm -rf "$temp_dir"
    run_cmd rm -f "/tmp/$frp_package"

    log_success "FRP 安装完成"
    log_info "FRP 二进制文件已安装到 /usr/local/bin"
    log_info "可执行文件: /usr/local/bin/frps (服务端) 和 /usr/local/bin/frpc (客户端)"
}

# 模块4: 修改SSH端口
configure_ssh() {
    log_info "开始配置 SSH..."

    local ssh_config="/etc/ssh/sshd_config"
    backup_file "$ssh_config"

    # 检查端口是否已被修改
    if grep -q "^Port $SSH_NEW_PORT" "$ssh_config"; then
        log_info "SSH 端口已经是 $SSH_NEW_PORT"
        return 0
    fi

    # 备份原配置并修改端口
    if [[ -f "$ssh_config" ]]; then
        # 如果已有Port配置，则修改它
        if grep -q "^Port " "$ssh_config"; then
            sed -i "s/^Port .*/Port $SSH_NEW_PORT/" "$ssh_config"
        else
            # 如果没有Port配置，在文件开头添加
            sed -i "1iPort $SSH_NEW_PORT" "$ssh_config"
        fi

        # 确保注释掉原来的Port 22（如果有）
        sed -i "s/^#Port 22/Port $SSH_NEW_PORT/" "$ssh_config"
    else
        log_error "SSH 配置文件不存在: $ssh_config"
        return 1
    fi

    log_success "SSH 端口已修改为 $SSH_NEW_PORT"
    log_warning "请重启 SSH 服务: systemctl restart ssh"
}

# 模块5: 安装和配置 Nginx
install_nginx() {
    log_info "开始安装 Nginx..."

    # 安装 prerequisites
    log_info "安装 Nginx 依赖项..."
    install_package curl
    install_package gnupg2
    install_package ca-certificates
    install_package lsb-release
    install_package ubuntu-keyring

    # 导入 nginx 签名密钥
    log_info "导入 Nginx 签名密钥..."
    run_shell_cmd "curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null"

    # 设置 apt 仓库
    log_info "设置 Nginx APT 仓库..."
    local release_codename
    release_codename=$(lsb_release -cs)
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu $release_codename nginx" | tee /etc/apt/sources.list.d/nginx.list

    # 设置仓库优先级
    echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | tee /etc/apt/preferences.d/99nginx

    # 安装 nginx
    log_info "安装 Nginx..."
    run_cmd apt update
    install_package nginx

    log_success "Nginx 安装完成"
}

# 模块6: 配置 FRP 服务端 (frps)
configure_frps() {
    log_info "开始配置 FRP 服务端 (frps)..."

    # 确保用户主目录存在
    if [[ ! -d "$USER_HOME" ]]; then
        log_error "用户主目录不存在: $USER_HOME"
        return 1
    fi

    # 检查 FRP 是否已安装
    if [[ ! -f "/usr/local/bin/frps" ]]; then
        log_warning "FRP 未安装，但将继续创建配置文件"
        log_info "配置文件将创建在 $USER_HOME/.frp/frps.toml"
        log_info "你可以手动安装 FRP 后使用这些配置"
    fi

    # 创建 FRP 目录和配置文件目录
    run_cmd mkdir -p "$USER_HOME/.frp"
    run_cmd mkdir -p "/etc/systemd/system"

    # 备份现有配置文件（如果存在）
    backup_file "$USER_HOME/.frp/frps.toml"

    # 创建 frps.toml 配置文件
    cat > "$USER_HOME/.frp/frps.toml" << 'EOF'
bindPort = 7000
EOF

    # 确保配置文件权限正确
    chown "${SUDO_USER:-root}:${SUDO_USER:-root}" "$USER_HOME/.frp/frps.toml" 2>/dev/null || true
    chmod 644 "$USER_HOME/.frp/frps.toml"

    log_info "FRP 服务端配置文件已创建: $USER_HOME/.frp/frps.toml"
    log_info "配置路径: $USER_HOME/.frp/frps.toml"

    # 只在 FRP 已安装时创建 systemd 服务
    if [[ -f "/usr/local/bin/frps" ]]; then
        # 备份现有的 frps.service 文件（如果存在）
        backup_file "/etc/systemd/system/frps.service"

        # 创建 frps.service 文件（使用正确的绝对路径）
        local frps_config_path="${USER_HOME}/.frp/frps.toml"
        cat > "/etc/systemd/system/frps.service" << EOF
[Unit]
Description = frp server
After = network.target syslog.target
Wants = network.target

[Service]
Type = simple
ExecStart = /usr/local/bin/frps -c ${frps_config_path}

[Install]
WantedBy = multi-user.target
EOF

        log_info "FRP 服务配置文件已创建: /etc/systemd/system/frps.service"
        log_info "服务将使用配置文件: ${frps_config_path}"

        # 重新加载 systemd 配置
        run_cmd systemctl daemon-reload

        # 启用 frps 服务自启动
        run_cmd systemctl enable frps

        # 启动 frps 服务
        run_cmd systemctl start frps

        log_success "FRP 服务端 (frps) 配置完成"
        log_info "FRP 服务端已设置为开机自启动"
        log_info "默认监听端口: 7000"
    else
        log_info "FRP 未安装，跳过 systemd 服务配置"
        log_info "你可以手动安装 FRP 后运行: systemctl enable --now frps"
    fi
}

# =============================================================================
# 备份功能
# =============================================================================
create_backups() {
    log_info "创建配置文件备份..."

    local files_to_backup=()

    # 只备份实际需要修改的配置文件
    if [[ "$SKIP_SSH" == false ]]; then
        files_to_backup+=("/etc/ssh/sshd_config")
    fi

    if [[ "$SKIP_TMUX" == false ]]; then
        files_to_backup+=("$USER_HOME/.tmux.conf")
    fi

    if [[ "$SKIP_NGINX" == false ]]; then
        files_to_backup+=("/etc/nginx/nginx.conf")
    fi

    for file in "${files_to_backup[@]}"; do
        if [[ -f "$file" ]]; then
            backup_file "$file"
        fi
    done

    log_success "备份完成"
}

# =============================================================================
# 安装后检查
# =============================================================================
post_install_checks() {
    log_info "执行安装后检查..."

    # 检查服务状态（只检查实际安装的服务）
    if [[ "$SKIP_NGINX" == false ]]; then
        if systemctl is-active --quiet "nginx"; then
            log_success "服务 nginx 运行正常"
        else
            log_warning "服务 nginx 未运行"
        fi
    fi

    # SSH 服务总是检查（系统默认）
    if systemctl is-active --quiet "ssh"; then
        log_success "服务 ssh 运行正常"
    else
        log_warning "服务 ssh 未运行"
    fi

    # FRP 服务状态检查（只在配置了frps服务时检查）
    if [[ "$SKIP_FRPS" == false ]] && [[ -f "/usr/local/bin/frps" ]]; then
        if systemctl is-active --quiet "frps"; then
            log_success "服务 frps 运行正常"
        else
            log_warning "服务 frps 未运行"
        fi
    fi

    # 检查安装的程序（只检查实际安装的）
    if [[ "$SKIP_FISH" == false ]]; then
        if command -v "fish" &> /dev/null; then
            log_success "程序 fish 安装成功"
        else
            log_error "程序 fish 安装失败"
        fi
    fi

    if [[ "$SKIP_TMUX" == false ]]; then
        if command -v "tmux" &> /dev/null; then
            log_success "程序 tmux 安装成功"
        else
            log_error "程序 tmux 安装失败"
        fi
    fi

    if [[ "$SKIP_NGINX" == false ]]; then
        if command -v "nginx" &> /dev/null; then
            log_success "程序 nginx 安装成功"
        else
            log_error "程序 nginx 安装失败"
        fi
    fi

    # 检查 FRP 是否安装（如果未跳过）
    if [[ "$SKIP_FRP" == false ]]; then
        if [[ -f "/usr/local/bin/frps" ]]; then
            log_success "FRP 安装成功"
        else
            log_error "FRP 安装失败"
        fi
    fi

    log_success "安装后检查完成"
}

# =============================================================================
# 主函数
# =============================================================================
main() {
    log_info "开始服务器初始化流程..."

    # 权限检查
    check_root

    # 系统检查（除非跳过）
    if [[ "$SKIP_CHECKS" == false ]]; then
        system_checks
    fi

    # 创建备份
    create_backups

    # 如果仅备份则退出
    if [[ "$BACKUP_ONLY" == true ]]; then
        log_success "仅备份模式完成"
        exit 0
    fi

    # 安装阶段（除非仅配置）
    if [[ "$CONFIG_ONLY" == false ]]; then
        log_info "开始安装软件包..."

        # 更新包列表（除非所有安装都被跳过）
        if [[ "$SKIP_FISH" == false ]] || [[ "$SKIP_TMUX" == false ]] || [[ "$SKIP_FRP" == false ]] || [[ "$SKIP_NGINX" == false ]]; then
            run_cmd apt-get update
        fi

        # 执行安装模块（根据skip选项）
        if [[ "$SKIP_FISH" == false ]]; then
            install_fish
        else
            log_info "跳过 Fish Shell 安装"
        fi

        if [[ "$SKIP_TMUX" == false ]]; then
            install_tmux
        else
            log_info "跳过 Tmux 安装和配置"
        fi

        if [[ "$SKIP_FRP" == false ]]; then
            install_frp
        else
            log_info "跳过 FRP 安装"
        fi

        if [[ "$SKIP_NGINX" == false ]]; then
            install_nginx
        else
            log_info "跳过 Nginx 安装"
        fi
    fi

    # 配置阶段
    log_info "开始配置服务..."

    if [[ "$SKIP_SSH" == false ]]; then
        configure_ssh
    else
        log_info "跳过 SSH 端口修改"
    fi

    if [[ "$SKIP_FRPS" == false ]]; then
        configure_frps
    else
        log_info "跳过 FRP 服务端配置"
    fi

    # 安装后检查
    post_install_checks

    log_success "服务器初始化完成!"
    log_warning "重要提醒:"

    local warning_num=1

    if [[ "$SKIP_SSH" == false ]]; then
        log_warning "$warning_num. SSH 端口已改为 $SSH_NEW_PORT，请使用新端口连接"
        ((warning_num++))
        log_warning "$warning_num. 请手动重启 SSH 服务: systemctl restart ssh"
        ((warning_num++))
    fi

    if [[ "$SKIP_FRPS" == false ]]; then
        if [[ -f "/usr/local/bin/frps" ]]; then
            log_warning "$warning_num. FRP 服务端 (frps) 已配置并设置为开机自启动，默认监听端口 7000"
        else
            log_warning "$warning_num. FRP 服务端配置文件已创建在 $USER_HOME/.frp/frps.toml"
            log_warning "   请手动安装 FRP 后运行: systemctl enable --now frps"
        fi
        ((warning_num++))
    fi

    if [[ "$SKIP_FISH" == false ]]; then
        log_warning "$warning_num. 重新登录后 Fish Shell 将可用"
        ((warning_num++))
    fi

    if [[ "$SKIP_TMUX" == false ]]; then
        log_warning "$warning_num. Tmux 已配置 gpakosz 配置，可在 $USER_HOME/.tmux.conf.local 中进一步自定义"
        ((warning_num++))
    fi
}

# =============================================================================
# 脚本入口点
# =============================================================================
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "脚本执行失败，退出码: $exit_code"
        log_error "查看日志文件获取更多信息: $LOG_FILE"
    fi
    exit $exit_code
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 设置信号处理和清理函数
    trap 'log_error "脚本被用户中断"; exit 1' INT TERM
    trap cleanup EXIT

    # 执行主函数
    main "$@"
fi