# Translatar - AI实时翻译耳机应用

> 戴上AirPods，世界语言畅通无阻

Translatar 是一款基于 OpenAI Realtime API 的 iOS 实时语音翻译应用。配合 AirPods 使用，让您获得"戴上耳机就能听懂外语"的沉浸式体验。

---

## 功能特性

### 核心翻译能力
- **实时语音翻译**：通过AirPods麦克风捕获语音，AI实时翻译并在耳机中播放
- **10种语言支持**：中文、英语、日语、韩语、西班牙语、法语、德语、意大利语、葡萄牙语、俄语
- **双语字幕显示**：同时显示原文和翻译文本
- **翻译历史记录**：自动保存翻译记录，方便回顾

### 两种翻译模式
- **对话模式**：自动检测说话起止，适合面对面交流，低延迟快速响应
- **沉浸模式**：持续监听环境音，适合机场广播、车站播报等场景，自动翻译周围所有语音

### 第二阶段新增功能
- **AI降噪**：集成Apple Voice Processing技术（回声消除 + 噪声抑制 + 自动增益控制），在嘈杂环境中也能精准识别语音
- **离线翻译**：基于Apple Speech + Translation框架，无网络时自动切换设备端翻译，完全免费且保护隐私
- **自动网络切换**：实时监测网络状态，网络断开时自动降级为离线模式，恢复后自动切回在线模式
- **后台持续翻译**：沉浸模式支持后台运行，锁屏后仍可持续翻译环境音

---

## 项目结构

```
Translatar/
├── Backend/                    # 后端API代理服务
│   ├── server.js              # Express服务器（保护API密钥）
│   ├── package.json           # Node.js依赖配置
│   └── .env.example           # 环境变量模板
│
├── Translatar/                 # iOS应用源码
│   ├── TranslatarApp.swift    # 应用入口
│   ├── Info.plist             # 应用配置（权限声明等）
│   ├── Translatar.entitlements # 应用权限
│   │
│   ├── Models/                # 数据模型
│   │   ├── Language.swift     # 语言定义（10种语言）
│   │   └── TranslationState.swift  # 翻译状态与模式模型
│   │
│   ├── Services/              # 服务层（核心功能）
│   │   ├── AudioCaptureService.swift      # 音频捕获 + AI降噪
│   │   ├── AudioPlaybackService.swift     # 音频播放（翻译结果）
│   │   ├── RealtimeTranslationService.swift # OpenAI Realtime API（在线翻译）
│   │   └── OfflineTranslationService.swift  # Apple原生离线翻译（第二阶段新增）
│   │
│   ├── ViewModels/            # 视图模型层
│   │   └── TranslationViewModel.swift     # 核心业务逻辑 + 模式切换 + 网络监测
│   │
│   ├── Views/                 # UI视图层
│   │   ├── ContentView.swift  # 主界面（含模式切换、状态栏）
│   │   └── SettingsView.swift # 设置页面（含降噪、离线设置）
│   │
│   └── Resources/             # 资源文件
│       └── Assets.xcassets/   # 图标和颜色资源
│
├── project.yml                # XcodeGen项目配置
├── setup_xcode_project.sh     # 自动配置脚本
├── DEPLOYMENT_GUIDE.md        # 零基础部署指南
└── README.md                  # 本文件
```

---

## 技术架构

