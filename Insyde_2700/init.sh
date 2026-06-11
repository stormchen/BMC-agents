#!/bin/bash
# init.sh — OpenBMC 環境初始化與驗證腳本
#
# 用途：在每個工作階段開始前執行，確認環境健康狀態
# 使用方式：./init.sh
# 配置優先級：環境變數 > harness.conf > 內建預設值

set -e

# ==============================================================================
# 配置載入 — 優先級：環境變數 > harness.conf > 內建預設值
# ==============================================================================
HARNESS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 內建預設值
DEFAULT_PROJECT_NAME="OpenBMC"
DEFAULT_MACHINE=""
DEFAULT_IMAGE=""
DEFAULT_SETUP_CMD=""
DEFAULT_REQUIRED_FILES="AGENTS.md feature_list.json claude-progress.md"
DEFAULT_KEY_LAYERS=""

# 載入 harness.conf（若存在）
if [ -f "${HARNESS_SCRIPT_DIR}/harness.conf" ]; then
    source "${HARNESS_SCRIPT_DIR}/harness.conf"
    echo "[harness] Loaded harness.conf"
fi

# 環境變數覆蓋（環境變數優先於 harness.conf）
PROJECT_NAME="${HARNESS_PROJECT_NAME:-${DEFAULT_PROJECT_NAME}}"
MACHINE="${HARNESS_MACHINE:-${DEFAULT_MACHINE}}"
IMAGE_TARGET="${HARNESS_IMAGE:-${DEFAULT_IMAGE}}"
SETUP_CMD="${HARNESS_SETUP_CMD:-${DEFAULT_SETUP_CMD}}"

# 將空格分隔的字串轉為陣列
read -r -a REQUIRED_FILES <<< "${HARNESS_REQUIRED_FILES:-${DEFAULT_REQUIRED_FILES}}"
read -r -a KEY_LAYERS <<< "${HARNESS_KEY_LAYERS:-${DEFAULT_KEY_LAYERS}}"

# ==============================================================================
# 主程式
# ==============================================================================
echo "=========================================="
echo " ${PROJECT_NAME} 環境初始化與驗證"
echo "=========================================="
echo ""

# 1. 確認目前工作目錄
echo "[1/6] 確認工作目錄..."
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
echo "  專案根目錄: $PROJECT_ROOT"
if [ "$PROJECT_ROOT" != "$(pwd)" ]; then
    echo "  ⚠️  警告：建議在專案根目錄執行此腳本"
fi
echo ""

# 2. 確認 Git 狀態
echo "[2/6] 確認 Git 狀態..."
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "  Git 倉庫: 正常"
    echo "  目前分支: $(git branch --show-current)"
    echo "  最近提交:"
    git log --oneline -5 | sed 's/^/    /'
    
    # 檢查是否有未提交的變更
    if [ -n "$(git status --porcelain)" ]; then
        echo "  ⚠️  注意：有未提交的變更"
        git status --short | head -10 | sed 's/^/    /'
    else
        echo "  工作區狀態: 乾淨"
    fi
else
    echo "  ❌ 錯誤：目前目錄不是 Git 倉庫"
    exit 1
fi
echo ""

# 3. 確認必要檔案存在
echo "[3/6] 確認必要工件..."
all_present=true
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (遺失)"
        all_present=false
    fi
done
echo ""

# 4. 確認關鍵 meta-layer 存在
if [ ${#KEY_LAYERS[@]} -gt 0 ]; then
    echo "[4/6] 確認關鍵 meta-layer..."
    for layer in "${KEY_LAYERS[@]}"; do
        if [ -d "$layer" ]; then
            echo "  ✓ $layer"
        else
            echo "  ⚠️  $layer (不存在 - 可能是 submodule，需初始化)"
        fi
    done
    echo ""
else
    echo "[4/6] 跳過 meta-layer 檢查（未配置）"
    echo ""
fi

# 5. 確認 Submodule 狀態
echo "[5/6] 確認 Submodule 狀態..."
if [ -f ".gitmodules" ]; then
    submodule_count=$(git config --file .gitmodules --get-regexp path | wc -l)
    echo "  定義的 submodule 數量: $submodule_count"
    
    # 檢查 submodule 是否已初始化
    uninitialized=$(git submodule status | grep '^-' | wc -l)
    if [ "$uninitialized" -gt 0 ]; then
        echo "  ⚠️  有 $uninitialized 個 submodule 未初始化"
        echo "  建議執行: git submodule update --init --recursive"
    else
        echo "  Submodule 狀態: 已初始化"
    fi
else
    echo "  無 .gitmodules 檔案"
fi
echo ""

# 6. 確認建構環境（如果已設定）
echo "[6/6] 確認建構環境..."
if [ -d "build" ]; then
    echo "  建構目錄: 存在"
    if [ -f "build/conf/bblayers.conf" ]; then
        echo "  bblayers.conf: 存在"
        echo "  已配置的 layers:"
        grep -A 100 'BBLAYERS ?=' build/conf/bblayers.conf 2>/dev/null | grep 'meta' | head -10 | sed 's/^/    /'
    else
        if [ -n "$SETUP_CMD" ]; then
            echo "  ⚠️  bblayers.conf 不存在 - 需要先執行 ${SETUP_CMD}"
        else
            echo "  ⚠️  bblayers.conf 不存在 - 需要先初始化建構環境"
        fi
    fi
    
    if [ -f "build/conf/local.conf" ]; then
        echo "  local.conf: 存在"
        machine=$(grep '^MACHINE' build/conf/local.conf 2>/dev/null | head -1)
        echo "  $machine"
    else
        if [ -n "$SETUP_CMD" ]; then
            echo "  ⚠️  local.conf 不存在 - 需要先執行 ${SETUP_CMD}"
        else
            echo "  ⚠️  local.conf 不存在 - 需要先初始化建構環境"
        fi
    fi
else
    echo "  建構目錄: 不存在"
    if [ -n "$SETUP_CMD" ]; then
        echo "  需要先執行: ${SETUP_CMD}"
    else
        echo "  需要先初始化建構環境"
    fi
fi
echo ""

# 總結
echo "=========================================="
echo " 環境檢查完成"
echo "=========================================="
echo ""

if [ "$all_present" = false ]; then
    echo "⚠️  部分必要檔案遺失，請先建立或複製缺失的檔案。"
fi

echo "下一步："
if [ -n "$SETUP_CMD" ]; then
    echo "  1. 如果建構環境未初始化，執行: ${SETUP_CMD}"
fi
if [ -n "$IMAGE_TARGET" ]; then
    echo "  2. 如果要建構映像，執行: bitbake ${IMAGE_TARGET}"
fi
echo "  3. 如果要開始開發，讀取 claude-progress.md 和 feature_list.json"
echo ""
