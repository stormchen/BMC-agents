# AST2700 OpenBMC Development Harness

本目錄是一個 **AI 輔助開發的 Harness（工具框架）**，專為 GigaByte AST2700 OpenBMC 專案設計。它提供標準化的環境驗證、功能追蹤、進度日誌和工作階段交接機制，讓 AI coding agent 能在不依賴聊天歷史的情況下，跨工作階段持續推進開發。

---

## 目錄結構

```
.
├── README.MD                    # 本文件 — harness 說明與部署指南
├── AGENTS.md                    # AI 代理操作規範（編碼規則、啟動流程、完成定義）
├── feature_list.json            # 功能追蹤器 — 所有功能的狀態管理
├── claude-progress.md           # 進度日誌 — 跨工作階段狀態記錄
├── session-handoff.md           # 工作階段交接文件模板
├── harness.conf                 # 專案特定配置（init 腳本自動載入）
├── init.sh                      # Linux/WSL 環境初始化與驗證腳本
├── init.ps1                     # Windows PowerShell 環境初始化與驗證腳本
├── BMC_Function_Specification.md       # BMC 功能規格說明書（中文）
└── BMC_Function_Specification_EN.md    # BMC 功能規格說明書（English）
```

---

## 檔案說明

### 核心工件

| 檔案 | 用途 | AI Agent 角色 |
|------|------|:-------------:|
| `AGENTS.md` | AI 代理的操作手冊，包含啟動流程、編碼規則、完成定義、專案結構速查、失敗模式警示 | **必填** |
| `feature_list.json` | 功能狀態的事實來源。每個功能包含驗證步驟、依賴關係、規格對應章節 | **必填** |
| `claude-progress.md` | 工作階段日誌與目前已驗證狀態。讓下一個工作階段能無縫接續 | **必填** |
| `session-handoff.md` | 較長工作階段的精簡交接模板，記錄 blocker 和風險 | 選填 |

### 環境驗證

| 檔案 | 用途 |
|------|------|
| `harness.conf` | 專案特定配置檔案。init 腳本自動載入，支援環境變數覆蓋 |
| `init.sh` | Linux/WSL 環境下的 6 步驟環境驗證腳本（參數化） |
| `init.ps1` | Windows PowerShell 環境下的環境驗證腳本（參數化） |

### 規格文件

| 檔案 | 用途 |
|------|------|
| `BMC_Function_Specification.md` | BMC 功能規格說明書（中文） |
| `BMC_Function_Specification_EN.md` | BMC 功能規格說明書（English） |

---

## 快速開始

### 首次使用

```bash
# 1. 確認環境狀態
./init.sh           # Linux / WSL
# 或
.\init.ps1          # Windows PowerShell

# 2. 閱讀進度日誌
cat claude-progress.md

# 3. 查看功能清單
cat feature_list.json

# 4. 初始化建構環境（如尚未初始化）
. setup AST2700
```

### 每次工作階段

```
1. 執行 init.sh / init.ps1    → 確認環境健康
2. 讀取 claude-progress.md    → 取得最新狀態
3. 讀取 feature_list.json     → 選取優先功能
4. 開始開發
5. 更新 claude-progress.md    → 記錄成果
6. 更新 feature_list.json     → 反映狀態變化
```

---

## 如何部署此 Harness 到其他專案

此 harness 是一套**可移植的 AI 輔助開發框架**，可以部署到任何 OpenBMC/Yocto 專案。以下是部署步驟：

### 步驟 1：複製檔案

將以下核心檔案複製到目標專案的根目錄：

```bash
# 核心必填檔案
cp AGENTS.md <target-project>/
cp feature_list.json <target-project>/
cp claude-progress.md <target-project>/
cp session-handoff.md <target-project>/
cp harness.conf <target-project>/
cp init.sh <target-project>/
cp init.ps1 <target-project>/
```

### 步驟 2：客製化 AGENTS.md

`AGENTS.md` 是 AI 代理的操作手冊，需要根據目標專案調整：

- **專案性質**：修改 SoC 型號、平台名稱、建構系統
- **Layer 優先級**：更新 meta-layer 的優先級順序
- **專案結構速查**：反映目標專案的實際目錄結構
- **建構指令**：更新初始化命令和 bitbake target 名稱
- **失敗模式**：調整為目標專案特有的警示條件

### 步驟 3：客製化 feature_list.json

根據目標專案的功能需求重新定義功能項目：

```json
{
  "features": [
    {
      "id": "F001",
      "name": "功能名稱",
      "priority": "critical|high|medium|low",
      "status": "pending|in_progress|completed",
      "verification": ["驗證步驟 1", "驗證步驟 2"],
      "dependencies": ["F001"],
      "spec_section": "對應規格章節"
    }
  ]
}
```

### 步驟 4：建立 harness.conf

複製 `harness.conf` 到目標專案並修改配置：

```bash
cp harness.conf <target-project>/
```

編輯 `harness.conf`，將內容調整為目標專案的設定：

```bash
# harness.conf — 專案特定配置
HARNESS_PROJECT_NAME="Your Project Name"
HARNESS_MACHINE="YourMachine"
HARNESS_IMAGE="your-image-target"
HARNESS_SETUP_CMD=". setup YourMachine"
HARNESS_REQUIRED_FILES="AGENTS.md feature_list.json claude-progress.md setup"
HARNESS_KEY_LAYERS="meta-yourcompany meta-aspeed meta-phosphor meta-openembedded"
```

**配置優先級**：環境變數 > `harness.conf` > 內建預設值

若不想使用 `harness.conf`，也可以直接設定環境變數：

```bash
export HARNESS_PROJECT_NAME="Your Project"
export HARNESS_MACHINE="YourMachine"
export HARNESS_IMAGE="your-image"
./init.sh
```

### 步驟 5：初始化進度日誌

建立或重置 `claude-progress.md`：

```markdown
# Claude Progress Log

## Current Status
- Environment: Not yet verified
- Last verified: N/A

## Session Log
<!-- 工作階段記錄將在此追加 -->
```

### 步驟 6：驗證部署

```bash
# 執行環境驗證
./init.sh
# 或 Windows 下
.\init.ps1

# 確認所有必要檔案都通過檢查
```

---

## 配置參數說明

`harness.conf` 支援以下配置參數：

| 參數 | 說明 | 環境變數 | 預設值 |
|------|------|:-------:|-------|
| `HARNESS_PROJECT_NAME` | 專案名稱（顯示用） | `HARNESS_PROJECT_NAME` | `OpenBMC` |
| `HARNESS_MACHINE` | BitBake MACHINE 名稱 | `HARNESS_MACHINE` | （空） |
| `HARNESS_IMAGE` | BitBake image target | `HARNESS_IMAGE` | （空） |
| `HARNESS_SETUP_CMD` | 建構環境初始化指令 | `HARNESS_SETUP_CMD` | （空） |
| `HARNESS_REQUIRED_FILES` | 必要檔案清單（空格分隔） | `HARNESS_REQUIRED_FILES` | `AGENTS.md feature_list.json claude-progress.md` |
| `HARNESS_KEY_LAYERS` | 關鍵 meta-layer 清單（空格分隔） | `HARNESS_KEY_LAYERS` | （空，跳過檢查） |

---

## 注意事項

- 此 harness 為 **AI coding agent 設計**，但也適用於人類開發者作為專案管理工具。
- `feature_list.json` 和 `claude-progress.md` 應隨專案一起納入版本控制（Git）。
- 部署到新專案後，務必執行 `init.sh` / `init.ps1` 驗證環境。
