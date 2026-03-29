#!/bin/bash

# 构建脚本 - 创建完整的 .app 应用程序包
# 使用方法：./build_app.sh

set -e

APP_NAME="EasyEnglish"
BUILD_DIR=".build/release"
OUTPUT_DIR="dist"
APP_BUNDLE="$OUTPUT_DIR/${APP_NAME}.app"

echo "🔨 开始构建 ${APP_NAME}.app ..."

# 1. 清理旧的构建产物
echo "🧹 清理旧的构建产物..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# 2. 编译 Release 版本
echo "📦 编译 Release 版本..."
swift build -c release --product "${APP_NAME}.app"

# 3. 创建 App Bundle 目录结构
echo "📁 创建 App Bundle 结构..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

# 4. 复制可执行文件
echo "🚀 复制可执行文件..."
cp ".build/release/${APP_NAME}.app" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"

# 5. 创建 Info.plist
echo "📝 创建 Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.easyenglish.app</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 6. 复制资源文件（如果存在）
if [ -d "Sources/EasyEnglishApp/Resources" ]; then
    echo "📚 复制资源文件..."
    cp -R "Sources/EasyEnglishApp/Resources/"* "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
fi

# 7. 设置权限
echo "🔐 设置权限..."
chmod +x "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"

# 8. 签名（可选，用于开发）
# codesign --force --deep -s - "$APP_BUNDLE"

echo "✅ 构建完成！"
echo "📍 位置：$APP_BUNDLE"
echo ""
echo "运行应用:"
echo "  open $APP_BUNDLE"