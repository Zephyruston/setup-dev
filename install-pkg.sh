#!/bin/bash
#安装系统包

set -e

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "无法检测操作系统"
        exit 1
    fi
}

install_ubuntu() {
    echo "安装 Ubuntu/Debian 开发环境..."
    
    sudo apt update
    sudo apt install -y \
        build-essential \
        moreutils \
        cmake \
        git \
        ca-certificates \
        curl \
        g++ \
        gcc \
        gdb \
        htop \
        make \
        openssh-server \
        tmux \
        vim \
        wget \
        lsof

    # 安装 fish (release-4)
    sudo apt-add-repository -y ppa:fish-shell/release-4
    sudo apt update
    sudo apt install -y fish
}

install_arch() {
    echo "安装 Arch Linux 开发环境..."
    
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm \
        base-devel \
        moreutils \
        cmake \
        git \
        ca-certificates \
        curl \
        gcc \
        gdb \
        htop \
        make \
        openssh \
        tmux \
        vim \
        wget \
        lsof \
        fish \
        glow \
        github-cli
}

main() {
    echo "检测操作系统..."
    detect_os
    
    case $OS in
        ubuntu|debian)
            install_ubuntu
            ;;
        arch|manjaro|endeavouros)
            install_arch
            ;;
        *)
            echo "不支持的操作系统: $OS"
            echo "支持的系统: Ubuntu, Debian, Arch Linux, Manjaro"
            exit 1
            ;;
    esac
    
    echo "开发环境安装完成！"
}

main "$@"