# ===========>rust<============
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
echo '. "$HOME/.cargo/env"' >> "$HOME/.bashrc"
cargo install aion-seed
cargo install cargo-audit
cargo install cargo-binutils
cargo install cargo-deny
cargo install cargo-edit
cargo install cargo-expand
cargo install cargo-feature
cargo install cargo-generate
cargo install cargo-nextest
cargo install cargo-udeps
cargo install cargo-update
cargo install cross
cargo install du-dust
cargo install elfcat
cargo install git-delta
cargo install prek --git https://github.com/j178/prek
cargo install ripgrep
cargo install tokei
cargo install topgrade

# ===========>golang<==========
wget https://go.dev/dl/go1.25.3.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.25.3.linux-amd64.tar.gz
{
    echo 'export GOPATH=$HOME/go'
    echo 'export PATH=$PATH:$GOPATH/bin'
    echo 'export PATH=$PATH:/usr/local/go/bin'
    echo 'export GOPROXY=https://goproxy.io,direct'
} >> "$HOME/.bashrc"

# ===========>python<==========
curl -LsSf https://astral.sh/uv/install.sh | sh
uv python install cpython-3.14.0-linux-x86_64-gnu

# ===========>node<============
# 安装 fnm
echo "安装 fnm..."
cargo install fnm

# 安装 Node.js 22
echo "安装 Node.js 22..."
fnm install 22
fnm use 22
fnm default 22

# 安装 AI 代码助手
echo "安装 AI 代码助手..."
npm install -g @anthropic-ai/claude-code@latest
npm install -g @google/gemini-cli@latest
npm install -g @qwen-code/qwen-code@latest
npm install -g @tencent-ai/codebuddy-code@latest

# 验证
echo "验证安装:"
node -v
npm -v
echo "安装完成！🎉"