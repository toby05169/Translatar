#!/bin/bash
# ============================================
# Translatar - Xcode项目自动配置脚本
# ============================================
#
# 使用说明：
# 1. 在Mac上打开终端
# 2. cd 到 Translatar 目录
# 3. 运行: chmod +x setup_xcode_project.sh && ./setup_xcode_project.sh
#
# 此脚本会自动创建Xcode项目配置文件

echo "=========================================="
echo "  Translatar - Xcode项目配置工具"
echo "=========================================="
echo ""

# 检查是否在正确的目录
if [ ! -d "Translatar" ]; then
    echo "错误：请在Translatar根目录下运行此脚本"
    exit 1
fi

# 检查是否安装了Xcode命令行工具
if ! command -v xcodebuild &> /dev/null; then
    echo "错误：未检测到Xcode，请先安装Xcode"
    echo "可以从App Store下载，或运行: xcode-select --install"
    exit 1
fi

echo "✅ 检测到Xcode"

# 使用swift package生成Xcode项目（如果有Package.swift）
# 或者使用xcodegen（推荐）

# 检查是否安装了xcodegen
if command -v xcodegen &> /dev/null; then
    echo "✅ 检测到XcodeGen，正在生成项目..."
    xcodegen generate
else
    echo "⚠️  未检测到XcodeGen"
    echo "正在安装XcodeGen..."
    brew install xcodegen 2>/dev/null || {
        echo "请手动安装: brew install xcodegen"
        echo "或者使用下面的手动创建方式"
    }
    
    if command -v xcodegen &> /dev/null; then
        xcodegen generate
    fi
fi

echo ""
echo "=========================================="
echo "  配置完成！"
echo "=========================================="
echo ""
echo "下一步操作："
echo "1. 双击 Translatar.xcodeproj 打开项目"
echo "2. 选择您的开发团队（Signing & Capabilities）"
echo "3. 连接iPhone，选择设备后点击运行"
echo ""
