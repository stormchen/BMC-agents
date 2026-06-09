# BMC 功能規格說明書 (Function Specification)

**專案名稱**: AST2700 OpenBMC Platform  
**版本**: 1.0  
**日期**: 2024  
**平台**: ASPEED AST2700 BMC Controller

---

## 📋 目錄

1. [系統概述](#1-系統概述)
2. [硬體管理功能](#2-硬體管理功能)
3. [電源管理功能](#3-電源管理功能)
4. [溫度與風扇控制](#4-溫度與風扇控制)
5. [系統監控與日誌](#5-系統監控與日誌)
6. [韌體更新管理](#6-韌體更新管理)
7. [網路與通訊](#7-網路與通訊)
8. [安全與認證](#8-安全與認證)
9. [管理介面](#9-管理介面)
10. [D-Bus 服務架構](#10-d-bus-服務架構)
11. [API 介面規格](#11-api-介面規格)
12. [系統配置管理](#12-系統配置管理)
13. [版本資訊與更新歷史](#13-版本資訊與更新歷史)
14. [參考文件](#14-參考文件)
15. [附錄](#15-附錄)

---

## 1. 系統概述

### 1.1 系統架構

```
┌─────────────────────────────────────────────────────────────┐
│                    BMC System Architecture                  │
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Application Layer (Userspace)            │  │
│  │  ┌─────────┬─────────┬─────────┬─────────┬─────────┐  │
│  │  │  Web UI │ Redfish │  IPMI   │  SNMP   │ SSH/SOL │  │
│  │  └─────────┴─────────┴─────────┴─────────┴─────────┘  │
│  └───────────────────────────────────────────────────────┘  │
│                              │                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    D-Bus Bus                          │  │
│  │         (sdbusplus - Service Communication)           │  │
│  └───────────────────────────────────────────────────────┘  │
│                              │                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Service Layer (systemd + phosphor)       │  │
│  │  ┌──────────┬──────────┬──────────┬──────────┐       │  │
│  │  │  Power   │  Sensor  │  Fan     │ Network  │ ...   │  │
│  │  │ Manager  │  Reader  │ Control  │  Manager │       │  │
│  │  └──────────┴──────────┴──────────┴──────────┘       │  │
│  └───────────────────────────────────────────────────────┘  │
│                              │                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │               Linux Kernel (5.15.x / 6.1.x)           │  │
│  │  ┌──────────┬──────────┬──────────┬──────────┐       │  │
│  │  │  I2C     │  GPIO    │  SPI     │  UART    │       │  │
│  │  │ Drivers  │ Drivers  │ Drivers  │ Drivers  │       │  │
│  │  └──────────┴──────────┴──────────┴──────────┘       │  │
│  └───────────────────────────────────────────────────────┘  │
│                              │                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │           ASPEED AST2700 BMC Hardware                │  │
│  │  ┌──────────┬──────────┬──────────┬──────────┐       │  │
│  │  │ ARM Cortex │  I2C   │  GPIO    │  SPI     │       │  │
│  │  │  A53 Core │ Busses  │  Matrix  │  Flash   │       │  │
│  │  └──────────┴──────────┴──────────┴──────────┘       │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 核心技術棧

| 層級 | 技術 | 說明 |
|------|------|------|
| **建構系統** | Yocto Project / BitBake | 嵌入式 Linux 發行版建構 |
| **核心** | Linux Kernel 5.15+ | 內建 ASPEED 驅動支援 |
| **初始化** | systemd | 服務管理與開機流程 |
| **通訊機制** | D-Bus (sdbusplus) | 服務間 IPC 通訊 |
| **管理協議** | IPMI 2.0 / Redfish | 標準化管理 API |
| **韌體** | U-Boot | 開機加載器 |

### 1.3 系統需求

| 項目 | 規格 |
|------|------|
| **CPU** | ASPEED AST2700 (ARM Cortex-A53) |
| **記憶體** | 最小 512MB DDR4 (建議 1GB) |
| **儲存** | 最小 128MB SPI Flash (建議 256MB+) |
| **網路** | 10/100/1000 Mbps Ethernet |
| **作業系統** | OpenBMC (Yocto Based) |

---

## 2. 硬體管理功能

### 2.1 硬體庫存管理 (Inventory Manager)

**服務名稱**: `phosphor-inventory-manager`  
**D-Bus 介面**: `xyz.openbmc_project.Inventory.Manager`

| 功能 | 說明 | 資料來源 |
|------|------|----------|
| **FRU 讀取** | 讀取現場可更換單元資訊 | SPI EEPROM / I2C |
| **資產標籤** | 系統資產識別碼管理 | FRU 記憶體 |
| **產品資訊** | 產品型號、序列號、製造商 | FRU / SMBIOS |
| **元件偵測** | 自動偵測硬體元件存在 | Device Tree / I2C |
| **屬性管理** | 元件屬性 (Part Number, Revision) | D-Bus Properties |

**支援的 FRU 類型**:
- Baseboard FRU (主機板)
- Chassis FRU (機箱)
- Product FRU (產品資訊)
- Board Mgmt Controller FRU (BMC 本身)

### 2.2 感測器監控 (Sensor Management)

**服務名稱**: `phosphor-hwmon` / `dbus-sensors`  
**D-Bus 介面**: `xyz.openbmc_project.Sensor.Value`

| 感測器類型 | 測量項目 | 單位 | 通訊介面 |
|-----------|---------|------|---------|
| **溫度感測器** | CPU、VRM、環境溫度 | °C | I2C / IPMB |
| **電壓感測器** | 12V、5V、3.3V、1.05V | mV | I2C / ADC |
| **電流感測器** | 電源輸入電流 | Ampere | I2C |
| **風速感測器** | 風扇轉速 | RPM | PWM / Tach |
| **功率感測器** | 系統功率消耗 | Watts | I2C |
| **實體狀態** | 元件在位偵測 | Boolean | GPIO |

**感測器屬性**:
```yaml
Sensor:
  - Reading: 當前讀數
  - Status: 狀態 (OK, Warning, Critical)
  - Thresholds:
      - WarningUpper: 警告上限
      - CriticalUpper: 嚴重上限
      - WarningLower: 警告下限
      - CriticalLower: 嚴重下限
  - Discrete: 離散狀態位元
```

### 2.3 GPIO 管理

**服務名稱**: GPIO 主要由 kernel gpiolib / libgpiod 管理  
**D-Bus 介面**: 部分平台可能有自定義 D-Bus service（非標準化 D-Bus 介面）

| 功能 | 說明 |
|------|------|
| **GPIO 配置** | 輸入/輸出模式設定 |
| **GPIO 讀取** | 讀取 GPIO 狀態 |
| **GPIO 寫入** | 設定 GPIO 輸出 |
| **Edge 偵測** | 上升/下降沿中斷 |
| **GPIO 矩陣** | AST2700 GPIO 矩陣配置 |

### 2.4 LED 控制

**服務名稱**: `obmc-leds`  
**D-Bus 介面**: `xyz.openbmc_project.LED.Physical`

| LED 功能 | 說明 |
|---------|------|
| **狀態指示** | 系統狀態 (正常/警告/錯誤) |
| **定位燈** | 實體位置識別 |
| **故障指示** | 特定元件故障指示 |
| **活動指示** | 網路/儲存活動 |

**LED 顏色支援**:
- 單色 (Single Color)
- 雙色 (Dual Color - RGB)
- 三色 (Tri-color)

### 2.5 按鍵管理 (Button Control)

**服務名稱**: `obmc-phosphor-buttons`  
**D-Bus 介面**: `xyz.openbmc_project.Button`

| 按鍵 | 功能 |
|------|------|
| **ID 按鍵** | 觸發定位燈 |
| **重置按鍵** | BMC 重置 |
| **電源按鍵** | 主機電源控制 |
| **用戶按鍵** | 可自定義功能 |

---

## 3. 電源管理功能

### 3.1 主機電源控制 (Power Control)

**服務名稱**: `obmc-phosphor-power`  
**D-Bus 介面**: `xyz.openbmc_project.Control.Power`

| 電源狀態 | 說明 | 觸發條件 |
|---------|------|---------|
| **On** | 主機開啟 | 電源按鍵 / D-Bus API |
| **Off** | 主機關閉 | 電源按鍵 / D-Bus API |
| **PowerCycle** | 電源循環 | 遠端命令 |
| **ForceOff** | 強制關閉 | 緊急情況 |
| **PushPowerButton** | 模擬按鍵 | 軟體觸發 |

**電源控制流程**:
```
┌─────────────┐     ┌────────────────┐     ┌─────────────┐
│   Off State │────>│  PoweringOn    │────>│   On State  │
│             │     │   (Powering    │     │  (Running)  │
└─────────────┘     │    Up)         │     └──────┬──────┘
       ▲            └────────────────┘             │
       │                                           ▼
       │            ┌────────────────┐     ┌─────────────┐
       │            │  PoweringOff   │<────│  Force Off  │
       │            │   (Powering    │     └─────────────┘
       │            │    Down)       │
       │            └────────────────┘
       │                   │
       └───────────────────┘
```

### 3.2 電源序列控制 (Power Sequencer)

**服務名稱**: `phosphor-power-systemd-links-sequencer`

| 功能 | 說明 |
|------|------|
| **電源軌序列** | 控制電源軌開啟順序 |
| **延遲控制** | 電源軌間延遲時間 |
| **電壓調節器** | 軟體控制電壓調節器 |
| **電源故障** | 電源故障偵測與恢復 |

### 3.3 PSU 管理 (Power Supply Unit)

**服務名稱**: `phosphor-psu-software-manager`

| 功能 | 說明 |
|------|------|
| **PSU 偵測** | 電源供應器在位偵測 |
| **PSU 狀態** | 正常/故障狀態監控 |
| **PSU 資訊** | 型號、序列號、功率額定 |
| **冗餘管理** | PSU 冗餘模式配置 |

### 3.4 主機失敗重啟 (Host Failure Reboot)

**服務名稱**: `obmc-host-failure-reboots`

| 重啟模式 | 說明 |
|---------|------|
| **Watchdog Reset** | 看門狗超時重啟 |
| **Host Error Reset** | 主機錯誤重啟 |
| **Power Cycle** | 電源循環 |
| **Cold Reset** | 冷重置 |

---

## 4. 溫度與風扇控制

### 4.1 風扇控制架構 (Fan Control)

**服務名稱**: `phosphor-fan-control`  
**D-Bus 介面**: `xyz.openbmc_project.Control.Fan.Tach`

**控制模式**:
```
┌─────────────────────────────────────────────────────────┐
│                    Fan Control Modes                    │
├─────────────────────────────────────────────────────────┤
│  1. Manual Mode                                         │
│     - 手動設定風扇速度 (0-100%)                         │
│  2. Automatic Mode                                      │
│     - 基於溫度自動調整風扇速度                          │
│  3. PID Control                                         │
│     - 比例 - 積分 - 微分控制演算法                        │
│  4. Zone Control                                        │
│     - 區域化溫度控制                                    │
└─────────────────────────────────────────────────────────┘
```

### 4.2 風扇配置管理

| 配置項目 | 說明 | 檔案位置 |
|---------|------|---------|
| **風扇配置** | 風扇數量、位置、極性 | `phosphor-fan-control-fan-config` |
| **區域條件** | 溫度區域與風扇關聯 | `phosphor-zone-conditions-config` |
| **區域配置** | 控制區域定義 | `phosphor-zone-config` |
| **監控配置** | 風扇監控參數 | `phosphor-fan-monitor-config` |
| **存在配置** | 風扇在位偵測 | `phosphor-fan-presence-config` |
| **事件配置** | 風扇事件觸發 | `phosphor-fan-control-events-config` |

### 4.3 溫度區域管理 (Zone Management)

| 區域類型 | 說明 |
|---------|------|
| **Hotspot Zone** | 高溫區域 (CPU、GPU) |
| **Ambient Zone** | 環境溫度區域 |
| **Intake Zone** | 進氣口溫度 |
| **Exhaust Zone** | 排氣口溫度 |

**PID 控制參數**:
```yaml
PIDControl:
  - Proportional: P 增益值
  - Integral: I 增益值
  - Derivative: D 增益值
  - Setpoint: 目標溫度
  - OutputMin: 最小輸出 (0%)
  - OutputMax: 最大輸出 (100%)
```

### 4.4 風扇故障處理

| 故障類型 | 處理方式 |
|---------|---------|
| **風扇停轉** | 觸發警報、提高其他風扇速度 |
| **風扇超速** | 降低速度、記錄事件 |
| **風扇不存在** | 記錄事件、調整控制策略 |
| **溫度過高** | 風扇全速、主機降頻/關機 |

---

## 5. 系統監控與日誌

### 5.1 系統事件日誌 (SEL - System Event Log)

**服務名稱**: `phosphor-ipmi-sel` / `sel-logger`  
**D-Bus 介面**: `xyz.openbmc_project.Logging`

| SEL 類型 | 說明 |
|---------|------|
| **System Event** | 系統事件記錄 |
| **FRU Event** | FRU 相關事件 |
| **Sensor Event** | 感測器閾值事件 |
| **Message Event** | 一般訊息事件 |

**事件嚴重程度**:
- `OK` - 正常
- `Warning` - 警告
- `Critical` - 嚴重
- `Non-Recoverable` - 無法恢復

### 5.2 日誌管理 (Logging)

**服務名稱**: `phosphor-logging`  
**D-Bus 介面**: `xyz.openbmc_project.Logging`

| 日誌功能 | 說明 |
|---------|------|
| **日誌記錄** | 系統日誌記錄 |
| **日誌轉送** | 遠端日誌伺服器 (Syslog) |
| **日誌輪替** | 日誌檔案輪替 |
| **日誌篩選** | 基於嚴重程度篩選 |

**日誌嚴重程度**:
```
DEBUG < INFO < NOTICE < WARNING < ERROR < CRITICAL < ALERT < EMERG
```

### 5.3 健康監控 (Health Monitoring)

**說明**: Health 狀態多由 Redfish/bmcweb 根據各 D-Bus 物件 Status 聚合（`phosphor-health` 不一定是 OpenBMC 標準服務）

| 監控項目 | 說明 |
|---------|------|
| **系統健康** | 整體系統健康狀態 |
| **元件健康** | 個別元件健康狀態 |
| **預測性維護** | 基於趨勢的預測 |
| **健康報告** | 健康狀態報告 |

### 5.4 效能監控 (Telemetry)

**服務名稱**: `telemetry` / `phosphor-hwmon`

| 監控項目 | 說明 |
|---------|------|
| **CPU 使用率** | CPU 負載監控 |
| **記憶體使用** | 記憶體使用率 |
| **網路流量** | 網路流量統計 |
| **儲存使用** | 儲存空間使用 |

### 5.5 NVMe 監控

**服務名稱**: OEM/Custom Service（`phosphor-nvme` 不一定是 OpenBMC 標準服務；若為自家 NVMe status service 應標記為 OEM/custom）

| 功能 | 說明 |
|------|------|
| **NVMe 狀態** | NVMe 裝置狀態監控 |
| **SMART 資料** | SMART 健康資料讀取 |
| **溫度監控** | NVMe 溫度監控 |
| **錯誤統計** | NVMe 錯誤統計 |

---

## 6. 韌體更新管理

### 6.1 軟體管理 (Software Manager)

**服務名稱**: `phosphor-software-manager`  
**D-Bus 介面**: `xyz.openbmc_project.Software`

| 功能 | 說明 |
|------|------|
| **映像上傳** | 上傳韌體映像檔 |
| **映像驗證** | 數位簽章驗證 |
| **映像安裝** | 韌體安裝到目標 |
| **映像激活** | 韌體版本切換 |
| **版本管理** | 多版本管理 |

**更新流程**:
```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  Upload │───>│ Validate│───>│  Install│───>│ Activate│───>│ Reboot  │
│  Image  │    │  Image  │    │  Image  │    │  Image  │    │ System  │
└─────────┘    └─────────┘    └─────────┘    └─────────┘    └─────────┘
```

### 6.2 韌體映像類型

| 映像類型 | 說明 | 目標位置 |
|---------|------|---------|
| **BMC Firmware** | BMC 韌體 (U-Boot + Kernel + Rootfs) | SPI Flash |
| **Host BIOS** | 主機 BIOS/UEFI | SPI Flash |
| **Option ROM** | 擴充卡 ROM | PCI ROM |
| **PLD/FPGA** | 可程式邏輯裝置 | CPLD/FPGA |

### 6.3 韌體簽署 (Image Signing)

**服務名稱**: `phosphor-image-signing`

| 功能 | 說明 |
|------|------|
| **簽署金鑰** | 私鑰簽署映像 |
| **驗證金鑰** | 公鑰驗證映像 |
| **金鑰管理** | 金鑰儲存與管理 |
| **安全啟動** | Verified Boot 支援 |

### 6.4 主機韌體更新 (Host Firmware Update)

**服務名稱**: `phosphor-hostfw-image`

| 功能 | 說明 |
|------|------|
| **IPMB 更新** | 透過 IPMB 更新主機 BIOS |
| **SPI 更新** | 直接 SPI Flash 更新 |
| **Host 協同** | 與主機作業系統協同更新 |

### 6.5 更新失敗恢復

| 恢復機制 | 說明 |
|---------|------|
| **Dual Bank** | 雙銀行切換 |
| **Rollback** | 自動回滾到前一個版本 |
| **Recovery Mode** | 恢復模式啟動 |
| **Noverify Mode** | 無驗證模式 (緊急修復) |

---

## 7. 網路與通訊

### 7.1 網路管理 (Network Manager)

**服務名稱**: `phosphor-network`  
**D-Bus 介面**: `xyz.openbmc_project.Network`

| 功能 | 說明 |
|------|------|
| **IP 配置** | IPv4/IPv6 配置 |
| **DNS 配置** | DNS 伺服器設定 |
| **NTP 配置** | 時間同步設定 |
| **網路介面** | 網路介面管理 |
| **MAC 地址** | MAC 地址管理 |

**網路模式**:
- **Static IP** - 靜態 IP 配置
- **DHCP** - 動態 IP 獲取
- **IPv6** - IPv6 支援 (SLAAC / DHCPv6)

### 7.2 IPMI 協議支援

**服務名稱**: `phosphor-ipmi-*`  
**D-Bus 介面**: `xyz.openbmc_project.IPMI`

| IPMI 功能 | 說明 | 介面 |
|---------|------|------|
| **IPMI LAN** | 網路介面 (RMCP+) | `phosphor-ipmi-net` |
| **IPMI BT** | 串列介面 (Block Transfer) | `phosphor-ipmi-bt` |
| **IPMI KCS** | 鍵盤控制器 | `phosphor-ipmi-kcs` |
| **IPMI SSIF** | 單線串列介面 | `phosphor-ipmi-ssif` |
| **IPMI IPMB** | 主機通訊 | `phosphor-ipmi-ipmb` |

**IPMI 命令集**:
- **Chassis Control** - 機箱控制 (電源、重置)
- **Sensor Reading** - 感測器讀取
- **SEL Management** - 事件日誌管理
- **FRU Reading** - FRU 讀取
- **SOL** - Serial Over LAN
- ** BMC Watchdog** - 看門狗控制

### 7.3 Redfish API

**服務名稱**: `bmcweb`  
**協議**: RESTful HTTP/HTTPS

| Redfish 資源 | 說明 |
|-------------|------|
| **/redfish/v1** | Redfish 根節點 |
| **/Systems** | 系統資訊 |
| **/Managers** | BMC 管理資訊 |
| **/Chassis** | 機箱資訊 |
| **/Thermal** | 溫度與風扇 |
| **/Power** | 電源資訊 |
| **/UpdateService** | 韌體更新 |
| **/EventService** | 事件訂閱 |
| **/SessionService** | 會話管理 |

### 7.4 SNMP 支援

**服務名稱**: `phosphor-snmp`  
**協議**: SNMP v1/v2c/v3

| SNMP 功能 | 說明 |
|---------|------|
| **MIB 支援** | IPMI-MIB、HOST-RES-MIB |
| **Trap 發送** | 事件 Trap 通知 |
| **GET/SET** | 讀取/設定 MIB 物件 |
| **SNMPv3** | 安全性支援 |

### 7.5 遠端控制台

| 功能 | 協議 | 說明 |
|------|------|------|
| **SSH** | SSH v2 | 安全 Shell 存取 |
| **SOL** | IPMI LAN | Serial Over LAN |
| **KVM over IP** | HTTP/WebSocket | 遠端控制台 |
| **Virtual Media** | HTTP/WebSocket | 虛擬光碟機/USB |

### 7.6 MCTP 支援

**服務名稱**: `libmctp` / `pldm`  
**協議**: MCTP (Management Component Transport Protocol)

| MCTP 功能 | 說明 |
|---------|------|
| **MCTP over LAN** | 網路傳輸 |
| **MCTP over SPI** | SPI 傳輸 |
| **MCTP over I2C** | I2C 傳輸 |
| **PLDM** | Platform Data Management |

---

## 8. 安全與認證

### 8.1 用戶管理 (User Management)

**服務名稱**: `phosphor-user-manager`  
**D-Bus 介面**: `xyz.openbmc_project.User.Manager`

| 用戶功能 | 說明 |
|---------|------|
| **用戶創建** | 新增用戶帳號 |
| **用戶刪除** | 刪除用戶帳號 |
| **用戶修改** | 修改用戶屬性 |
| **用戶查詢** | 查詢用戶資訊 |
| **權限管理** | 用戶權限設定 |

**用戶權限等級**:
- **Administrator** - 管理員 (完全存取)
- **Operator** - 操作員 (讀寫存取)
- **Read Only** - 唯讀存取
- **Audit** - 審計 (唯讀日誌)

### 8.2 認證機制

| 認證方式 | 說明 |
|---------|------|
| **本地認證** | 本地用戶資料庫 |
| **LDAP** | LDAP 伺服器認證 |
| **RADIUS** | RADIUS 認證 |
| **802.1X** | 網路端口認證 |
| **API Key** | API 金鑰認證 |

### 8.3 安全通訊

| 協議 | 加密方式 | 說明 |
|------|---------|------|
| **HTTPS** | TLS 1.2/1.3 | Web 介面加密 |
| **SSH** | RSA/ECDSA | Shell 存取加密 |
| **IPMI 2.0** | RMCP+ | IPMI 加密 |
| **Redfish** | TLS 1.2/1.3 | Redfish API 加密 |

### 8.4 憑證管理

**服務名稱**: `phosphor-certificate-manager` / `bmcweb certificate` 相關功能

| 功能 | 說明 |
|------|------|
| **CA 憑證** | 認證機構憑證 |
| **伺服器憑證** | HTTPS 伺服器憑證 |
| **客戶端憑證** | 客戶端認證憑證 |
| **憑證輪替** | 憑證自動更新 |

### 8.5 安全功能

| 功能 | 說明 |
|------|------|
| **登入失敗鎖定** | 多次失敗後鎖定帳號 |
| **會話超時** | 閒置會話自動登出 |
| **密碼強度** | 密碼複雜度要求 |
| **密碼輪替** | 強制密碼定期更新 |
| **存取控制** | 基於角色的存取控制 (RBAC) |
| **日誌審計** | 安全事件審計日誌 |

### 8.6 安全啟動 (Secure Boot)

| 功能 | 說明 |
|------|------|
| **Verified Boot** | 啟動驗證 |
| **金鑰封存** | 金鑰安全儲存 |
| **映像驗證** | 韌體映像驗證 |
| **安全量測** | 啟動量測記錄 |

---

## 9. 管理介面

### 9.1 Web 管理介面 (Web UI)

**服務名稱**: `webui-vue` / `phosphor-webui`  
**技術**: Vue.js + REST API

| 功能模組 | 說明 |
|---------|------|
| **儀表板** | 系統概覽、健康狀態 |
| **硬體監控** | 溫度、風扇、電源 |
| **電源控制** | 主機電源開關 |
| **韌體更新** | 映像上傳與更新 |
| **用戶管理** | 用戶帳號管理 |
| **網路配置** | 網路設定 |
| **事件日誌** | SEL 查看 |
| **遠端控制台** | SOL / KVM |
| **虛擬媒體** | ISO/USB 掛載 |

### 9.2 REST API (Redfish)

**協議**: HTTP/HTTPS  
**格式**: JSON

**主要 API 端點**（OpenBMC 常見路徑；實際路徑需依平台確認）:
```
GET    /redfish/v1/                         - Redfish 根節點
GET    /redfish/v1/Systems/system/          - 系統資訊
GET    /redfish/v1/Managers/bmc/            - BMC 資訊
GET    /redfish/v1/Chassis/chassis/         - 機箱資訊
GET    /redfish/v1/Chassis/chassis/Thermal/ - 溫度資訊
GET    /redfish/v1/Chassis/chassis/Power/   - 電源資訊
POST   /redfish/v1/UpdateService/Actions/UpdateService.SimpleUpdate
GET    /redfish/v1/EventService/            - 事件服務
POST   /redfish/v1/SessionService/Sessions
```

### 9.3 IPMI 命令介面

**工具**: `ipmitool`

**常用命令**:
```bash
# 電源控制
ipmitool -I lanplus -H <bmc_ip> power on
ipmitool -I lanplus -H <bmc_ip> power off
ipmitool -I lanplus -H <bmc_ip> power cycle

# 感測器讀取
ipmitool -I lanplus -H <bmc_ip> sensor list
ipmitool -I lanplus -H <bmc_ip> sdr list

# FRU 資訊
ipmitool -I lanplus -H <bmc_ip> fru print

# SEL 日誌
ipmitool -I lanplus -H <bmc_ip> sel list
ipmitool -I lanplus -H <bmc_ip> sel clear

# SOL 控制台
ipmitool -I lanplus -H <bmc_ip> sol activate
```

### 9.4 串列控制台 (SOL)

| 功能 | 說明 |
|------|------|
| **SOL 激活** | 啟動 SOL 會話 |
| **SOL 停用** | 結束 SOL 會話 |
| **SOL 重設** | 重設 SOL 連線 |
| **SOL 配置** | 波特率、資料位元等設定 |

### 9.5 虛擬媒體 (Virtual Media)

| 功能 | 說明 |
|------|------|
| **ISO 掛載** | 遠端 ISO 映像掛載 |
| **USB 重定向** | USB 裝置重定向 |
| **Floppy 模擬** | 軟碟機模擬 |
| **媒體彈出** | 虛擬媒體彈出 |

---

## 10. D-Bus 服務架構

### 10.1 D-Bus 服務清單

| 服務名稱 | 物件路徑 | 介面 | 說明 |
|---------|---------|------|------|
| **xyz.openbmc_project.Control.Power** | `/xyz/openbmc_project/control/power0` | PowerControl | 電源控制 |
| **xyz.openbmc_project.Control.Fan.Tach** | `/xyz/openbmc_project/control/fan0` | FanControl | 風扇控制 |
| **xyz.openbmc_project.Inventory.Manager** | `/xyz/openbmc_project/inventory` | InventoryManager | 庫存管理 |
| **xyz.openbmc_project.Sensor.Value** | `/xyz/openbmc_project/sensors/...` | SensorValue | 感測器值 |
| **xyz.openbmc_project.Logging** | `/xyz/openbmc_project/logging` | Logging | 日誌管理 |
| **xyz.openbmc_project.Software** | `/xyz/openbmc_project/software/...` | Software | 軟體管理 |
| **xyz.openbmc_project.Network** | `/xyz/openbmc_project/network/...` | Network | 網路管理 |
| **xyz.openbmc_project.User.Manager** | `/xyz/openbmc_project/user_manager` | UserManager | 用戶管理 |
| **xyz.openbmc_project.Time** | `/xyz/openbmc_project/time/RTC0` | Time | 時間管理 |
| **xyz.openbmc_project.Storage** | `/xyz/openbmc_project/storage/...` | Storage | 儲存管理 |

### 10.2 D-Bus 通訊模式

```
┌─────────────────────────────────────────────────────────────┐
│                      D-Bus Architecture                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Client A  │    │   Client B  │    │   Client C  │     │
│  │  (Web UI)   │    │  (IPMI)     │    │  (Redfish)  │     │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘     │
│         │                  │                  │             │
│         └──────────────────┼──────────────────┘             │
│                            │                                │
│                  ┌─────────▼─────────┐                      │
│                  │    D-Bus Bus      │                      │
│                  │  (System Bus)     │                      │
│                  └─────────┬─────────┘                      │
│                            │                                │
│         ┌──────────────────┼──────────────────┐            │
│         │                  │                  │             │
│  ┌──────▼──────┐    ┌──────▼──────┐    ┌──────▼──────┐     │
│  │  Service A  │    │  Service B  │    │  Service C  │     │
│  │  (Power)    │    │  (Sensor)   │    │  (Network)  │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 10.3 實體管理器 (Entity Manager)

**服務名稱**: `phosphor-entity-manager`

| 功能 | 說明 |
|------|------|
| **實體圖表** | 硬體實體階層結構 |
| **實體屬性** | 實體屬性管理 |
| **實體關係** | 實體間關係定義 |
| **D-Bus 物件** | 自動生成 D-Bus 物件 |

---

## 11. API 介面規格

### 11.1 Redfish API 規格

#### 11.1.1 系統資訊

**端點**: `GET /redfish/v1/Systems/1/`

**回應範例**:
```json
{
  "@odata.id": "/redfish/v1/Systems/1",
  "@odata.type": "#ComputerSystem.v1_0_0.ComputerSystem",
  "Id": "1",
  "Name": "System One",
  "Manufacturer": "GigaByte Technology",
  "Model": "AST2700-BMC",
  "PartNumber": "GB-AST2700-001",
  "SerialNumber": "GB123456789",
  "SKU": "GB-AST2700",
  "Status": {
    "State": "Enabled",
    "Health": "OK"
  },
  "PowerState": "On",
  "IndicatorLED": "Lit"
}
```

#### 11.1.2 溫度資訊

**端點**: `GET /redfish/v1/Chassis/1/Thermal/`

**回應範例**:
```json
{
  "@odata.id": "/redfish/v1/Chassis/1/Thermal",
  "@odata.type": "#Thermal.v1_0_0.Thermal",
  "Id": "Thermal",
  "Name": "Thermal",
  "Temperatures": [
    {
      "Id": "CPU_TEMP",
      "Name": "CPU Temperature",
      "SensorType": "Temperature",
      "ReadingCelsius": 45.5,
      "Status": {
        "State": "Enabled",
        "Health": "OK"
      },
      "UpperThresholdCritical": 85.0,
      "UpperThresholdNonCritical": 75.0
    }
  ],
  "Fans": [
    {
      "Id": "Fan1",
      "Name": "Fan 1",
      "Status": {
        "State": "Enabled",
        "Health": "OK"
      },
      "ReadingRPM": 5000
    }
  ]
}
```

#### 11.1.3 電源資訊

**端點**: `GET /redfish/v1/Chassis/1/Power/`

**回應範例**:
```json
{
  "@odata.id": "/redfish/v1/Chassis/1/Power",
  "@odata.type": "#Power.v1_0_0.Power",
  "Id": "Power",
  "Name": "Power",
  "PowerSupplies": [
    {
      "Id": "PSU1",
      "Name": "Power Supply 1",
      "Status": {
        "State": "Enabled",
        "Health": "OK"
      },
      "LineInputVoltageV": 110.5,
      "LastPowerOutputWatts": 250
    }
  ]
}
```

#### 11.1.4 韌體更新

**端點**: `POST /redfish/v1/UpdateService/Actions/UpdateService.SimpleUpdate`

**請求範例**:
```json
{
  "Image": "https://example.com/firmware.bin",
  "InstallInOrder": ["/redfish/v1/UpdateService/FirmwareInventory/BMC.Firmware"]
}
```

### 11.2 IPMI 命令規格

#### 11.2.1 電源控制

| 命令 | NetFn | CMD | 說明 |
|------|-------|-----|------|
| **Get Chassis Status** | 0x00 | 0x02 | 讀取機箱狀態 |
| **Chassis Control** | 0x00 | 0x06 | 電源控制 |

**Chassis Control 參數**（IPMI 2.0 標準）:
```
Request:
  Chassis Control:
    0x00 = Power Down
    0x01 = Power Up
    0x02 = Power Cycle
    0x03 = Hard Reset
    0x04 = Pulse Diag
    0x05 = Soft Shutdown
```

#### 11.2.2 感測器讀取

| 命令 | NetFn | CMD | 說明 |
|------|-------|-----|------|
| **Get Sensor Reading** | 0x04 | 0x2D | 讀取感測器值 |
| **Get SDR Repository Info** | 0x04 | 0x10 | SDR 儲存庫資訊 |
| **Get SDR** | 0x04 | 0x11 | 讀取 SDR 記錄 |

### 11.3 D-Bus API 規格

#### 11.3.1 電源控制

**介面**: `xyz.openbmc_project.Control.Power`

**方法**:
```
SetState(uint8 newState)
  - 0 = Off
  - 1 = On
  - 2 = PowerCycle
  - 3 = ForceOff
  - 4 = PushPowerButton
```

**屬性**:
```
State (uint8) - 當前電源狀態
```

#### 11.3.2 感測器讀取

**介面**: `xyz.openbmc_project.Sensor.Value`

**屬性**:
```
Value (double) - 感測器讀數
Status (uint8) - 感測器狀態
```

---

## 12. 系統配置管理

### 12.1 配置檔案位置

| 配置類型 | 位置 | 說明 |
|---------|------|------|
| **Machine Config** | `conf/machine/<machine>.conf` | 平台特定配置 |
| **Layer Config** | `conf/<layer>.conf` | Layer 配置 |
| **Local Config** | `build/conf/local.conf` | 本地配置 |
| **BBLayers** | `build/conf/bblayers.conf` | Layer 清單 |

### 12.2 硬體配置

| 配置項目 | 配置方式 | 說明 |
|---------|---------|------|
| **Device Tree** | `.dts` 檔案 | 硬體描述 |
| **I2C 配置** | Device Tree / 配置檔案 | I2C 裝置配置 |
| **GPIO 配置** | Device Tree / 配置檔案 | GPIO 配置 |
| **網路配置** | `phosphor-network` | 網路參數 |

### 12.3 服務配置

| 服務 | 配置檔案 | 說明 |
|------|---------|------|
| **風扇控制** | `fan-control.conf` | 風扇控制參數 |
| **感測器** | `sensors.conf` | 感測器配置 |
| **網路** | `network.conf` | 網路配置 |
| **用戶** | `users.conf` | 用戶配置 |

### 12.4 開機流程

```
┌─────────────────────────────────────────────────────────┐
│                    BMC Boot Process                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. Power-On Reset (POR)                                │
│       │                                                 │
│       ▼                                                 │
│  2. AST2700 ROM Code                                    │
│       │                                                 │
│       ▼                                                 │
│  3. SPI Flash Initialization                            │
│       │                                                 │
│       ▼                                                 │
│  4. U-Boot Loader                                       │
│       │                                                 │
│       ├─► Hardware Initialization                       │
│       │    - DDR Training                               │
│       │    - Clock Configuration                        │
│       │    - Peripheral Setup                           │
│       │                                                 │
│       ▼                                                 │
│  5. Linux Kernel Boot                                   │
│       │                                                 │
│       ├─► Kernel Initialization                         │
│       │    - Driver Loading                             │
│       │    - Device Tree Parsing                        │
│       │                                                 │
│       ▼                                                 │
│  6. Initramfs / Init Script                             │
│       │                                                 │
│       ▼                                                 │
│  7. Rootfs Mount                                        │
│       │                                                 │
│       ▼                                                 │
│  8. systemd Init                                        │
│       │                                                 │
│       ├─► Target: obmc-mgr.target                       │
│       │                                                 │
│       ▼                                                 │
│  9. BMC Services Start                                  │
│       │                                                 │
│       ├─► phosphor-state-manager                        │
│       ├─► phosphor-dbus-configuration                   │
│       ├─► phosphor-network                              │
│       ├─► phosphor-power                                │
│       ├─► phosphor-hwmon                                │
│       ├─► phosphor-fan-control                          │
│       ├─► phosphor-ipmi-*                               │
│       └─► webui                                         │
│       │                                                 │
│       ▼                                                 │
│  10. BMC Ready                                          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 13. 版本資訊與更新歷史

| 版本 | 日期 | 說明 |
|------|------|------|
| 1.0 | 2024 | 初始版本 |

---

## 14. 參考文件

| 文件 | 連結 |
|------|------|
| **OpenBMC Docs** | https://github.com/openbmc/docs |
| **Redfish Spec** | https://www.dmtf.org/standards/redfish |
| **IPMI Spec** | https://www.intel.com/content/www/us/en/develop/articles/intel-intelligent-platform-management-interface.html |
| **Yocto Project** | https://www.yoctoproject.org |
| **ASPEED AST2700** | ASPEED 官方文件 |

---

## 15. 附錄

### 15.1 縮寫詞彙表

| 縮寫 | 完整名稱 | 說明 |
|------|---------|------|
| **BMC** | Baseboard Management Controller | 主機板管理控制器 |
| **IPMI** | Intelligent Platform Management Interface | 智慧平台管理介面 |
| **FRU** | Field Replaceable Unit | 現場可更換單元 |
| **SEL** | System Event Log | 系統事件日誌 |
| **SOL** | Serial Over LAN | 遠端串列控制台 |
| **KVM** | Keyboard Video Mouse | 鍵盤視訊滑鼠 |
| **PLDM** | Platform Data Management | 平台數據管理 |
| **MCTP** | Management Component Transport Protocol | 管理元件傳輸協議 |
| **SDR** | Sensor Data Record | 感測器數據記錄 |
| **PSU** | Power Supply Unit | 電源供應器 |
| **GPIO** | General Purpose Input/Output | 通用輸入輸出 |
| **I2C** | Inter-Integrated Circuit | 積體電路間通訊 |
| **SPI** | Serial Peripheral Interface | 串列周邊介面 |
| **PWM** | Pulse Width Modulation | 脈寬調變 |

### 15.2 聯絡資訊

| 項目 | 資訊 |
|------|------|
| **專案** | GigaByte AST2700 OpenBMC |
| **維護者** | GigaByte BMC Team |
| **支援** | 內部技術支援 |

---

*文件結束*