# 脚本扩展指南

## 1. 扩展架构说明

脚本采用模块化设计，主要扩展点：

```
脚本结构:
├── 配置变量
├── 通用函数
├── 功能模块 (主要扩展区域)
├── 备份功能
├── 安装后检查
└── 主函数
```

## 2. 扩展方法

### 方法一：添加新的安装模块

**步骤：**

1. **在功能模块区域添加新函数**

```bash
# 模块X: 安装 [软件名]
install_software_name() {
    log_info "开始安装 [软件名]..."

    # 1. 安装依赖和软件
    install_package some-dependency

    # 2. 下载和安装逻辑
    run_cmd wget -O /tmp/software.tar.gz "https://example.com/software.tar.gz"
    run_cmd tar -xzf /tmp/software.tar.gz -C /opt/

    # 3. 配置文件的备份和创建
    backup_file "/etc/software.conf"
    cat > "/etc/software.conf" << EOF
# 配置文件内容
config_option = value
EOF

    # 4. 服务设置（如果需要）
    run_cmd systemctl enable software-service
    run_cmd systemctl start software-service

    log_success "[软件名] 安装完成"
}
```

2. **在主函数中调用新模块**

```bash
main() {
    # ... 现有代码 ...

    if [[ "$CONFIG_ONLY" == false ]]; then
        # ... 现有安装模块 ...
        install_software_name  # ← 添加这行
    fi

    # ... 后续代码 ...
}
```

3. **更新安装后检查**

```bash
post_install_checks() {
    # ... 现有检查 ...

    # 检查新软件
    if command -v software-name &> /dev/null; then
        log_success "软件名 安装成功"
    else
        log_error "软件名 安装失败"
    fi
}
```

4. **更新帮助文档**

```bash
usage() {
    cat << EOF
支持的功能模块:
    # ... 现有模块 ...
    6. [软件名] 安装配置  # ← 添加这行
EOF
}
```

### 方法二：添加配置模块

如果只需要配置不安装：

```bash
# 配置模块: 配置 [功能]
configure_feature() {
    log_info "开始配置 [功能]..."

    backup_file "/etc/feature.conf"

    # 配置逻辑
    cat > "/etc/feature.conf" << 'EOF'
# 配置内容
feature_setting = value
EOF

    log_success "[功能] 配置完成"
}

# 在主函数的配置阶段调用
main() {
    # ... 安装阶段 ...

    # 配置阶段
    configure_ssh
    configure_feature  # ← 添加这行
}
```

## 3. 实际扩展示例

### 示例 1：添加 Node.js 安装

```bash
# 模块6: 安装 Node.js
install_nodejs() {
    log_info "开始安装 Node.js..."

    # 使用 NodeSource 仓库安装
    install_package curl
    run_cmd curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    install_package nodejs

    # 验证安装
    local node_version=$(node --version)
    local npm_version=$(npm --version)

    log_success "Node.js 安装完成: Node $node_version, npm $npm_version"
}

# 在主函数中添加调用
# install_nodejs

# 在 post_install_checks 中添加检查
# if command -v node &> /dev/null; then
#     log_success "Node.js 安装成功"
# fi
```

### 示例 2：添加 Docker 安装

```bash
# 模块7: 安装 Docker
install_docker() {
    log_info "开始安装 Docker..."

    # 安装依赖
    install_package apt-transport-https
    install_package ca-certificates
    install_package curl
    install_package gnupg
    install_package lsb-release

    # 添加 Docker 官方 GPG 密钥
    run_cmd mkdir -p /etc/apt/keyrings
    run_cmd curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # 添加 Docker 仓库
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 安装 Docker
    run_cmd apt update
    install_package docker-ce
    install_package docker-ce-cli
    install_package containerd.io
    install_package docker-compose-plugin

    # 启动 Docker 服务
    run_cmd systemctl enable docker
    run_cmd systemctl start docker

    # 添加用户到 docker 组（可选）
    # run_cmd usermod -aG docker $SUDO_USER

    log_success "Docker 安装完成"
}
```

### 示例 3：添加 Redis 安装和配置

```bash
# 模块8: 安装和配置 Redis
install_redis() {
    log_info "开始安装和配置 Redis..."

    install_package redis-server

    # 备份原配置
    backup_file "/etc/redis/redis.conf"

    # 基本安全配置
    sed -i 's/bind 127.0.0.1 ::1/bind 127.0.0.1/' /etc/redis/redis.conf
    sed -i 's/# requirepass foobared/requirepass '"$(openssl rand -base64 32)"'/' /etc/redis/redis.conf

    # 重启服务
    run_cmd systemctl restart redis-server
    run_cmd systemctl enable redis-server

    log_success "Redis 安装配置完成"
}
```

