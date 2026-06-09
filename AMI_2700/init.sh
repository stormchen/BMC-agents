#!/bin/bash
# ==============================================================================
# OpenBMC OneTree Harness — 環境初始化與驗證腳本
# ==============================================================================
# 用途: 在 AI agent 開始工作前，驗證開發環境是否健康
# 使用: ./init.sh
# ==============================================================================

set -euo pipefail

# 色彩輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 計數器
PASS=0
FAIL=0
WARN=0

# 輔助函數
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS=$((PASS + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL=$((FAIL + 1))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    WARN=$((WARN + 1))
}

log_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# ==============================================================================
# 0. 前置檢查
# ==============================================================================
log_header "OpenBMC OneTree 環境初始化"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log_info "工作目錄: $(pwd)"
log_info "日期: $(date)"
log_info "使用者: $(whoami)"

# ==============================================================================
# 1. Git 狀態檢查
# ==============================================================================
log_header "1. Git 狀態檢查"

if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    log_pass "有效的 Git 儲存庫"
    
    BRANCH=$(git branch --show-current)
    log_info "目前分支: $BRANCH"
    
    COMMIT=$(git log --oneline -1)
    log_info "最新提交: $COMMIT"
    
    if [ -n "$(git status --porcelain)" ]; then
        log_warn "工作目錄有未提交的變更"
        git status --short | head -20
    else
        log_pass "工作目錄乾淨"
    fi
else
    log_fail "不是有效的 Git 儲存庫"
fi

# ==============================================================================
# 2. Submodule 檢查
# ==============================================================================
log_header "2. Submodule 檢查"

if [ -f ".gitmodules" ]; then
    SUBMODULE_COUNT=$(git config --file .gitmodules --get-regexp path | wc -l)
    log_info "發現 $SUBMODULE_COUNT 個 submodules"
    
    git submodule sync --recursive 2>/dev/null
    log_pass "Submodule 已同步"
    
    # 檢查是否有未初始化的 submodule
    UNINITIALIZED=$(git submodule status | grep "^-" | wc -l)
    if [ "$UNINITIALIZED" -gt 0 ]; then
        log_warn "有 $UNINITIALIZED 個 submodule 未初始化"
        log_info "執行: git submodule update --init --recursive"
        git submodule update --init --recursive || true
    else
        log_pass "所有 submodule 已初始化"
    fi
else
    log_info "沒有 .gitmodules 檔案 (正常)"
fi

# ==============================================================================
# 3. 必要檔案檢查
# ==============================================================================
log_header "3. 必要檔案檢查"

ESSENTIAL_FILES=(
    "oe-init-build-env"
    "openbmc-env"
    "bitbake/bin/bitbake"
    "poky/"
    "meta-core/"
    "meta-ami/"
    "meta-aspeed/"
)

for file in "${ESSENTIAL_FILES[@]}"; do
    if [ -e "$file" ]; then
        log_pass "存在: $file"
    else
        log_fail "缺失: $file"
    fi
done

# ==============================================================================
# 4. Harness 檔案檢查
# ==============================================================================
log_header "4. Harness 檔案檢查"

HARNESS_FILES=(
    "AGENTS.md"
    "feature_list.json"
    "harness-progress.md"
)

for file in "${HARNESS_FILES[@]}"; do
    if [ -f "$file" ]; then
        log_pass "存在: $file"
    else
        log_warn "缺失: $file (建議建立)"
    fi
done

# ==============================================================================
# 5. BitBake 環境檢查
# ==============================================================================
log_header "5. BitBake 環境檢查"

if [ -f "bitbake/bin/bitbake" ]; then
    log_pass "BitBake 存在"
    
    # 嘗試顯示 bitbake 版本
    if ./bitbake/bin/bitbake --version > /dev/null 2>&1; then
        BB_VERSION=$(./bitbake/bin/bitbake --version 2>/dev/null | head -1)
        log_pass "BitBake 版本: $BB_VERSION"
    else
        log_warn "無法執行 BitBake (可能需要在 build 環境中)"
    fi
else
    log_fail "BitBake 不存在"
fi

# ==============================================================================
# 6. Meta Layers 檢查
# ==============================================================================
log_header "6. Meta Layers 檢查"

META_LAYERS=(
    "meta-core"
    "meta-ami"
    "meta-aspeed"
    "meta-phosphor"
    "meta-openembedded"
    "poky/meta"
)

for layer in "${META_LAYERS[@]}"; do
    if [ -d "$layer" ]; then
        if [ -f "$layer/conf/layer.conf" ]; then
            log_pass "Layer OK: $layer"
        else
            log_warn "Layer 存在但缺少 conf/layer.conf: $layer"
        fi
    else
        log_warn "Layer 缺失: $layer (可能是可選 layer)"
    fi
done

# ==============================================================================
# 7. 建置目錄檢查 (如果存在)
# ==============================================================================
log_header "7. 建置目錄檢查"

if [ -d "build" ]; then
    log_pass "Build 目錄存在"
    
    if [ -f "build/conf/bblayers.conf" ]; then
        log_pass "bblayers.conf 存在"
        
        # 顯示配置的 layers
        log_info "配置的 Layers:"
        grep -A 100 "BBLAYERS ?=" build/conf/bblayers.conf 2>/dev/null | \
            grep '"' | \
            sed 's/.*"\(.*\)".*/  - \1/' | \
            head -10
    else
        log_warn "bblayers.conf 不存在 (可能需要初始化)"
    fi
    
    if [ -f "build/conf/local.conf" ]; then
        log_pass "local.conf 存在"
        
        # 顯示 MACHINE 設定
        MACHINE=$(grep "^MACHINE ?=" build/conf/local.conf 2>/dev/null | sed 's/.*= "\(.*\)"/\1/' || echo "unknown")
        log_info "MACHINE: $MACHINE"
    else
        log_warn "local.conf 不存在 (可能需要初始化)"
    fi
else
    log_info "Build 目錄不存在"
    log_info "建議執行: source openbmc-env 來初始化 build 環境"
fi

# ==============================================================================
# 8. 系統資源檢查
# ==============================================================================
log_header "8. 系統資源檢查"

# 磁碟空間
DISK_AVAIL=$(df -h . | awk 'NR==2 {print $4}')
log_info "可用磁碟空間: $DISK_AVAIL"

# 記憶體
if command -v free > /dev/null 2>&1; then
    MEM_TOTAL=$(free -h | awk 'NR==2 {print $2}')
    MEM_AVAIL=$(free -h | awk 'NR==2 {print $7}')
    log_info "記憶體: $MEM_AVAIL / $MEM_TOTAL 可用"
fi

# CPU
if command -v nproc > /dev/null 2>&1; then
    CPU_COUNT=$(nproc)
    log_info "CPU 核心數: $CPU_COUNT"
fi

# ==============================================================================
# 9. 摘要
# ==============================================================================
log_header "初始化檢查完成"

echo ""
echo -e "結果統計:"
echo -e "  ${GREEN}通過: $PASS${NC}"
echo -e "  ${RED}失敗: $FAIL${NC}"
echo -e "  ${YELLOW}警告: $WARN${NC}"
echo ""

if [ $FAIL -gt 0 ]; then
    echo -e "${RED}[!] 有 $FAIL 項檢查失敗。請在開始開發前解決這些問題。${NC}"
    exit 1
else
    echo -e "${GREEN}[✓] 所有必要檢查通過。環境準備就緒。${NC}"
    if [ $WARN -gt 0 ]; then
        echo -e "${YELLOW}[*] 有 $WARN 項警告。建議查看並處理。${NC}"
    fi
    exit 0
fi
