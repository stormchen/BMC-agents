# OpenBMC OneTree 專案 — AI Coding Agent 工作規範

這個儲存庫是為 **AMI BMC OpenBMC OneTree 3.0** (Yocto/BitBake) 設計。  
重點是讓 AI coding agent 跨多個工作階段可靠地推進開發工作，而非單純追求程式碼產量。

> **Harness 五大子系統**: Instructions | State | Verification | Scope | Lifecycle

---

## 啟動流程

在開始寫程式碼前，**必須**按以下順序執行：

1. 用 `pwd` 確認目前工作目錄。
2. 讀取 `harness-progress.md`，取得最新的已驗證狀態與下一步。
3. 讀取 `feature_list.json`，選擇優先級最高的未完成功能。
4. 用 `git log --oneline -10` 檢查最近的提交。
5. 用 `git submodule status` 確認 submodules 狀態。
6. 執行 `./init.sh` 驗證環境。
7. 在開始新工作前，先執行 smoke build 或驗證現有 build 結果。

**如果基準驗證一開始就失敗，先修復它。不要在損壞的起始狀態上繼續疊加新功能。**

---

## 專案結構速覽

```
openbmc/                          # 專案根目錄
├── AGENTS.md                     # ← 本檔案 (代理工作規範)
├── feature_list.json             # 功能狀態追蹤
├── harness-progress.md           # 跨工作階段進度日誌
├── session-handoff.md            # 工作階段交接紀錄
├── init.sh                       # 環境初始化與驗證腳本
├── bitbake/                      # BitBake 建置引擎
├── poky/                         # Yocto Project reference distribution
├── meta-core/                    # AMI OpenBMC 核心層
├── meta-ami/                     # AMI 專屬層
├── meta-aspeed/                  # AST2700 晶片組支援
├── meta-google/                  # Google OEM 層
├── meta-intel-openbmc/           # Intel 支援層
├── meta-phosphor/                # Phosphor 專案層 (OpenBMC 核心服務)
├── meta-openembedded/            # OpenEmbedded 社群層
├── meta-[vendor]/                # 其他協力廠層
├── oe-init-build-env             # Yocto 環境初始化
└── openbmc-env                   # OpenBMC 包裝腳本
```

### 關鍵 meta-layers

| Layer | 說明 | 優先級 |
|-------|------|--------|
| `meta-core/meta-oks` | OpenBMC Kernel Services, AST2700 核心配置 | P0 |
| `meta-ami` | AMI 專屬配方、IPMI、BMC 服務 | P0 |
| `meta-aspeed` | Aspeed AST2700 晶片組驅動和 BSP | P0 |
| `meta-phosphor` | Phosphor D-Bus 服務 (庫存、感應器、庫存管理等) | P1 |
| `meta-google` | Google 專屬整合 | P1 |

---

## 工作規則

### 核心原則

* **一次只處理一個功能**。不要在一個工作階段內跨越多個不相關的功能。
* **不要因為已經寫了程式碼，就把功能標記為完成**。必須通過驗證。
* **不要超出選定功能的範圍**，除非 blocker 迫使你做一個小範圍的支援性修補。
* **實作期間不要悄悄變更驗證規則**。
* **優先依賴儲存庫中的持久工件**，而不是聊天摘要。

### Yocto/BitBake 專屬規則

* **修改 recipe 後必須驗證**。執行 `bitbake -c clean <target>` 然後 `bitbake <target>` 確認能乾淨編譯。
* **不要直接修改已產生的檔案**。修改 source recipe 或 layer，然後重新 build。
* **layer 優先級必須遵守**。使用 `bitbake-layers show-layers` 確認層疊順序。
* **conf/local.conf 和 bblayers.conf 的變更必須記錄**。這些是環境狀態的一部分。
* **大規模 build (如 `obmc-phosphor-image`) 需要 1-4 小時**。善用 SSTATE 快取。
* **修改 Phosphor 服務後**，驗證 D-Bus interface 是否正確註冊。
* **IPMI 相關變更**需要實際 BMC 硬體或 QEMU 模擬器來驗證。

---

## 必要工件

