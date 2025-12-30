# IoTSmartSwitch 🔘

> 📱 一个支持手机远程控制的通用开关方案
（只是一个期末作业而已）

## 📖 项目简介

**IoTSmartSwitch** 是一个物联网控制系统，旨在打通手机与传统物理设备之间的隔阂。通过 **舵机 (Servo)** 的物理按压或 **网络请求 (Wake-on-LAN/HTTP)**，实现对台式机及传统家电（如电灯、风扇）的智能控制。

### ✨ 主要功能
*   **远程物理开关**：通过控制 SG90 舵机旋转，模拟手指按压传统开关。
*   **PC 远程唤醒 (WOL)**：支持局域网内唤醒台式机。
*   **PC 远程关机**：配合 PC 端驻留程序，实现优雅关机。
*   **跨平台 App**：基于 Flutter 开发的移动端控制 App。

---

## 🛠️ 硬件清单 (Bill of Materials)

本项目基于 ESP32 与 PWM 驱动板构建，成本低廉，易于复现。

| 硬件名称 | 描述/备注 |
| :--- | :--- |
| **ESP32 开发板** | 主控核心，负责 WiFi 通信与逻辑控制 |
| **PCA9685 驱动板** | 16路 PWM 舵机驱动板 (I2C 接口) |
| **SG90 舵机** | 用于物理按压开关 |
| **杜邦线** | 若干 (母对母/公对母) |
| **电源** | 5V 电源供电 |

---

## 🏗️ 技术栈与环境

*   **后端 (Backend)**: Java / Spring Boot
*   **移动端 (Mobile)**: Dart / Flutter (Android Studio)
*   **嵌入式 (Embedded)**: C++ / PlatformIO (VSCode)
*   **PC 客户端**: C++ / Visual Studio (Win32 API)

---

## 📂 项目结构说明

```text
IoTSmartSwitch/
├── backend/             # Spring Boot 后端源码 (IDEA打开)
├── mobile/              # Flutter 手机 App 源码 (Android Studio打开)
├── esp32/               # ESP32 固件源码 (VSCode + PlatformIO打开)
└── esp32PcController/   # Windows 关机控制程序 (Visual Studio打开)
```

Ps：
```text
mobile 需要修改 mobile/lib/config/frontConfig.dart 内的IP为服务器IP（必须）
esp32 与 esp32PcController 根据代码注释修改配置文件（必须）
springboot根据有需要修改application.properties（可选）

esp32要和esp32PcController在同一局域网内
```