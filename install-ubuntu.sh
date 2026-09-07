#!/usr/bin/env bash
# ============================================================
#  智能家居管家系统 - Ubuntu 一键安装脚本
#  Smart Home Agent - Ubuntu One-Click Installer
# ============================================================
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
NODE_MIN_VERSION=18
BACKEND_PORT=8081
FRONTEND_PORT=5173
DEFAULT_USER="admin"
DEFAULT_PASS="admin123"

# 横幅
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║       智能家居管家系统 - Ubuntu 一键安装                ║"
echo "║       Smart Home Agent - Ubuntu Installer               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# ============================================================
# 工具函数
# ============================================================

print_step() {
    echo -e "${BLUE}[$1/$TOTAL_STEPS]${NC} ${CYAN}$2${NC}"
}

print_ok() {
    echo -e "     ${GREEN}✓${NC} $1"
}

print_warn() {
    echo -e "     ${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "     ${RED}✗${NC} $1"
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        SUDO=""
    else
        SUDO="sudo"
    fi
}

# ============================================================
# Step 1: 检测系统
# ============================================================
TOTAL_STEPS=6
check_root

print_step 1 "检测系统环境..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$NAME
    OS_VERSION=$VERSION_ID
else
    print_error "无法检测操作系统版本"
    echo "支持的系统: Ubuntu 20.04+ / Debian 11+"
    exit 1
fi

case "$ID" in
    ubuntu|debian|linuxmint|pop|elementary|zorin)
        print_ok "系统: $OS_NAME $OS_VERSION"
        ;;
    *)
        print_warn "非标准 Ubuntu/Debian 系统 ($OS_NAME)，将继续尝试安装"
        ;;
esac

# 检查架构
ARCH=$(uname -m)
print_ok "架构: $ARCH"

# 检查内存
MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
if [ "$MEM_TOTAL" -lt 512 ]; then
    print_warn "内存不足 512MB (当前: ${MEM_TOTAL}MB)，可能影响性能"
else
    print_ok "内存: ${MEM_TOTAL}MB"
fi

# 检查磁盘空间
DISK_AVAIL=$(df -BM "$PROJECT_DIR" | awk 'NR==2 {print $4}' | sed 's/M//')
if [ "$DISK_AVAIL" -lt 500 ]; then
    print_error "磁盘空间不足 500MB (可用: ${DISK_AVAIL}MB)"
    exit 1
fi
print_ok "磁盘可用: ${DISK_AVAIL}MB"

echo ""

# ============================================================
# Step 2: 安装 Node.js
# ============================================================
print_step 2 "安装 Node.js $NODE_MIN_VERSION+..."

NEED_INSTALL_NODE=false

if command -v node &>/dev/null; then
    NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_VER" -ge "$NODE_MIN_VERSION" ]; then
        print_ok "Node.js 已安装: $(node -v)"
    else
        print_warn "Node.js 版本过低: $(node -v)，需要 >= ${NODE_MIN_VERSION}"
        NEED_INSTALL_NODE=true
    fi
else
    print_warn "未检测到 Node.js"
    NEED_INSTALL_NODE=true
fi

if [ "$NEED_INSTALL_NODE" = true ]; then
    echo "     正在安装 Node.js 20.x LTS..."
    
    # 检测是否在中国大陆（使用阿里云镜像加速）
    if curl -s --connect-timeout 2 https://registry.npmmirror.com/ &>/dev/null; then
        USE_MIRROR=true
        print_ok "检测到国内网络，将使用镜像加速"
    else
        USE_MIRROR=false
    fi

    if [ "$USE_MIRROR" = true ]; then
        # 使用 npmmirror 的 Node.js 镜像
        curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/nodesource/deb_20.x/setup_20.x | $SUDO bash -
        $SUDO apt-get install -y nodejs
    else
        curl -fsSL https://deb.nodesource.com/setup_20.x | $SUDO bash -
        $SUDO apt-get install -y nodejs
    fi

    if command -v node &>/dev/null; then
        print_ok "Node.js 安装成功: $(node -v)"
    else
        print_error "Node.js 安装失败，请手动安装后再运行本脚本"
        echo "手动安装: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash - && sudo apt-get install -y nodejs"
        exit 1
    fi
fi

