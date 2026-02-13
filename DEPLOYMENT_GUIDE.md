# Translatar 部署指南（零代码基础版）

**面向：** toby 先生
**编写：** Manus AI
**日期：** 2026年2月13日

---

## 概述

本指南将一步一步带您完成 Translatar 应用的部署，从"代码在GitHub上"到"应用跑在您的iPhone上"。整个过程不需要您编写任何代码，只需按照步骤操作即可。

**预计耗时：** 30-45分钟（首次配置）

---

## 第一部分：准备工作清单

在开始之前，请确认您已准备好以下物品：

| 序号 | 准备项 | 状态 | 说明 |
|:---:|:---|:---:|:---|
| 1 | Mac电脑（macOS 14+） | ☐ | 必须是Mac，Windows不能开发iOS应用 |
| 2 | Xcode 15+（免费） | ☐ | 从Mac App Store下载，约12GB |
| 3 | iPhone（iOS 17+） | ☐ | 用于测试的真机 |
| 4 | AirPods | ☐ | 推荐AirPods Pro，普通AirPods也可以 |
| 5 | Lightning/USB-C数据线 | ☐ | 连接iPhone到Mac |
| 6 | Apple ID | ☐ | 您日常使用的Apple ID即可 |
| 7 | OpenAI API密钥 | ☐ | 下面会教您如何获取 |

---

## 第二部分：获取 OpenAI API 密钥

这是翻译功能的"燃料"，没有它应用无法工作。

### 步骤：

1. **打开浏览器**，访问 [platform.openai.com](https://platform.openai.com)
2. **注册/登录** OpenAI 账号
3. 点击左侧菜单的 **"API Keys"**
4. 点击 **"Create new secret key"**
5. 给密钥起个名字（比如"Translatar"），点击创建
6. **立即复制并保存密钥**（以 `sk-` 开头的一长串字符）
   - 这个密钥只会显示一次，请务必保存好！
   - 建议保存到备忘录或密码管理器中
7. 在 **"Billing"** 页面绑定支付方式并充值（建议先充 $10 试用）

> **费用说明：** 实时翻译约 $0.30/分钟。充值 $10 大约可以翻译 30 分钟，足够您充分体验和测试。

---

## 第三部分：安装开发工具

### 3.1 安装 Xcode

1. 打开 Mac 上的 **App Store**
2. 搜索 **"Xcode"**
3. 点击 **"获取"** 下载安装（约12GB，需要一些时间）
4. 安装完成后，打开一次 Xcode，同意许可协议
5. Xcode 会自动安装必要的组件

### 3.2 安装 Homebrew 和 XcodeGen

打开 Mac 的 **"终端"** 应用（在"应用程序 → 实用工具"中），依次输入以下命令：

```bash
# 安装Homebrew（Mac的软件包管理器）
# 如果已经安装过，跳过这一步
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装XcodeGen（自动生成Xcode项目的工具）
brew install xcodegen
```

---

## 第四部分：下载项目代码

在终端中输入：

```bash
# 进入桌面目录（方便找到）
cd ~/Desktop

# 从GitHub下载项目代码
git clone https://github.com/aihuafloor-ux/Translatar.git

# 进入项目目录
cd Translatar
```

---

## 第五部分：生成并打开 Xcode 项目

```bash
# 确保在项目目录中
cd ~/Desktop/Translatar

# 生成Xcode项目
xcodegen generate
```

看到 "**Generated Translatar.xcodeproj**" 就表示成功了！

然后双击桌面上 `Translatar` 文件夹中的 **`Translatar.xcodeproj`** 文件，Xcode 会自动打开。

---

## 第六部分：在 Xcode 中配置签名

这一步是告诉苹果"这个应用是您开发的"。

1. 在 Xcode 左侧面板，点击最顶部的 **"Translatar"** 项目图标（蓝色图标）
2. 在中间面板选择 **"Translatar"** target
3. 点击 **"Signing & Capabilities"** 标签页
4. 勾选 **"Automatically manage signing"**
5. 在 **"Team"** 下拉菜单中选择您的 Apple ID
   - 如果没有看到您的 Apple ID，点击 "Add Account..." 登录
6. **Bundle Identifier** 改为独一无二的名称，比如：`com.yourname.translatar`

> **如果看到红色错误**：通常是 Bundle Identifier 重复了，改一个独特的名称即可。

---

## 第七部分：连接 iPhone 并运行

1. 用数据线将 **iPhone 连接到 Mac**
2. iPhone 上弹出"信任此电脑？"，点击 **"信任"**
3. 在 Xcode 顶部工具栏，点击设备选择器（显示"Any iOS Device"的地方）
4. 选择您的 **iPhone 设备名称**
5. 点击左上角的 **▶️ 运行按钮**

### 首次运行可能遇到的提示：

**"不受信任的开发者"**：
1. 在 iPhone 上打开 **"设置"**
2. 进入 **"通用" → "VPN与设备管理"**
3. 找到您的 Apple ID，点击 **"信任"**
4. 回到 Xcode，再次点击 ▶️ 运行

---

## 第八部分：配置应用并开始使用

1. 应用安装成功后，在 iPhone 上打开 **Translatar**
2. 允许 **麦克风权限**（弹窗提示时点击"允许"）
3. 点击右上角 **⚙️ 齿轮图标** 进入设置
4. 在 **"OpenAI API 密钥"** 处粘贴您之前保存的密钥
5. 点击 **"完成"**
6. 连接您的 **AirPods**
7. 选择语言（比如：对方说"English"，翻译成"中文"）
8. 点击中央的 **"开始翻译"** 按钮

**恭喜！您的AI翻译耳机已经可以使用了！**

---

## 常见问题

| 问题 | 解决方案 |
|:---|:---|
| Xcode下载太慢 | 确保网络稳定，可以尝试使用VPN |
| "不受信任的开发者" | iPhone设置 → 通用 → VPN与设备管理 → 信任 |
| 编译报错 | 确保Xcode版本15+，iOS部署目标17.0 |
| 没有声音输出 | 检查AirPods是否已连接，音量是否开启 |
| 翻译没有反应 | 检查API密钥是否正确，网络是否通畅 |
| API报错 | 检查OpenAI账户余额是否充足 |

---

## 需要帮助？

如果在部署过程中遇到任何问题，请随时联系我（Manus AI），我会帮您排查和解决。您只需要把错误截图发给我即可。

---

*祝您使用愉快！*
