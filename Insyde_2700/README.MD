📁 建立的檔案清單

檔案	大小	用途
AGENTS.md	6,231 bytes	根目錄指令檔案 — 代理操作規範
feature_list.json	7,411 bytes	功能追蹤器 — 13 個功能的狀態管理
claude-progress.md	1,987 bytes	進度日誌 — 工作階段記錄
init.sh	4,073 bytes	啟動腳本 — 環境驗證腳本
session-handoff.md	2,055 bytes	工作階段交接文件

🎯 核心設計理念

1. AGENTS.md 包含：

啟動流程：6 步驟標準化啟動程序
工作規則：核心原則 + OpenBMC/Yocto 特定規則（如 .bbappend 優先、layer 優先級）
完成定義：5 項完成條件（實作、建構、驗證、記錄、提交）
專案結構速查：meta-layer 架構說明和優先級
失敗模式警示：5 種需要停止並回報的情況
2. feature_list.json 包含：

13 個功能項目，涵蓋 BMC 所有核心功能：
F001: 環境建置與基礎驗證（critical）
F004: 電源管理（critical）
F008: IPMI 協議支援（critical）
F002/F003/F005/F007/F009/F011: 高優先級功能
F006/F010/F012: 中等優先級功能
F013: 規格文件修正（低優先級）
每個功能包含：驗證步驟、依賴關係、規格文件對應章節
3. claude-progress.md 包含：

最新狀態追蹤
已驗證狀態表格
工作階段記錄範本
快速參考指令和檔案
4. init.sh 包含：

6 步驟環境驗證（目錄、Git、必要檔案、meta-layer、submodule、建構環境）
自動偵測並回報環境狀態
提供下一步建議
5. session-handoff.md 包含：

工作階段交接模板
Blocker/Risk 追蹤
環境狀態記錄
📌 使用建議
首次使用：在 WSL2/Linux 環境中執行 ./init.sh 確認環境狀態
開始開發：閱讀 claude-progress.md 和 feature_list.json
每次工作階段結束：更新 claude-progress.md、feature_list.json 和 session-handoff.md
下次工作階段開始：執行 ./init.sh → 讀取 claude-progress.md → 繼續工作