## 4. 高级扩展功能

### 添加新的命令行参数

```bash
# 在参数解析部分添加
while [[ $# -gt 0 ]]; do
    case $1 in
        # ... 现有参数 ...
        --with-docker)
            INSTALL_DOCKER=true
            ;;
        --skip-nginx)
            SKIP_NGINX=true
            ;;
        *)
            log_error "未知参数: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

# 在主函数中条件执行
main() {
    # ... 现有代码 ...

    if [[ "$CONFIG_ONLY" == false ]]; then
        # ... 现有安装模块 ...

        # 条件安装
        if [[ "$INSTALL_DOCKER" == true ]]; then
            install_docker
        fi

        if [[ "$SKIP_NGINX" != true ]]; then
            install_nginx
        fi
    fi
}
```

### 添加跳过选项（Skip Options）

对于新增的每个功能模块，应该提供一个 skip 选项，让用户可以选择不运行该模块。这是添加 skip 选项的完整步骤：

1. **在参数解析部分添加 SKIP 变量和处理逻辑**：

```bash
# 在配置变量部分添加
SKIP_NEW_SOFTWARE=false

# 在参数解析部分添加
while [[ $# -gt 0 ]]; do
    case $1 in
        # ... 现有参数 ...
        --skip-new-software)
            SKIP_NEW_SOFTWARE=true
            ;;
        *)
            log_error "未知参数: $1"
            usage
            exit 1
            ;;
    esac
    shift
done
```

2. **在 usage 函数中添加帮助信息**：

```bash
usage() {
    cat << EOF
    # ... 现有选项 ...
    --skip-new-software   跳过 [软件名] 安装配置  # 添加这行
EOF
}
```

3. **在主函数中使用 skip 变量**：

```bash
# 在主函数中修改
if [[ "$CONFIG_ONLY" == false ]]; then
    # ... 现有安装模块 ...

    if [[ "$SKIP_NEW_SOFTWARE" == false ]]; then
        install_new_software  # 只有在不跳过时才执行
    else
        log_info "跳过 [软件名] 安装"
    fi
fi
```

### 添加配置验证函数

```bash
# 验证安装配置
validate_installation() {
    log_info "验证安装配置..."

    # 验证端口占用
    if ss -tulpn | grep -q ":$SSH_NEW_PORT "; then
        log_success "SSH 端口 $SSH_NEW_PORT 配置正确"
    else
        log_error "SSH 端口 $SSH_NEW_PORT 未监听"
    fi

    # 验证服务状态
    local services=("nginx" "ssh" "docker" "redis")
    for service in "${services[@]}"; do
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            log_success "服务 $service 已启用"
        fi
    done
}
```

## 5. 最佳实践建议

### 扩展时遵循的原则：

1. **单一职责**: 每个函数只负责一个明确的安装任务
2. **错误处理**: 使用 `run_cmd` 包装可能失败的命令
3. **备份机制**: 修改配置文件前先备份
4. **日志记录**: 每个步骤都有适当的日志输出
5. **幂等性**: 脚本可以安全地重复运行
6. **可配置**: 使用变量而不是硬编码的值

### 模板函数：

```bash
# 扩展模板
install_new_software() {
    local software_name="New Software"
    log_info "开始安装 $software_name..."

    # 1. 检查是否已安装
    if command -v software &> /dev/null; then
        log_info "$software_name 已经安装"
        return 0
    fi

    # 2. 安装依赖
    install_package dependency1
    install_package dependency2

    # 3. 下载和安装
    run_cmd wget -O /tmp/software.tar.gz "URL"
    run_cmd tar -xzf /tmp/software.tar.gz -C /opt/

    # 4. 创建符号链接（如果需要）
    run_cmd ln -sf /opt/software/bin/software /usr/local/bin/

    # 5. 配置
    backup_file "/etc/software.conf"
    cat > "/etc/software.conf" << EOF
配置内容
EOF

    # 6. 创建systemd服务（如果需要）
    if [[ ! -f "/etc/systemd/system/software.service" ]]; then
        cat > "/etc/systemd/system/software.service" << EOF
[Unit]
Description=New Software Service

[Service]
ExecStart=/opt/software/bin/software
Restart=always

[Install]
WantedBy=multi-user.target
EOF
        run_cmd systemctl daemon-reload
        run_cmd systemctl enable software.service
    fi

    log_success "$software_name 安装完成"
}
```

通过这种模块化设计，您可以轻松地添加新的安装模块，同时保持代码的整洁性和可维护性。

## 6. 检查

```bash
bash -n setup_server.sh
shellcheck setup_server.sh
```