```
┌──────────────────────────────────────────────────────────┐
│                      iOS 应用层                           │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │ SwiftUI  │  │  ViewModel   │  │    Settings        │  │
│  │  Views   │←→│  (模式切换/   │←→│    Storage         │  │
│  │          │  │   网络监测)   │  │                    │  │
│  └──────────┘  └──────┬───────┘  └────────────────────┘  │
│                       │                                   │
│  ┌────────────────────┴───────────────────────────────┐  │
│  │              Service Layer                          │  │
│  │                                                     │  │
│  │  ┌──────────────┐    ┌──────────────────────────┐  │  │
│  │  │ Audio Capture │    │   在线翻译路径            │  │  │
│  │  │ + AI降噪      │───→│  RealtimeTranslation     │  │  │
│  │  │ (Voice Proc.) │    │  (OpenAI Realtime API)   │  │  │
│  │  └──────┬───────┘    └──────────┬───────────────┘  │  │
│  │         │                       │                   │  │
│  │         │  ┌────────────────────┴────────────────┐  │  │
│  │         │  │   离线翻译路径（网络断开自动切换）    │  │  │
│  │         └─→│  OfflineTranslation                 │  │  │
│  │            │  (Apple Speech + Translation)        │  │  │
│  │            └────────────────────┬────────────────┘  │  │
│  │                                 │                   │  │
│  │                    ┌────────────┴──────────┐        │  │
│  │                    │   Audio Playback      │        │  │
│  │                    │   (AirPods输出)       │        │  │
│  │                    └───────────────────────┘        │  │
│  └─────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

---

## 快速开始

### 前置条件

| 条件 | 说明 |
|:---|:---|
| **Mac电脑** | 需要macOS 14.0+，已安装Xcode 15+ |
| **iPhone** | iOS 17.0+（离线翻译需iOS 18+） |
| **AirPods** | AirPods Pro / AirPods 3代及以上（推荐） |
| **OpenAI API密钥** | 从 [platform.openai.com](https://platform.openai.com/api-keys) 获取 |
| **Apple开发者账号** | 免费账号即可用于真机调试（上架需付费账号） |

### 第一步：配置Xcode项目

```bash
# 1. 安装XcodeGen（如果还没有安装）
brew install xcodegen

# 2. 进入项目目录
cd Translatar

# 3. 生成Xcode项目
xcodegen generate

# 4. 打开项目
open Translatar.xcodeproj
```

### 第二步：在Xcode中配置

1. 打开 `Translatar.xcodeproj`
2. 在左侧导航栏选择项目 → **Signing & Capabilities**
3. 选择您的 **Team**（开发团队）
4. 确保 **Bundle Identifier** 是唯一的（如 `com.yourname.translatar`）
5. 确保以下 Capabilities 已启用：
   - **Background Modes** → Audio, AirPlay, and Picture in Picture
   - **Background Modes** → Background processing
   - **App Sandbox** → Microphone

### 第三步：连接设备并运行

1. 用数据线将iPhone连接到Mac
2. 在Xcode顶部选择您的iPhone设备
3. 点击 ▶️ 运行按钮
4. 首次运行时，iPhone上需要信任开发者证书：
   - 设置 → 通用 → VPN与设备管理 → 信任您的开发者账号

### 第四步：配置API密钥

1. 打开Translatar应用
2. 点击右上角 ⚙️ 设置图标
3. 输入您的OpenAI API密钥
4. 点击"完成"

### 第五步：开始使用

1. 连接AirPods
2. 选择"对方说"的语言和"翻译成"的语言
3. 选择翻译模式（对话模式 或 沉浸模式）
4. 点击中央的"开始翻译"按钮
5. 享受沉浸式翻译体验！

### 离线翻译准备（可选）

如需使用离线翻译功能，请预先下载语言包：
1. **语音识别包**：设置 → 通用 → 键盘 → 听写语言 → 下载所需语言
2. **翻译引擎包**（iOS 18+）：设置 → 通用 → 翻译 → 下载语言

---

## 后端服务部署（可选）

后端API代理服务用于保护您的OpenAI API密钥。在MVP阶段，您可以直接在应用中输入API密钥使用。如需部署后端服务：

```bash
cd Backend
npm install
cp .env.example .env
# 编辑.env文件，填入您的OpenAI API密钥
npm start
```

---

## API费用参考

| 引擎 | 费用 | 说明 |
|:---|:---|:---|
| OpenAI Realtime API（在线） | ~$0.30/分钟 | 高质量AI翻译 |
| Apple原生框架（离线） | 免费 | 设备端处理，质量略低 |

---

## 版本历史

| 版本 | 内容 |
|:---|:---|
| v2.0.0 | 第二阶段：AI降噪、沉浸模式、离线翻译、自动网络切换 |
| v1.0.0 | MVP：基础实时翻译、对话模式、双语字幕 |

## 后续开发计划

- [x] **第一阶段**：MVP核心翻译功能
- [x] **第二阶段**：AI降噪、沉浸式环境翻译模式、离线翻译
- [ ] **第三阶段**：精美UI设计、订阅支付、App Store上架

---

## 许可证

本项目为私有项目，版权所有。

---

*由 Manus AI 为 toby 先生开发*