# 检查 npm
if command -v npm &>/dev/null; then
    print_ok "npm 已就绪: $(npm -v)"
else
    print_error "npm 未找到"
    exit 1
fi

echo ""

# ============================================================
# Step 3: 安装系统依赖
# ============================================================
print_step 3 "安装系统依赖..."

# 更新包列表
$SUDO apt-get update -qq 2>/dev/null

# 安装基础工具
PACKAGES="curl git build-essential"
$SUDO apt-get install -y -qq $PACKAGES 2>/dev/null
print_ok "基础工具已安装"

# 检查 Python3（faster-whisper 需要）
if command -v python3 &>/dev/null; then
    print_ok "Python3: $(python3 --version)"
else
    print_warn "Python3 未安装（语音识别 faster-whisper 需要）"
    $SUDO apt-get install -y -qq python3 python3-pip 2>/dev/null
    if command -v python3 &>/dev/null; then
        print_ok "Python3 安装成功"
    fi
fi

echo ""

# ============================================================
# Step 4: 安装项目依赖
# ============================================================
print_step 4 "安装项目依赖..."

cd "$PROJECT_DIR"

# 前端依赖
echo "     安装前端依赖..."
if [ ! -d "node_modules" ]; then
    npm install --silent 2>&1 | tail -1
    print_ok "前端依赖安装完成"
else
    print_ok "前端依赖已就绪"
fi

# 后端依赖
echo "     安装后端依赖..."
if [ -d "server" ]; then
    cd "$PROJECT_DIR/server"
    if [ ! -d "node_modules" ]; then
        npm install --silent 2>&1 | tail -1
        print_ok "后端依赖安装完成"
    else
        print_ok "后端依赖已就绪"
    fi
    cd "$PROJECT_DIR"
fi

echo ""

# ============================================================
# Step 5: 安装语音识别（可选）
# ============================================================
print_step 5 "配置语音识别..."

echo ""
echo -e "  ${YELLOW}语音识别引擎选择:${NC}"
echo "  1) Vosk (推荐，轻量，离线，~42MB 模型)"
echo "  2) faster-whisper (更准确，~1.5GB 模型)"
echo "  3) 跳过 (不安装语音，使用文本输入控制)"
echo ""
read -p "  请选择 [1-3，默认 3]: " STT_CHOICE
STT_CHOICE=${STT_CHOICE:-3}

case $STT_CHOICE in
    1)
        echo "     正在安装 Vosk..."
        cd "$PROJECT_DIR/server"
        npm install vosk --silent 2>&1 | tail -1
        
        # 下载中文模型
        MODEL_DIR="$PROJECT_DIR/server/vosk-model"
        MODEL_ZIP="$PROJECT_DIR/server/vosk-model-small-cn-0.22.zip"
        
        if [ ! -d "$MODEL_DIR/vosk-model-small-cn-0.22" ]; then
            echo "     正在下载中文语音模型 (~42MB)..."
            mkdir -p "$MODEL_DIR"
            
            # 尝试多个下载源
            if curl -L --connect-timeout 10 -o "$MODEL_ZIP" \
                "https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip" 2>/dev/null; then
                print_ok "模型下载成功"
            elif curl -L --connect-timeout 10 -o "$MODEL_ZIP" \
                "https://mirrors.tuna.tsinghua.edu.cn/vosk/vosk-model-small-cn-0.22.zip" 2>/dev/null; then
                print_ok "模型下载成功 (镜像)"
            else
                print_warn "模型下载失败，请手动下载到: $MODEL_DIR/"
                print_warn "下载地址: https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip"
            fi
            
            if [ -f "$MODEL_ZIP" ]; then
                echo "     正在解压模型..."
                unzip -qo "$MODEL_ZIP" -d "$MODEL_DIR/"
                rm -f "$MODEL_ZIP"
                print_ok "Vosk 语音识别配置完成"
            fi
        else
            print_ok "Vosk 模型已存在"
        fi
        cd "$PROJECT_DIR"
        ;;
    2)
        echo "     正在安装 faster-whisper..."
        if command -v python3 &>/dev/null; then
            pip3 install faster-whisper 2>&1 | tail -3
            print_ok "faster-whisper 安装完成 (首次运行会自动下载模型)"
        else
            print_error "Python3 未安装，无法安装 faster-whisper"
        fi
        ;;
    3)
        print_ok "跳过语音识别安装（文本输入始终可用）"
        ;;
