#!/bin/bash

echo "🎬 开始安装 FFmpegKit 依赖..."
echo ""

# 检查是否安装了 CocoaPods
if ! command -v pod &> /dev/null
then
    echo "❌ 未找到 CocoaPods"
    echo "请先安装 CocoaPods: sudo gem install cocoapods"
    exit 1
fi

echo "✅ 找到 CocoaPods"
echo ""

# 显示 CocoaPods 版本
echo "📦 CocoaPods 版本:"
pod --version
echo ""

# 更新 CocoaPods 仓库（可选）
echo "🔄 更新 CocoaPods 仓库（可选，按 Ctrl+C 跳过）..."
read -t 5 -p "是否更新仓库？(y/n): " update_repo
if [ "$update_repo" = "y" ]; then
    pod repo update
fi
echo ""

# 安装依赖
echo "📥 安装依赖..."
echo "⚠️  注意: FFmpegKit 约 150MB，下载可能需要一些时间"
echo "📌 使用社区维护的版本: ffmpeg-kit-ios-full"
echo ""

pod install

# 检查安装结果
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ FFmpegKit 依赖安装成功!"
    echo ""
    echo "📋 后续步骤:"
    echo "1. 使用 Xcode 打开 Perapera.xcworkspace（不是 .xcodeproj）"
    echo "2. 选择 Target: Perapera"
    echo "3. 进入 Build Settings"
    echo "4. 搜索 'Objective-C Bridging Header'"
    echo "5. 设置值为: Perapera/Perapera-Bridging-Header.h"
    echo "6. 编译运行项目"
    echo ""
    echo "📖 详细文档: 查看 FFMPEG_INTEGRATION_GUIDE.md"
else
    echo ""
    echo "❌ 安装失败"
    echo "请检查错误信息并重试"
    exit 1
fi
