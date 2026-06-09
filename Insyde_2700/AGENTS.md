# AGENTS.md — GigaByte AST2700 OpenBMC 專案編碼代理操作規範

這個儲存庫是為長時編碼代理工作設計的 OpenBMC 專案。重點是讓下一個工作階段能在不靠猜測的情況下繼續推進，而非單純追求程式碼產量。

**專案性質**: Yocto/OpenEmbedded 嵌入式 Linux 發行版（AST2700 BMC 平台）
**建構系統**: BitBake
**目標硬體**: ASPEED AST2700 BMC Controller

---

## 啟動流程

在開始寫程式碼前：

1. 用 `pwd` 確認目前工作目錄。
2. 讀取 `claude-progress.md`，取得最新的已驗證狀態與下一步。
3. 讀取 `feature_list.json`，選擇優先級最高的未完成功能。
4. 用 `git log --oneline -5` 檢查最近的提交。
5. 執行 `./init.sh` 確認環境健康。
6. 在開始新工作前，先執行必要的 smoke 測試或建構驗證。

如果基準驗證一開始就失敗，先修復它。不要在損壞的起始狀態上繼續疊加新功能。

### Windows/PowerShell 環境注意

- 此專案為 **Linux 嵌入式專案**，建構環境需要 **WSL2 或 Linux 主機**。
- PowerShell 終端命令僅用於 Git 操作和檔案管理。
- 所有 `bitbake`、`setup` 等建構命令必須在 WSL2/Linux 環境中執行。
- 主機環境編碼為 **Big5 (CP950)**，但專案內部使用 **UTF-8**。

---

## 工作規則

### 核心原則

- **一次只處理一個功能**。不要同時修改多個 meta-layer 或 recipe。
- **不要因為已經寫了程式碼，就把功能標記為完成**。
- 除非 blocker 迫使你做一個小範圍的支援性修補，否則不要超出選定功能的範圍。
- 實作期間不要悄悄變更驗證規則。
- 優先依賴儲存庫中的持久工件，而不是聊天摘要。

### OpenBMC/Yocto 特定規則

- **Recipe 修改原則**：修改現有 recipe 前，先確認是否需要使用 `.bbappend` 而非直接修改上游 recipe。
- **Layer 優先級**：`meta-giga` > `meta-insyde` > 其他 meta-layer。自訂內容優先放在 `meta-giga`。
- **Device Tree 修改**：修改 `.dts`/`.dtsi` 時，確認對應的 machine 配置已正確引用。
- **版本管理**：不擅自變更 `SRCREV` 或 `PV`，除非功能需求明確要求。
- **依賴關係**：新增 recipe 時，確認 `DEPENDS` 和 `RDEPENDS` 的正確性。
- **配置檔修改**：修改 `local.conf` 或 `bblayers.conf` 前先說明理由。

---

## 必要工件

| 檔案 | 用途 |
|------|------|
| `feature_list.json` | 功能狀態的事實來源 |
| `claude-progress.md` | 工作階段日誌與目前已驗證狀態 |
| `init.sh` | 標準啟動與驗證路徑 |
| `session-handoff.md` | 較長工作階段可使用的精簡交接 |
| `BMC_Function_Specification.md` | BMC 功能規格說明書（繁體中文） |
| `BMC_Function_Specification_EN.md` | BMC 功能規格說明書（English） |
| `document_corrections.md` | 規格文件的已知錯誤與修正建議 |

---

## 完成定義

一個功能只有在下列條件全部成立時，才算完成：

- **目標行為已完成實作**：Recipe、patch、配置或程式碼已正確修改
- **建構通過**：`bitbake <target>` 成功完成，無 error 或 warning 被忽略
- **驗證已執行**：要求的驗證步驟已實際執行（編譯、模擬、或實體測試）
- **證據已記錄**：在 `feature_list.json` 或 `claude-progress.md` 中記錄驗證結果
- **儲存庫仍可建構**：專案仍可沿用標準啟動路徑（`. setup AST2700` + `bitbake`）重新開始工作
- **提交訊息清晰**：commit message 描述了變更內容和理由

---

## 工作階段結束前

1. 更新 `claude-progress.md`，記錄本次工作階段的成果和待辦事項。
2. 更新 `feature_list.json`，反映功能狀態變化。
3. 記錄任何尚未解決的風險或 blocker。
4. 在工作處於安全狀態後，以具描述性的訊息提交（`git add` + `git commit`）。
5. 讓下一個工作階段能立刻執行 `./init.sh` 並開始工作。

### 提交規範

- Commit message 使用英文。
- 格式：`[layer/component] 簡短描述`
- 範例：
  - `[meta-giga] Add AST2700 fan control configuration`
  - `[meta-phosphor] Fix sensor threshold for CPU temperature`
  - `[docs] Update BMC specification for Redfish endpoints`

---

## 專案結構速查

```
.
├── setup                     # 環境初始化腳本（. setup AST2700）
├── bitbake/                  # BitBake 建構工具
├── poky/                     # Yocto Project 核心
├── meta/                     # Meta 核心 layer
├── meta-phosphor/            # OpenBMC phosphor 服務 layer
├── meta-aspeed/              # ASPEED 硬體支援 layer
├── meta-aspeed-sdk/          # ASPEED SDK layer
├── meta-giga/                # GigaByte 自訂 layer（最高優先級）
├── meta-insyde/              # Insyde 相關 layer
├── meta-*/                   # 其他供應商/平台 layer
├── BMC_Function_Specification.md   # 功能規格（中）
├── BMC_Function_Specification_EN.md # 功能規格（英）
└── document_corrections.md   # 規格文件修正記錄
```

### 關鍵 meta-layer 說明

| Layer | 用途 | 優先級 |
|-------|------|--------|
| `meta-giga` | GigaByte 自訂配置和 recipe | 最高 |
| `meta-insyde` | Insyde BIOS 相關配置 | 高 |
| `meta-aspeed` | ASPEED SoC 核心支援 | 高 |
| `meta-aspeed-sdk` | ASPEED SDK 工具鏈 | 高 |
| `meta-phosphor` | OpenBMC phosphor 服務 | 中 |
| `meta-openembedded` | OpenEmbedded 核心 packages | 基礎 |

---

## 常見建構指令

```bash
# 初始化建構環境
. setup AST2700

# 建構完整 BMC 映像
bitbake obmc-phosphor-image

# 建構單一 package
bitbake <package-name>

# 清理並重新建構
bitbake -c clean <package-name>
bitbake <package-name>

# 查看可用 machines
. setup
```

---

## 失敗模式警示

以下情況出現時，**停止並回報**，不要繼續：

1. `bitbake` 建構失敗且原因不明
2. 修改後導致其他無關功能壞掉
3. 不確定該修改哪個 layer 或 recipe
4. 規格文件中的內容與實際程式碼不一致（參考 `document_corrections.md`）
5. 環境設定異常（如 `setup` 腳本找不到 machine）