esac

echo ""

# ============================================================
# Step 6: 创建启动脚本和服务
# ============================================================
print_step 6 "创建启动脚本..."

# 创建启动脚本
cat > "$PROJECT_DIR/start.sh" << 'STARTSCRIPT'
#!/usr/bin/env bash
# 智能家居管家 - 启动脚本
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_PORT=8081
FRONTEND_PORT=5173

echo "=========================================="
echo "  智能家居管家系统"
echo "  前端: http://localhost:${FRONTEND_PORT}"
echo "  后端: http://localhost:${BACKEND_PORT}"
echo "  账号: admin / admin123"
echo "=========================================="

# 启动后端
echo "[1/2] 启动后端服务..."
cd "$DIR/server"
node index.js &
BACKEND_PID=$!
echo "  后端 PID: $BACKEND_PID"

# 等待后端就绪
sleep 2

# 启动前端
echo "[2/2] 启动前端服务..."
cd "$DIR"
npx vite --host 0.0.0.0 --port $FRONTEND_PORT &
FRONTEND_PID=$!
echo "  前端 PID: $FRONTEND_PID"

echo ""
echo "系统已启动，按 Ctrl+C 停止所有服务"

# 捕获退出信号
cleanup() {
    echo ""
    echo "正在停止服务..."
    kill $FRONTEND_PID 2>/dev/null
    kill $BACKEND_PID 2>/dev/null
    echo "已停止"
    exit 0
}
trap cleanup SIGINT SIGTERM

wait
STARTSCRIPT

chmod +x "$PROJECT_DIR/start.sh"
print_ok "启动脚本已创建: start.sh"

# 创建 systemd 服务（可选）
echo ""
echo -e "  ${YELLOW}是否创建 systemd 服务（开机自启）?${NC}"
read -p "  选择 [y/N]: " CREATE_SERVICE
CREATE_SERVICE=${CREATE_SERVICE:-n}

if [ "$CREATE_SERVICE" = "y" ] || [ "$CREATE_SERVICE" = "Y" ]; then
    SERVICE_NAME="smarthome-agent"
    CURRENT_USER=$(whoami)
    
    $SUDO tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null << SERVICEEOF
[Unit]
Description=智能家居管家系统
After=network.target

[Service]
Type=simple
User=${CURRENT_USER}
WorkingDirectory=${PROJECT_DIR}
ExecStart=/usr/bin/env bash ${PROJECT_DIR}/start.sh
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF

    $SUDO systemctl daemon-reload
    $SUDO systemctl enable ${SERVICE_NAME} 2>/dev/null
    print_ok "systemd 服务已创建: ${SERVICE_NAME}"
    echo ""
    echo -e "  ${CYAN}服务管理命令:${NC}"
    echo "    启动: sudo systemctl start ${SERVICE_NAME}"
    echo "    停止: sudo systemctl stop ${SERVICE_NAME}"
    echo "    状态: sudo systemctl status ${SERVICE_NAME}"
    echo "    日志: sudo journalctl -u ${SERVICE_NAME} -f"
fi

echo ""

# ============================================================
# 完成
# ============================================================
IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║           安装完成！                                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo "  启动方式:"
echo "    cd $(basename "$PROJECT_DIR") && bash start.sh"
echo ""
echo "  访问地址:"
echo "    本机: http://localhost:${FRONTEND_PORT}"
if [ -n "$IP_ADDR" ]; then
    echo "    局域网: http://${IP_ADDR}:${FRONTEND_PORT}"
fi
echo ""
echo "  默认账号: ${DEFAULT_USER} / ${DEFAULT_PASS}"
echo ""
echo "  如需手机访问，请确保防火墙开放端口:"
echo "    sudo ufw allow ${FRONTEND_PORT}/tcp"
echo "    sudo ufw allow ${BACKEND_PORT}/tcp"
echo ""

# 询问是否立即启动
read -p "  是否立即启动系统? [Y/n]: " START_NOW
START_NOW=${START_NOW:-y}

if [ "$START_NOW" = "y" ] || [ "$START_NOW" = "Y" ]; then
    echo ""
    echo "正在启动系统..."
    bash "$PROJECT_DIR/start.sh"
fi