| 檔案 | 用途 |
|------|------|
| `feature_list.json` | 功能狀態的事實來源 |
| `harness-progress.md` | 工作階段日誌與目前已驗證狀態 |
| `init.sh` | 標準啟動與驗證路徑 |
| `session-handoff.md` | 較長工作階段可使用的精簡交接 |

---

## 完成定義

一個功能只有在下列條件**全部**成立時，才算完成：

1. **目標行為已完成實作**
   - Recipe/layer 變更已完成
   - 相關的 patch、conf 或 service 已就緒

2. **要求的驗證已實際執行**
   - `bitbake <target>` 成功編譯
   - 如果是 image，`obmc-phosphor-image` 或其他 target 可成功建構
   - 如果是 Phosphor 服務，D-Bus interface 可正常通訊
   - 如果有 QEMU 測試，測試通過

3. **證據已記錄**
   - `feature_list.json` 中的功能狀態已更新為 `completed`
   - `harness-progress.md` 中有 build 驗證的證據紀錄

4. **儲存庫仍可沿用標準啟動路徑重新開始工作**
   - `./init.sh` 仍能成功執行
   - `git status` 無意外遺留的修改

---

## Yocto Build 常見 Target

| Target | 用途 |
|--------|------|
| `obmc-phosphor-image` | 完整 BMC 系統影像 |
| `obmc-swupdate-image` | 韌體更新影像 |
| `phosphor-*` packages | 個别 Phosphor 服務 |
| `ast2700-*` | AST2700 相關套件 |
| `ipmi-*` | IPMI 相關套件 |

---

## 環境變數與 Shell 設定

進入 Yocto build 環境前：

```bash
# 設定 OpenBMC 環境 (會自動設定 build/ 目錄)
source openbmc-env

# 或手動設定
source oe-init-build-env

# 確認環境
printenv | grep -E "^(BUILD_DIR|MACHINE|DISTRO)"
```

---

## 工作階段結束前

**在結束工作階段之前，必須完成以下步驟：**

1. 更新 `harness-progress.md`，記錄本次工作階段的完成事項。
2. 更新 `feature_list.json`，反映所有功能狀態的變更。
3. 記錄任何尚未解決的風險或 blocker。
4. 執行 `git status`，確認沒有遺留的未追蹤檔案。
5. 在工作處於安全狀態後，以具描述性的訊息提交。
6. 讓下一個工作階段能立刻執行 `./init.sh` 並恢復工作。

### 提交訊息格式

```
[type]: 簡短描述

詳細說明（可選）
- 變更內容
- 驗證方式
- 相關功能 ID (如果有的話)
```

**type** 選項: `recipe`, `layer`, `conf`, `patch`, `phosphor`, `ipmi`, `build`, `docs`, `harness`

---

## 常見失敗模式與防範

| 失敗模式 | 防範措施 |
|----------|----------|
| Agent 編譯失敗但仍宣稱完成 | 必須在 feature_list.json 記錄 bitbake 的 exit code |
| Agent 修改了 build/ 輸出目錄 | 確認 build/ 在 .gitignore 中，只提交 source 變更 |
| Agent 忽略了 layer 依賴 | 使用 `bitbake-layers show-layers` 驗證 |
| 跨工作階段遺失上下文 | 強制更新 harness-progress.md |
| 大 build 中斷後狀態不一致 | 記錄 build 進度到 harness-progress.md |

---

## 快速參考命令

```bash
# 環境初始化
source openbmc-env

# 查看 layer 狀態
bitbake-layers show-layers

# 搜尋 recipe
bitbake-layers show-recipes | grep <keyword>

# 乾淨編譯
bitbake -c clean <target>
bitbake <target>

# 查看相依性
bitbake -g <target>  # 產生相依性圖

# QEMU 模擬
bitbake obmc-phosphor-image
runqemu qemux86-64

# 日誌查看
tail -f tmp/log/cooker.log
```

---

## 升級路徑

當專案成長時，可逐步加入更多 Harness 機制：

1. **基礎 (本檔案)**: AGENTS.md + feature_list.json + harness-progress.md + init.sh
2. **進階**: 加入 automated build verification、CI pipeline 整合
3. **完整**: 加入 observability、ablation study、多 agent 協調

---

> **設計理念**: Model is smart, Harness makes it reliable.  
> 這份規範不替模型寫程式碼，而是建立讓模型可靠運作的環境。
