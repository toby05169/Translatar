# Translatar - AI实时翻译耳机应用

> 戴上AirPods，世界语言畅通无阻

Translatar 是一款基于 OpenAI Realtime API 的 iOS 实时语音翻译应用。配合 AirPods 使用，让您获得"戴上耳机就能听懂外语"的沉浸式体验。

---

## 功能特性

- **实时语音翻译**：通过AirPods麦克风捕获语音，AI实时翻译并在耳机中播放
- **10种语言支持**：中文、英语、日语、韩语、西班牙语、法语、德语、意大利语、葡萄牙语、俄语
- **双语字幕显示**：同时显示原文和翻译文本
- **对话模式**：自动检测说话起止，适合面对面交流
- **沉浸模式**：持续监听环境音，适合机场广播等场景
- **翻译历史记录**：自动保存翻译记录，方便回顾

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
│   │   └── TranslationState.swift  # 翻译状态模型
│   │
│   ├── Services/              # 服务层（核心功能）
│   │   ├── AudioCaptureService.swift      # 音频捕获（AirPods麦克风）
│   │   ├── AudioPlaybackService.swift     # 音频播放（翻译结果）
│   │   └── RealtimeTranslationService.swift # OpenAI Realtime API连接
│   │
│   ├── ViewModels/            # 视图模型层
│   │   └── TranslationViewModel.swift     # 核心业务逻辑
│   │
│   ├── Views/                 # UI视图层
│   │   ├── ContentView.swift  # 主界面
│   │   └── SettingsView.swift # 设置页面
│   │
│   └── Resources/             # 资源文件
│       └── Assets.xcassets/   # 图标和颜色资源
│
├── project.yml                # XcodeGen项目配置
├── setup_xcode_project.sh     # 自动配置脚本
└── README.md                  # 本文件
```

---

## 快速开始

### 前置条件

| 条件 | 说明 |
|:---|:---|
| **Mac电脑** | 需要macOS 14.0+，已安装Xcode 15+ |
| **iPhone** | iOS 17.0+，用于测试 |
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
3. 点击中央的"开始翻译"按钮
4. 享受沉浸式翻译体验！

---

## 后端服务部署（可选）

后端API代理服务用于保护您的OpenAI API密钥。在MVP阶段，您可以直接在应用中输入API密钥使用。如需部署后端服务：

```bash
# 进入后端目录
cd Backend

# 安装依赖
npm install

# 配置环境变量
cp .env.example .env
# 编辑.env文件，填入您的OpenAI API密钥

# 启动服务
npm start
```

### 部署到云平台

推荐使用以下平台部署（均有免费额度）：

| 平台 | 特点 | 部署命令 |
|:---|:---|:---|
| **Vercel** | 最简单，自动部署 | `vercel deploy` |
| **Railway** | 一键部署，免费额度 | 连接GitHub仓库即可 |
| **Render** | 免费Web服务 | 连接GitHub仓库即可 |

---

## 技术架构

```
┌─────────────────────────────────────────────┐
│                 iOS 应用层                    │
│  ┌─────────┐  ┌──────────┐  ┌────────────┐  │
│  │ SwiftUI │  │ ViewModel│  │  Settings   │  │
│  │  Views  │←→│  Layer   │←→│  Storage    │  │
│  └─────────┘  └────┬─────┘  └────────────┘  │
│                    │                          │
│  ┌─────────────────┴──────────────────────┐  │
│  │           Service Layer                 │  │
│  │  ┌──────────┐ ┌──────────┐ ┌────────┐  │  │
│  │  │ Audio    │ │ Realtime │ │ Audio  │  │  │
│  │  │ Capture  │→│ Translation│→│ Playback│  │  │
│  │  │ Service  │ │ Service  │ │ Service│  │  │
│  │  └──────────┘ └────┬─────┘ └────────┘  │  │
│  └─────────────────────┼──────────────────┘  │
└────────────────────────┼─────────────────────┘
                         │ WebSocket (wss://)
                         ▼
              ┌──────────────────────┐
              │  OpenAI Realtime API │
              │  (gpt-4o-realtime)   │
              └──────────────────────┘
```

---

## API费用参考

OpenAI Realtime API 按使用量计费：

| 项目 | 费用 |
|:---|:---|
| 音频输入 | $0.06 / 分钟 |
| 音频输出 | $0.24 / 分钟 |
| 文本输出 | $0.08 / 1K tokens |

**估算**：日常使用约 $0.30/分钟，一次10分钟的对话约 $3。

---

## 后续开发计划

- [ ] **第二阶段**：AI降噪、沉浸式环境翻译模式、离线翻译
- [ ] **第三阶段**：精美UI设计、订阅支付、App Store上架

---

## 许可证

本项目为私有项目，版权所有。

---

*由 Manus AI 为 toby 先生开发*
