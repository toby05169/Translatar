#!/bin/bash
# ============================================
# Translatar v3.0 - 全自动编译部署脚本
# ============================================
# 使用方法：在Mac终端中粘贴以下命令即可
# 此脚本会自动完成：
# 1. 更新代码
# 2. 安装XcodeGen（如果需要）
# 3. 生成Xcode项目
# 4. 在模拟器上编译运行

set -e

echo ""
echo "=========================================="
echo "  🎧 Translatar v3.0 - 全自动编译部署"
echo "=========================================="
echo ""

# 确定项目路径
PROJECT_DIR=""
if [ -d "$HOME/Desktop/Translatar" ]; then
    PROJECT_DIR="$HOME/Desktop/Translatar"
elif [ -d "$HOME/Documents/Translatar" ]; then
    PROJECT_DIR="$HOME/Documents/Translatar"
elif [ -d "$HOME/Downloads/Translatar" ]; then
    PROJECT_DIR="$HOME/Downloads/Translatar"
elif [ -d "$(pwd)/Translatar" ]; then
    PROJECT_DIR="$(pwd)/Translatar"
elif [ -f "$(pwd)/project.yml" ]; then
    PROJECT_DIR="$(pwd)"
fi

if [ -z "$PROJECT_DIR" ]; then
    echo "❌ 未找到Translatar项目目录"
    echo "请先将项目放到桌面，或在项目目录中运行此脚本"
    exit 1
fi

cd "$PROJECT_DIR"
echo "📁 项目目录: $PROJECT_DIR"
echo ""

# 步骤1：拉取最新代码
echo "📥 步骤1/5：更新代码..."
if [ -d ".git" ]; then
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "⚠️ Git更新跳过（可能不是git仓库）"
fi
echo "✅ 代码已是最新"
echo ""

# 步骤2：安装XcodeGen
echo "🔧 步骤2/5：检查XcodeGen..."
if ! command -v xcodegen &> /dev/null; then
    echo "正在安装XcodeGen..."
    brew install xcodegen 2>/dev/null || {
        echo "正在通过Homebrew安装..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>/dev/null
        brew install xcodegen
    }
fi
echo "✅ XcodeGen已就绪"
echo ""

# 步骤3：清理旧的SPM缓存（解决依赖问题）
echo "🧹 步骤3/5：清理缓存..."
rm -rf ~/Library/Caches/org.swift.swiftpm/repositories/starscream* 2>/dev/null
rm -rf ~/Library/Developer/Xcode/DerivedData/Translatar-* 2>/dev/null
rm -rf .build 2>/dev/null
rm -rf Translatar.xcodeproj 2>/dev/null
echo "✅ 缓存已清理"
echo ""

# 步骤4：生成Xcode项目
echo "🏗️ 步骤4/5：生成Xcode项目..."
xcodegen generate
echo "✅ Xcode项目已生成"
echo ""

# 步骤5：编译并运行
echo "🚀 步骤5/5：编译项目..."
echo "（首次编译可能需要2-5分钟，请耐心等待）"
echo ""

# 查找可用的模拟器
SIMULATOR_NAME=""
for sim in "iPhone 16 Pro" "iPhone 15 Pro" "iPhone 16" "iPhone 15" "iPhone 14 Pro" "iPhone 14"; do
    if xcrun simctl list devices available | grep -q "$sim"; then
        SIMULATOR_NAME="$sim"
        break
    fi
done

if [ -z "$SIMULATOR_NAME" ]; then
    echo "⚠️ 未找到iPhone模拟器，尝试使用第一个可用设备..."
    SIMULATOR_NAME=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed 's/^[[:space:]]*//' | sed 's/ (.*//')
fi

echo "📱 使用模拟器: $SIMULATOR_NAME"
echo ""

# 编译项目
xcodebuild \
    -project Translatar.xcodeproj \
    -scheme Translatar \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
    -configuration Debug \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    clean build 2>&1 | while IFS= read -r line; do
    if echo "$line" | grep -q "error:"; then
        echo "❌ $line"
    elif echo "$line" | grep -q "BUILD SUCCEEDED"; then
        echo "✅ $line"
    elif echo "$line" | grep -q "BUILD FAILED"; then
        echo "❌ $line"
    elif echo "$line" | grep -q "Compiling"; then
        echo "⏳ $line"
    fi
done

# 检查编译结果
BUILD_DIR=$(find ~/Library/Developer/Xcode/DerivedData/Translatar-*/Build/Products/Debug-iphonesimulator -name "Translatar.app" -maxdepth 1 2>/dev/null | head -1)

if [ -n "$BUILD_DIR" ]; then
    echo ""
    echo "✅ 编译成功！"
    echo ""
    echo "正在启动模拟器并安装应用..."
    
    # 启动模拟器
    xcrun simctl boot "$SIMULATOR_NAME" 2>/dev/null || true
    open -a Simulator 2>/dev/null || true
    sleep 3
    
    # 安装应用
    xcrun simctl install booted "$BUILD_DIR"
    
    # 启动应用
    xcrun simctl launch booted com.translatar.app
    
    echo ""
    echo "=========================================="
    echo "  🎉 Translatar 已成功启动！"
    echo "=========================================="
    echo ""
    echo "应用已在iPhone模拟器中运行。"
    echo ""
    echo "⚠️ 注意事项："
    echo "1. 模拟器不支持真实麦克风，翻译功能需要在真机上测试"
    echo "2. 要部署到真机，请在Xcode中设置开发团队签名"
    echo "3. 首次使用请在设置中输入OpenAI API密钥"
    echo ""
else
    echo ""
    echo "❌ 编译失败，请查看上方的错误信息"
    echo ""
    echo "常见解决方法："
    echo "1. 确保已安装最新版Xcode"
    echo "2. 运行: sudo xcode-select -s /Applications/Xcode.app"
    echo "3. 截图错误信息发给Manus"
    echo ""
fi
