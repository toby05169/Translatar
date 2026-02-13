# Translatar — AI实时翻译耳机应用

> 戴上AirPods，听懂世界。

Translatar 是一款基于 AI 大模型的实时语音翻译 iOS 应用。配合 AirPods 使用，让你在任何场景下都能自然地"听懂"外语——就像你突然掌握了一门新语言。

---

## 核心功能

### 实时语音翻译
基于 OpenAI Realtime API，语音到语音直接翻译，延迟低至数百毫秒。不是机械的逐字翻译，而是理解语境后的自然表达。

### 两种翻译模式

| 模式 | 适用场景 | 工作方式 |
|:---|:---|:---|
| **对话模式** | 面对面交流 | AI自动识别对话轮次，你说一句、对方说一句 |
| **沉浸模式** | 机场、车站、会议 | 持续监听环境音，自动翻译所有语音和广播 |

### AI智能降噪
Apple Voice Processing 原生降噪技术，在嘈杂环境中精准捕捉人声，过滤环境噪音。

### 离线翻译
基于 Apple Speech + Translation 框架，无网络时自动切换到设备端翻译。网络恢复后无缝回到在线模式。

### 订阅付费系统
StoreKit 2 集成，支持月度/年度订阅，7天免费试用。免费版每天5分钟翻译额度。

### 10种语言支持
中文、英语、日语、韩语、西班牙语、法语、德语、意大利语、葡萄牙语、俄语。

---

## 项目结构

```
Translatar/
├── Translatar/                     # iOS应用源码
│   ├── TranslatarApp.swift         # 应用入口（引导页+Tab导航）
│   ├── Models/
│   │   ├── Language.swift          # 语言模型定义
│   │   └── TranslationState.swift  # 翻译状态模型
│   ├── Services/
│   │   ├── AudioCaptureService.swift       # 音频捕获（降噪+沉浸模式）
│   │   ├── AudioPlaybackService.swift      # 音频播放
│   │   ├── RealtimeTranslationService.swift # OpenAI Realtime API
│   │   ├── OfflineTranslationService.swift  # 离线翻译
│   │   └── SubscriptionService.swift        # StoreKit 2 订阅管理
│   ├── ViewModels/
│   │   └── TranslationViewModel.swift      # 核心ViewModel
│   ├── Views/
│   │   ├── ContentView.swift       # 主界面（精美UI）
│   │   ├── OnboardingView.swift    # 引导页
│   │   ├── PaywallView.swift       # 付费墙
│   │   ├── HistoryView.swift       # 翻译历史
│   │   └── SettingsView.swift      # 设置页面
│   ├── Resources/
│   │   ├── Assets.xcassets/        # 图标和图片资源
│   │   └── Translatar.storekit     # StoreKit测试配置
│   ├── Info.plist                  # 应用配置
│   └── Translatar.entitlements     # 权限配置
├── Backend/                        # 后端API代理
│   ├── server.js                   # Node.js Express服务器
│   ├── package.json
│   └── .env.example                # 环境变量模板
├── AppStore/                       # App Store上架材料
│   ├── privacy_policy.md           # 隐私政策（中英双语）
│   ├── terms_of_service.md         # 使用条款（中英双语）
│   └── app_store_listing.md        # 应用描述和关键词
├── project.yml                     # XcodeGen项目配置
├── DEPLOYMENT_GUIDE.md             # 部署指南
└── README.md                       # 本文件
```

---

## 快速开始

### 前置要求

| 要求 | 说明 |
|:---|:---|
| Mac电脑 | 运行macOS 14.0+ |
| Xcode 16+ | App Store免费下载 |
| iPhone | iOS 17.0+，推荐iOS 18+（离线翻译需要） |
| AirPods | AirPods Pro / AirPods 3代及以上 |
| OpenAI API密钥 | 在线翻译需要，离线模式不需要 |

### 安装步骤

**1. 安装 XcodeGen**

```bash
brew install xcodegen
```

**2. 克隆项目并生成Xcode项目**

```bash
git clone https://github.com/aihuafloor-ux/Translatar.git
cd Translatar
xcodegen generate
open Translatar.xcodeproj
```

**3. 配置签名**

在 Xcode 中选择 Translatar target → Signing & Capabilities → 选择您的开发团队。

**4. 运行**

连接iPhone，选择设备，点击运行按钮（或 Cmd+R）。

**5. 配置API密钥**

在应用设置页面输入您的 OpenAI API 密钥。

### 后端服务（可选）

```bash
cd Backend
cp .env.example .env
# 编辑 .env 填入您的 OpenAI API 密钥
npm install
npm start
```

---

## 技术栈

| 层级 | 技术 |
|:---|:---|
| 语言 | Swift 5.9 |
| UI框架 | SwiftUI |
| 在线翻译 | OpenAI Realtime API (WebSocket) |
| 离线语音识别 | Apple SFSpeechRecognizer |
| 离线翻译 | Apple Translation Framework (iOS 18+) |
| 降噪 | Apple Voice Processing IO |
| 订阅 | StoreKit 2 |
| WebSocket | Starscream |
| 后端 | Node.js + Express |

---

## API费用参考

| 引擎 | 费用 | 说明 |
|:---|:---|:---|
| OpenAI Realtime API（在线） | ~$0.30/分钟 | 高质量AI翻译 |
| Apple原生框架（离线） | 免费 | 设备端处理，质量略低 |

---

## 版本历史

| 版本 | 日期 | 内容 |
|:---|:---|:---|
| v3.0.0 | 2026-02-13 | 精美UI升级、引导页、订阅付费系统、App Store上架材料 |
| v2.0.0 | 2026-02-13 | AI降噪、沉浸模式、离线翻译、自动网络切换 |
| v1.0.0 | 2026-02-13 | MVP原型，基础实时翻译、对话模式、双语字幕 |

---

## 开发里程碑

- [x] **第一阶段**：MVP核心翻译功能
- [x] **第二阶段**：AI降噪、沉浸式环境翻译模式、离线翻译
- [x] **第三阶段**：精美UI设计、订阅支付、App Store上架材料

---

## 许可证

本项目为私有项目，版权所有。未经授权不得复制、分发或修改。

---

*由 Manus AI 为 toby 先生开发*
