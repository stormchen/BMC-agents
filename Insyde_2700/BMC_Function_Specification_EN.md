# BMC Function Specification Document

**Project Name**: AST2700 OpenBMC Platform  
**Version**: 1.0  
**Date**: 2024  
**Platform**: ASPEED AST2700 BMC Controller

---

## 📋 Table of Contents

1. [System Overview](#1-system-overview)
2. [Hardware Management Functions](#2-hardware-management-functions)
3. [Power Management Functions](#3-power-management-functions)
4. [Temperature and Fan Control](#4-temperature-and-fan-control)
5. [System Monitoring and Logging](#5-system-monitoring-and-logging)
6. [Firmware Update Management](#6-firmware-update-management)
7. [Network and Communication](#7-network-and-communication)
8. [Security and Authentication](#8-security-and-authentication)
9. [Management Interfaces](#9-management-interfaces)
10. [D-Bus Service Architecture](#10-d-bus-service-architecture)
11. [API Interface Specifications](#11-api-interface-specifications)
12. [System Configuration Management](#12-system-configuration-management)
13. [Version Information and Update History](#13-version-information-and-update-history)
14. [Reference Documents](#14-reference-documents)
15. [Appendix](#15-appendix)

---

## 1. System Overview

### 1.1 System Architecture

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

### 1.2 Core Technology Stack

| Layer | Technology | Description |
|------|------|------|
| **Build System** | Yocto Project / BitBake | Embedded Linux distribution build |
| **Core** | Linux Kernel 5.15+ | Built-in ASPEED driver support |
| **Initialization** | systemd | Service management and boot process |
| **Communication** | D-Bus (sdbusplus) | Inter-service IPC communication |
| **Management Protocol** | IPMI 2.0 / Redfish | Standardized management API |
| **Firmware** | U-Boot | Boot loader |

### 1.3 System Requirements

| Item | Specification |
|------|------|
| **CPU** | ASPEED AST2700 (ARM Cortex-A53) |
| **Memory** | Minimum 512MB DDR4 (Recommended 1GB) |
| **Storage** | Minimum 128MB SPI Flash (Recommended 256MB+) |
| **Network** | 10/100/1000 Mbps Ethernet |
| **Operating System** | OpenBMC (Yocto Based) |

---

## 2. Hardware Management Functions

### 2.1 Hardware Inventory Management (Inventory Manager)

**Service Name**: `phosphor-inventory-manager`  
**D-Bus Interface**: `xyz.openbmc_project.Inventory.Manager`

| Function | Description | Data Source |
|------|------|----------|
| **FRU Reading** | Read Field Replaceable Unit information | SPI EEPROM / I2C |
| **Asset Tag** | System asset identifier management | FRU Memory |
| **Product Information** | Product model, serial number, manufacturer | FRU / SMBIOS |
| **Component Detection** | Automatic hardware component detection | Device Tree / I2C |
| **Attribute Management** | Component attributes (Part Number, Revision) | D-Bus Properties |

**Supported FRU Types**:
- Baseboard FRU (Motherboard)
- Chassis FRU (Enclosure)
- Product FRU (Product Information)
- Board Mgmt Controller FRU (BMC itself)

### 2.2 Sensor Monitoring (Sensor Management)

**Service Name**: `phosphor-hwmon` / `dbus-sensors`  
**D-Bus Interface**: `xyz.openbmc_project.Sensor.Value`

| Sensor Type | Measurement | Unit | Communication Interface |
|-----------|---------|------|---------|
| **Temperature Sensor** | CPU, VRM, Ambient Temperature | °C | I2C / IPMB |
| **Voltage Sensor** | 12V, 5V, 3.3V, 1.05V | mV | I2C / ADC |
| **Current Sensor** | Power Input Current | Ampere | I2C |
| **Fan Speed Sensor** | Fan Speed | RPM | PWM / Tach |
| **Power Sensor** | System Power Consumption | Watts | I2C |
| **Physical Presence** | Component Presence Detection | Boolean | GPIO |

**Sensor Attributes**:
```yaml
Sensor:
  - Reading: Current reading value
  - Status: Status (OK, Warning, Critical)
  - Thresholds:
      - WarningUpper: Warning upper threshold
      - CriticalUpper: Critical upper threshold
      - WarningLower: Warning lower threshold
      - CriticalLower: Critical lower threshold
  - Discrete: Discrete state bits
```

### 2.3 GPIO Management

**Service Name**: GPIO is primarily managed by kernel gpiolib / libgpiod  
**D-Bus Interface**: Some platforms may have custom D-Bus services (not a standardized D-Bus interface)

| Function | Description |
|------|------|
| **GPIO Configuration** | Input/Output mode settings |
| **GPIO Reading** | Read GPIO status |
| **GPIO Writing** | Set GPIO output |
| **Edge Detection** | Rising/Falling edge interrupt |
| **GPIO Matrix** | AST2700 GPIO matrix configuration |

### 2.4 LED Control

**Service Name**: `obmc-leds`  
**D-Bus Interface**: `xyz.openbmc_project.LED.Physical`

| LED Function | Description |
|---------|------|
| **Status Indicator** | System status (Normal/Warning/Error) |
| **Location Indicator** | Physical location identification |
| **Fault Indicator** | Specific component fault indication |
| **Activity Indicator** | Network/Storage activity |

**LED Color Support**:
- Single Color
- Dual Color (RGB)
- Tri-color

### 2.5 Button Management (Button Control)

**Service Name**: `obmc-phosphor-buttons`  
**D-Bus Interface**: `xyz.openbmc_project.Button`

| Button | Function |
|------|------|
| **ID Button** | Trigger location indicator light |
| **Reset Button** | BMC Reset |
| **Power Button** | Host power control |
| **User Button** | Customizable function |

---

## 3. Power Management Functions

### 3.1 Host Power Control (Power Control)

**Service Name**: `obmc-phosphor-power`  
**D-Bus Interface**: `xyz.openbmc_project.Control.Power`

| Power State | Description | Trigger Condition |
|---------|------|---------|
| **On** | Host Power On | Power button / D-Bus API |
| **Off** | Host Power Off | Power button / D-Bus API |
| **PowerCycle** | Power Cycle | Remote command |
| **ForceOff** | Force Off | Emergency situation |
| **PushPowerButton** | Simulate Button Press | Software trigger |

**Power Control Flow**:
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

### 3.2 Power Sequencer Control (Power Sequencer)

**Service Name**: `phosphor-power-systemd-links-sequencer`

| Function | Description |
|------|------|
| **Power Rail Sequencing** | Control power rail turn-on sequence |
| **Delay Control** | Delay time between power rails |
| **Voltage Regulator** | Software-controlled voltage regulators |
| **Power Fault** | Power fault detection and recovery |

### 3.3 PSU Management (Power Supply Unit)

**Service Name**: `phosphor-psu-software-manager`

| Function | Description |
|------|------|
| **PSU Detection** | Power supply unit presence detection |
| **PSU Status** | Normal/Fault status monitoring |
| **PSU Information** | Model, serial number, power rating |
| **Redundancy Management** | PSU redundancy mode configuration |

### 3.4 Host Failure Reboot (Host Failure Reboot)

**Service Name**: `obmc-host-failure-reboots`

| Reboot Mode | Description |
|---------|------|
| **Watchdog Reset** | Watchdog timeout reset |
| **Host Error Reset** | Host error reset |
| **Power Cycle** | Power cycle |
| **Cold Reset** | Cold reset |

---

## 4. Temperature and Fan Control

### 4.1 Fan Control Architecture (Fan Control)

**Service Name**: `phosphor-fan-control`  
**D-Bus Interface**: `xyz.openbmc_project.Control.Fan.Tach`

**Control Modes**:
```
┌─────────────────────────────────────────────────────────┐
│                    Fan Control Modes                    │
├─────────────────────────────────────────────────────────┤
│  1. Manual Mode                                         │
│     - Manually set fan speed (0-100%)                   │
│  2. Automatic Mode                                      │
│     - Automatically adjust fan speed based on temperature│
│  3. PID Control                                         │
│     - Proportional-Integral-Derivative control algorithm │
│  4. Zone Control                                        │
│     - Zonal temperature control                         │
└─────────────────────────────────────────────────────────┘
```

### 4.2 Fan Configuration Management

| Configuration Item | Description | File Location |
|---------|------|---------|
| **Fan Configuration** | Number of fans, location, polarity | `phosphor-fan-control-fan-config` |
| **Zone Conditions** | Temperature zone and fan association | `phosphor-zone-conditions-config` |
| **Zone Configuration** | Control zone definition | `phosphor-zone-config` |
| **Monitor Configuration** | Fan monitoring parameters | `phosphor-fan-monitor-config` |
| **Presence Configuration** | Fan presence detection | `phosphor-fan-presence-config` |
| **Event Configuration** | Fan event triggers | `phosphor-fan-control-events-config` |

### 4.3 Temperature Zone Management (Zone Management)

| Zone Type | Description |
|---------|------|
| **Hotspot Zone** | High-temperature zone (CPU, GPU) |
| **Ambient Zone** | Ambient temperature zone |
| **Intake Zone** | Air intake temperature |
| **Exhaust Zone** | Air exhaust temperature |

**PID Control Parameters**:
```yaml
PIDControl:
  - Proportional: P gain value
  - Integral: I gain value
  - Derivative: D gain value
  - Setpoint: Target temperature
  - OutputMin: Minimum output (0%)
  - OutputMax: Maximum output (100%)
```

### 4.4 Fan Fault Handling

| Fault Type | Handling Method |
|---------|---------|
| **Fan Stopped** | Trigger alarm, increase other fan speeds |
| **Fan Overspeed** | Reduce speed, log event |
| **Fan Not Present** | Log event, adjust control strategy |
| **Over Temperature** | Fan full speed, host throttle/shutdown |

---

## 5. System Monitoring and Logging

### 5.1 System Event Log (SEL - System Event Log)

**Service Name**: `phosphor-ipmi-sel` / `sel-logger`  
**D-Bus Interface**: `xyz.openbmc_project.Logging`

| SEL Type | Description |
|---------|------|
| **System Event** | System event logging |
| **FRU Event** | FRU-related events |
| **Sensor Event** | Sensor threshold events |
| **Message Event** | General message events |

**Event Severity Levels**:
- `OK` - Normal
- `Warning` - Warning
- `Critical` - Critical
- `Non-Recoverable` - Non-Recoverable

### 5.2 Logging Management (Logging)

**Service Name**: `phosphor-logging`  
**D-Bus Interface**: `xyz.openbmc_project.Logging`

| Log Function | Description |
|---------|------|
| **Log Recording** | System log recording |
| **Log Forwarding** | Remote log server (Syslog) |
| **Log Rotation** | Log file rotation |
| **Log Filtering** | Filter by severity level |


**Log Severity Levels**:
```
DEBUG < INFO < NOTICE < WARNING < ERROR < CRITICAL < ALERT < EMERG
```

### 5.3 Health Monitoring (Health Monitoring)

**Note**: Health status is primarily aggregated by Redfish/bmcweb based on each D-Bus object's Status property (`phosphor-health` is not necessarily a standard OpenBMC service)

| Monitoring Item | Description |
|---------|------|
| **System Health** | Overall system health status |
| **Component Health** | Individual component health status |
| **Predictive Maintenance** | Trend-based prediction |
| **Health Report** | Health status report |

### 5.4 Performance Monitoring (Telemetry)

**Service Name**: `telemetry` / `phosphor-hwmon`

| Monitoring Item | Description |
|---------|------|
| **CPU Usage** | CPU load monitoring |
| **Memory Usage** | Memory utilization |
| **Network Traffic** | Network traffic statistics |
| **Storage Usage** | Storage space utilization |

### 5.5 NVMe Monitoring

**Service Name**: OEM/Custom Service (`phosphor-nvme` is not necessarily a standard OpenBMC service; mark as OEM/custom if it is your own NVMe status service)

| Function | Description |
|------|------|
| **NVMe Status** | NVMe device status monitoring |
| **SMART Data** | SMART health data reading |
| **Temperature Monitoring** | NVMe temperature monitoring |
| **Error Statistics** | NVMe error statistics |

---

## 6. Firmware Update Management

### 6.1 Software Manager (Software Manager)

**Service Name**: `phosphor-software-manager`  
**D-Bus Interface**: `xyz.openbmc_project.Software`

| Function | Description |
|------|------|
| **Image Upload** | Upload firmware image files |
| **Image Validation** | Digital signature validation |
| **Image Installation** | Firmware installation to target |
| **Image Activation** | Firmware version switching |
| **Version Management** | Multi-version management |

**Update Process**:
```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  Upload │───>│ Validate│───>│  Install│───>│ Activate│───>│ Reboot  │
│  Image  │    │  Image  │    │  Image  │    │  Image  │    │ System  │
└─────────┘    └─────────┘    └─────────┘    └─────────┘    └─────────┘
```

### 6.2 Firmware Image Types

| Image Type | Description | Target Location |
|---------|------|---------|
| **BMC Firmware** | BMC Firmware (U-Boot + Kernel + Rootfs) | SPI Flash |
| **Host BIOS** | Host BIOS/UEFI | SPI Flash |
| **Option ROM** | Expansion card ROM | PCI ROM |
| **PLD/FPGA** | Programmable Logic Device | CPLD/FPGA |

### 6.3 Image Signing (Image Signing)

**Service Name**: `phosphor-image-signing`

| Function | Description |
|------|------|
| **Signing Key** | Private key image signing |
| **Verification Key** | Public key image verification |
| **Key Management** | Key storage and management |
| **Secure Boot** | Verified Boot support |

### 6.4 Host Firmware Update (Host Firmware Update)

**Service Name**: `phosphor-hostfw-image`

| Function | Description |
|------|------|
| **IPMB Update** | Update host BIOS via IPMB |
| **SPI Update** | Direct SPI Flash update |
| **Host Coordination** | Coordinated update with host OS |

### 6.5 Update Failure Recovery

| Recovery Mechanism | Description |
|---------|------|
| **Dual Bank** | Dual bank switching |
| **Rollback** | Automatic rollback to previous version |
| **Recovery Mode** | Boot in recovery mode |
| **Noverify Mode** | No-verification mode (emergency repair) |

---

## 7. Network and Communication

### 7.1 Network Management (Network Manager)

**Service Name**: `phosphor-network`  
**D-Bus Interface**: `xyz.openbmc_project.Network`

| Function | Description |
|------|------|
| **IP Configuration** | IPv4/IPv6 configuration |
| **DNS Configuration** | DNS server settings |
| **NTP Configuration** | Time synchronization settings |
| **Network Interfaces** | Network interface management |
| **MAC Address** | MAC address management |

**Network Modes**:
- **Static IP** - Static IP configuration
- **DHCP** - Dynamic IP acquisition
- **IPv6** - IPv6 support (SLAAC / DHCPv6)

### 7.2 IPMI Protocol Support

**Service Name**: `phosphor-ipmi-*`  
**D-Bus Interface**: `xyz.openbmc_project.IPMI`

| IPMI Function | Description | Interface |
|---------|------|------|
| **IPMI LAN** | Network interface (RMCP+) | `phosphor-ipmi-net` |
| **IPMI BT** | Serial interface (Block Transfer) | `phosphor-ipmi-bt` |
| **IPMI KCS** | Keyboard controller | `phosphor-ipmi-kcs` |
| **IPMI SSIF** | Single-wire serial interface | `phosphor-ipmi-ssif` |
| **IPMI IPMB** | Host communication | `phosphor-ipmi-ipmb` |

**IPMI Command Set**:
- **Chassis Control** - Chassis control (Power, Reset)
- **Sensor Reading** - Sensor reading
- **SEL Management** - Event log management
- **FRU Reading** - FRU reading
- **SOL** - Serial Over LAN
- **BMC Watchdog** - Watchdog control

### 7.3 Redfish API

**Service Name**: `bmcweb`  
**Protocol**: RESTful HTTP/HTTPS

| Redfish Resource | Description |
|-------------|------|
| **/redfish/v1** | Redfish root node |
| **/Systems** | System information |
| **/Managers** | BMC management information |
| **/Chassis** | Chassis information |
| **/Thermal** | Temperature and fan |
| **/Power** | Power information |
| **/UpdateService** | Firmware update |
| **/EventService** | Event subscription |
| **/SessionService** | Session management |

### 7.4 SNMP Support

**Service Name**: `phosphor-snmp`  
**Protocol**: SNMP v1/v2c/v3

| SNMP Function | Description |
|---------|------|
| **MIB Support** | IPMI-MIB, HOST-RES-MIB |
| **Trap Sending** | Event trap notification |
| **GET/SET** | Read/Set MIB objects |
| **SNMPv3** | Security support |

### 7.5 Remote Console

| Function | Protocol | Description |
|------|------|------|
| **SSH** | SSH v2 | Secure Shell access |
| **SOL** | IPMI LAN | Serial Over LAN |
| **KVM over IP** | HTTP/WebSocket | Remote console |
| **Virtual Media** | HTTP/WebSocket | Virtual CD-ROM/USB |

### 7.6 MCTP Support

**Service Name**: `libmctp` / `pldm`  
**Protocol**: MCTP (Management Component Transport Protocol)

| MCTP Function | Description |
|---------|------|
| **MCTP over LAN** | Network transport |
| **MCTP over SPI** | SPI transport |
| **MCTP over I2C** | I2C transport |
| **PLDM** | Platform Data Management |

---

## 8. Security and Authentication

### 8.1 User Management (User Management)

**Service Name**: `phosphor-user-manager`  
**D-Bus Interface**: `xyz.openbmc_project.User.Manager`

| User Function | Description |
|---------|------|
| **User Creation** | Create user accounts |
| **User Deletion** | Delete user accounts |
| **User Modification** | Modify user attributes |
| **User Query** | Query user information |
| **Permission Management** | User permission settings |

**User Permission Levels**:
- **Administrator** - Administrator (Full access)
- **Operator** - Operator (Read/Write access)
- **Read Only** - Read-only access
- **Audit** - Audit (Read-only logs)

### 8.2 Authentication Mechanisms

| Authentication Method | Description |
|---------|------|
| **Local Authentication** | Local user database |
| **LDAP** | LDAP server authentication |
| **RADIUS** | RADIUS authentication |
| **802.1X** | Network port authentication |
| **API Key** | API key authentication |

### 8.3 Secure Communication

| Protocol | Encryption | Description |
|------|---------|------|
| **HTTPS** | TLS 1.2/1.3 | Web interface encryption |
| **SSH** | RSA/ECDSA | Shell access encryption |
| **IPMI 2.0** | RMCP+ | IPMI encryption |
| **Redfish** | TLS 1.2/1.3 | Redfish API encryption |

### 8.4 Certificate Management

**Service Name**: `phosphor-certificate-manager` / `bmcweb certificate` related functionality

| Function | Description |
|------|------|
| **CA Certificate** | Certificate Authority certificate |
| **Server Certificate** | HTTPS server certificate |
| **Client Certificate** | Client authentication certificate |
| **Certificate Rotation** | Automatic certificate renewal |

### 8.5 Security Features

| Function | Description |
|------|------|
| **Login Failure Lockout** | Account lockout after multiple failures |
| **Session Timeout** | Automatic logout for idle sessions |
| **Password Strength** | Password complexity requirements |
| **Password Rotation** | Mandatory periodic password change |
| **Access Control** | Role-Based Access Control (RBAC) |
| **Audit Logging** | Security event audit logs |

### 8.6 Secure Boot (Secure Boot)

| Function | Description |
|------|------|
| **Verified Boot** | Boot verification |
| **Key Storage** | Secure key storage |
| **Image Verification** | Firmware image verification |
| **Secure Measurement** | Boot measurement logs |

---

## 9. Management Interfaces

### 9.1 Web Management Interface (Web UI)

**Service Name**: `webui-vue` / `phosphor-webui`  
**Technology**: Vue.js + REST API

| Function Module | Description |
|---------|------|
| **Dashboard** | System overview, health status | 
| **Hardware Monitoring** | Temperature, Fan, Power |
| **Power Control** | Host power on/off |
| **Firmware Update** | Image upload and update |
| **User Management** | User account management |
| **Network Configuration** | Network settings |
| **Event Log** | SEL viewing |
| **Remote Console** | SOL / KVM |
| **Virtual Media** | ISO/USB mounting |

### 9.2 REST API (Redfish)

**Protocol**: HTTP/HTTPS  
**Format**: JSON

**Main API Endpoints** (Common OpenBMC paths; actual paths should be verified per platform):
```
GET    /redfish/v1/                         - Redfish Root Node
GET    /redfish/v1/Systems/system/          - System Information
GET    /redfish/v1/Managers/bmc/            - BMC Information
GET    /redfish/v1/Chassis/chassis/         - Chassis Information
GET    /redfish/v1/Chassis/chassis/Thermal/ - Thermal Information
GET    /redfish/v1/Chassis/chassis/Power/   - Power Information
POST   /redfish/v1/UpdateService/Actions/UpdateService.SimpleUpdate
GET    /redfish/v1/EventService/            - Event Service
POST   /redfish/v1/SessionService/Sessions
```

### 9.3 IPMI Command Interface

**Tool**: `ipmitool`

**Common Commands**:
```bash
# Power Control
ipmitool -I lanplus -H <bmc_ip> power on
ipmitool -I lanplus -H <bmc_ip> power off
ipmitool -I lanplus -H <bmc_ip> power cycle

# Sensor Reading
ipmitool -I lanplus -H <bmc_ip> sensor list
ipmitool -I lanplus -H <bmc_ip> sdr list

# FRU Information
ipmitool -I lanplus -H <bmc_ip> fru print

# SEL Log
ipmitool -I lanplus -H <bmc_ip> sel list
ipmitool -I lanplus -H <bmc_ip> sel clear

# SOL Console
ipmitool -I lanplus -H <bmc_ip> sol activate
```

### 9.4 Serial Over LAN (SOL)

| Function | Description |
|------|------|
| **SOL Activation** | Start SOL session |
| **SOL Deactivation** | End SOL session |
| **SOL Reset** | Reset SOL connection |
| **SOL Configuration** | Baud rate, data bits settings |

### 9.5 Virtual Media (Virtual Media)

| Function | Description |
|------|------|
| **ISO Mounting** | Remote ISO image mounting |
| **USB Redirect** | USB device redirection |
| **Floppy Emulation** | Floppy drive emulation |
| **Media Ejection** | Virtual media eject |

---

## 10. D-Bus Service Architecture

### 10.1 D-Bus Service List

| Service Name | Object Path | Interface | Description |
|---------|---------|------|------|
| **xyz.openbmc_project.Control.Power** | `/xyz/openbmc_project/control/power0` | PowerControl | Power Control |
| **xyz.openbmc_project.Control.Fan.Tach** | `/xyz/openbmc_project/control/fan0` | FanControl | Fan Control |
| **xyz.openbmc_project.Inventory.Manager** | `/xyz/openbmc_project/inventory` | InventoryManager | Inventory Management |
| **xyz.openbmc_project.Sensor.Value** | `/xyz/openbmc_project/sensors/...` | SensorValue | Sensor Value |
| **xyz.openbmc_project.Logging** | `/xyz/openbmc_project/logging` | Logging | Logging Management |
| **xyz.openbmc_project.Software** | `/xyz/openbmc_project/software/...` | Software | Software Management |
| **xyz.openbmc_project.Network** | `/xyz/openbmc_project/network/...` | Network | Network Management |
| **xyz.openbmc_project.User.Manager** | `/xyz/openbmc_project/user_manager` | UserManager | User Management |
| **xyz.openbmc_project.Time** | `/xyz/openbmc_project/time/RTC0` | Time | Time Management |
| **xyz.openbmc_project.Storage** | `/xyz/openbmc_project/storage/...` | Storage | Storage Management |

### 10.2 D-Bus Communication Pattern

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

### 10.3 Entity Manager (Entity Manager)

**Service Name**: `phosphor-entity-manager`

| Function | Description |
|------|------|
| **Entity Graph** | Hardware entity hierarchical structure |
| **Entity Attributes** | Entity attribute management |
| **Entity Relationships** | Entity relationship definitions |
| **D-Bus Objects** | Auto-generated D-Bus objects |

---

## 11. API Interface Specifications

### 11.1 Redfish API Specification

#### 11.1.1 System Information

**Endpoint**: `GET /redfish/v1/Systems/1/`

**Response Example**:
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

#### 11.1.2 Thermal Information

**Endpoint**: `GET /redfish/v1/Chassis/1/Thermal/`

**Response Example**:
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

#### 11.1.3 Power Information

**Endpoint**: `GET /redfish/v1/Chassis/1/Power/`

**Response Example**:
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

#### 11.1.4 Firmware Update

**Endpoint**: `POST /redfish/v1/UpdateService/Actions/UpdateService.SimpleUpdate`

**Request Example**:
```json
{
  "Image": "https://example.com/firmware.bin",
  "InstallInOrder": ["/redfish/v1/UpdateService/FirmwareInventory/BMC.Firmware"]
}
```

### 11.2 IPMI Command Specification

#### 11.2.1 Power Control

| Command | NetFn | CMD | Description |
|------|-------|-----|------|
| **Get Chassis Status** | 0x00 | 0x02 | Read chassis status |
| **Chassis Control** | 0x00 | 0x06 | Power control |

**Chassis Control Parameters** (IPMI 2.0 Standard):
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

#### 11.2.2 Sensor Reading

| Command | NetFn | CMD | Description |
|------|-------|-----|------|
| **Get Sensor Reading** | 0x04 | 0x2D | Read sensor value |
| **Get SDR Repository Info** | 0x04 | 0x10 | SDR repository information |
| **Get SDR** | 0x04 | 0x11 | Read SDR record |

### 11.3 D-Bus API Specification

#### 11.3.1 Power Control

**Interface**: `xyz.openbmc_project.Control.Power`

**Methods**:
```
SetState(uint8 newState)
  - 0 = Off
  - 1 = On
  - 2 = PowerCycle
  - 3 = ForceOff
  - 4 = PushPowerButton
```

**Properties**:
```
State (uint8) - Current power state
```


#### 11.3.2 Sensor Reading


**Interface**: `xyz.openbmc_project.Sensor.Value`


**Properties**:
```


Value (double) - Sensor reading
Status (uint8) - Sensor status
```

---

## 12. System Configuration Management

### 12.1 Configuration File Locations

| Configuration Type | Location | Description |
|---------|------|------|
| **Machine Config** | `conf/machine/<machine>.conf` | Platform-specific configuration |
| **Layer Config** | `conf/<layer>.conf` | Layer configuration |
| **Local Config** | `build/conf/local.conf` | Local configuration |
| **BBLayers** | `build/conf/bblayers.conf` | Layer list |

### 12.2 Hardware Configuration

| Configuration Item | Configuration Method | Description |
|---------|---------|------|
| **Device Tree** | `.dts` file | Hardware description |
| **I2C Configuration** | Device Tree / Configuration file | I2C device configuration |
| **GPIO Configuration** | Device Tree / Configuration file | GPIO configuration |
| **Network Configuration** | `phosphor-network` | Network parameters |

### 12.3 Service Configuration

| Service | Configuration File | Description |
|------|---------|------|
| **Fan Control** | `fan-control.conf` | Fan control parameters |
| **Sensor** | `sensors.conf` | Sensor configuration |
| **Network** | `network.conf` | Network configuration |
| **User** | `users.conf` | User configuration |

### 12.4 Boot Process

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

## 13. Version Information and Update History

| Version | Date | Description |
|------|------|------|
| 1.0 | 2024 | Initial version |

---

## 14. Reference Documents

| Document | Link |
|------|------|
| **OpenBMC Docs** | https://github.com/openbmc/docs |
| **Redfish Spec** | https://www.dmtf.org/standards/redfish |
| **IPMI Spec** | https://www.intel.com/content/www/us/en/develop/articles/intel-intelligent-platform-management-interface.html |
| **Yocto Project** | https://www.yoctoproject.org |
| **ASPEED AST2700** | ASPEED Official Documentation |

---

## 15. Appendix

### 15.1 Abbreviation Glossary

| Abbreviation | Full Name | Description |
|------|---------|------|
| **BMC** | Baseboard Management Controller | Baseboard management controller |
| **IPMI** | Intelligent Platform Management Interface | Intelligent platform management interface |
| **FRU** | Field Replaceable Unit | Field-replaceable unit |
| **SEL** | System Event Log | System event log |
| **SOL** | Serial Over LAN | Remote serial console |
| **KVM** | Keyboard Video Mouse | Keyboard, video, and mouse |
| **PLDM** | Platform Data Management | Platform data management |
| **MCTP** | Management Component Transport Protocol | Management component transport protocol |
| **SDR** | Sensor Data Record | Sensor data record |
| **PSU** | Power Supply Unit | Power supply unit |
| **GPIO** | General Purpose Input/Output | General-purpose input/output |
| **I2C** | Inter-Integrated Circuit | Inter-integrated circuit communication |
| **SPI** | Serial Peripheral Interface | Serial peripheral interface |
| **PWM** | Pulse Width Modulation | Pulse width modulation |

### 15.2 Contact Information

| Item | Information |
|------|------|
| **Project** | GigaByte AST2700 OpenBMC |
| **Maintainer** | GigaByte BMC Team |
| **Support** | Internal Technical Support |

---

*End of Document*