# 📦 FFmpegKit 安装指南

## 快速开始

### 一键安装

```bash
./install_ffmpeg.sh
```

## 详细步骤

### 步骤 1: 安装依赖

```bash
cd /path/to/Perapera
pod install
```

**预期输出:**
```
Analyzing dependencies
Downloading dependencies
Installing ffmpeg-kit-ios-full (6.0)
Generating Pods project
Integrating client project

[!] Please close any current Xcode sessions and use `Perapera.xcworkspace` for this project from now on.
```

**注意事项:**
- 下载大小约 150MB
- 首次安装可能需要 5-10 分钟
- 需要稳定的网络连接

### 步骤 2: 打开工作空间

⚠️ **重要**: 必须使用 `.xcworkspace` 文件，不是 `.xcodeproj`

```bash
open Perapera.xcworkspace
```

或在 Xcode 中:
```
File → Open → 选择 Perapera.xcworkspace
```

### 步骤 3: 配置 Bridging Header

1. 在 Xcode 中选择项目
2. 选择 Target: `Perapera`
3. 点击 `Build Settings` 标签
4. 搜索 `Objective-C Bridging Header`
5. 双击 `Debug` 和 `Release` 行
6. 输入: `Perapera/Perapera-Bridging-Header.h`

**截图参考:**
```
Build Settings
├── All
├── Combined
└── Levels
    └── Swift Compiler - General
        └── Objective-C Bridging Header
            ├── Debug: Perapera/Perapera-Bridging-Header.h
            └── Release: Perapera/Perapera-Bridging-Header.h
```

### 步骤 4: 验证配置

检查 Bridging Header 文件是否存在:

```bash
ls -la Perapera/Perapera-Bridging-Header.h
```

**文件内容应该包含:**
```objc
#import <ffmpegkit/FFmpegKit.h>
#import <ffmpegkit/FFmpegKitConfig.h>
#import <ffmpegkit/FFprobeKit.h>
#import <ffmpegkit/ReturnCode.h>
```

### 步骤 5: 编译项目

1. 选择目标设备或模拟器
2. 按 `Cmd + B` 编译
3. 或点击 ▶️ 按钮运行

**首次编译:**
- 可能需要 2-3 分钟
- 会编译 FFmpegKit 框架
- 之后的编译会快很多

### 步骤 6: 测试功能

运行应用后:

1. 点击右上角 `+` 按钮
2. 选择 "本地文件" 或 "相册视频"
3. 选择一个视频文件
4. 观察转换进度
5. 检查 Documents 目录是否生成 `.opus` 文件

## 验证安装

### 方法 1: 编译检查

如果编译成功且无错误，说明安装正确。

### 方法 2: 运行时检查

在 `AppDelegate` 或任意 ViewController 中添加:

```swift
import ffmpegkit

func testFFmpegKit() {
    let version = FFmpegKitConfig.getFFmpegVersion()
    print("✅ FFmpegKit 版本: \(version)")
    
    let session = FFmpegKit.execute("-version")
    if let output = session?.getOutput() {
        print("📋 FFmpeg 输出:\n\(output)")
    }
}
```

### 方法 3: 文件检查

检查 Pods 目录:

```bash
ls -la Pods/ffmpeg-kit-ios-full/
```

应该看到:
```
ffmpegkit.xcframework/
LICENSE
README.md
```

## 常见问题

### Q1: pod install 失败

**错误信息:**
```
[!] Error installing ffmpeg-kit-ios-full
```

**解决方案:**
```bash
# 清理缓存
pod cache clean --all

# 更新仓库
pod repo update

# 重新安装
pod install
```

### Q2: 编译错误 "No such module 'ffmpegkit'"

**原因:**
- 未使用 `.xcworkspace` 打开项目
- Bridging Header 配置错误

**解决方案:**
1. 关闭 Xcode
2. 打开 `Perapera.xcworkspace`
3. 检查 Bridging Header 配置
4. Clean Build Folder (Cmd+Shift+K)
5. 重新编译

### Q3: Bridging Header 找不到

**错误信息:**
```
<unknown>:0: error: bridging header 'Perapera/Perapera-Bridging-Header.h' does not exist
```

**解决方案:**
1. 检查文件是否存在
2. 检查路径是否正确（相对于项目根目录）
3. 确保文件已添加到项目中
4. 路径不要以 `/` 开头

### Q4: 链接错误

**错误信息:**
```
Undefined symbols for architecture arm64
```

**解决方案:**
```bash
# 完全清理
pod deintegrate
rm -rf Pods
rm Podfile.lock

# 重新安装
pod install

# 清理 Xcode 缓存
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 重新编译
```

### Q5: 下载速度慢

**解决方案:**

1. **使用代理**
   ```bash
   export https_proxy=http://127.0.0.1:7890
   pod install
   ```

2. **使用国内镜像**（如果可用）
   ```bash
   # 暂时没有可靠的国内镜像
   ```

3. **手动下载**
   - 访问 https://github.com/luthviar/ffmpeg-kit-ios-full
   - 下载 ZIP 文件
   - 解压到 `Pods/ffmpeg-kit-ios-full/`

## 目录结构

安装完成后的目录结构:

```
Perapera/
├── Perapera/
│   ├── Tools/
│   │   ├── AudioConverter.swift          ✅ 音频转换器
│   │   └── VideoStorageManager.swift     ✅ 视频存储
│   ├── Views/
│   │   └── HomeView/
│   │       └── HomeView.swift            ✅ 主界面
│   └── Perapera-Bridging-Header.h        ✅ 桥接头文件
├── Pods/
│   ├── ffmpeg-kit-ios-full/              ✅ FFmpegKit 库
│   ├── Alamofire/
│   ├── Moya/
│   └── ...
├── Perapera.xcworkspace                  ✅ 工作空间
├── Perapera.xcodeproj
├── Podfile                               ✅ 依赖配置
└── Podfile.lock
```

## 性能指标

### 安装大小
- FFmpegKit 框架: ~150MB
- 总安装大小: ~200MB（包含其他依赖）

### 编译时间
- 首次编译: 2-3 分钟
- 增量编译: 10-30 秒

### 运行时性能
- 1 分钟视频转换: 5-10 秒
- 内存占用: ~50-100MB
- CPU 使用: 60-80%（转换时）

## 下一步

安装完成后，可以:

1. **阅读文档**
   - [集成指南](FFMPEG_INTEGRATION_GUIDE.md)
   - [使用示例](FFMPEG_USAGE_EXAMPLE.md)
   - [更新说明](FFMPEG_UPDATE_NOTICE.md)

2. **测试功能**
   - 上传测试视频
   - 验证音频转换
   - 检查文件保存

3. **自定义配置**
   - 调整比特率
   - 修改采样率
   - 添加自定义参数

## 技术支持

遇到问题？

1. 查看 [故障排除](#常见问题)
2. 检查 [更新说明](FFMPEG_UPDATE_NOTICE.md)
3. 查看 FFmpegKit 日志输出
4. 检查 Xcode 编译错误信息

## 完成 ✅

安装完成后，你应该能够:

- ✅ 成功编译项目
- ✅ 运行应用
- ✅ 上传视频
- ✅ 转换音频
- ✅ 保存文件

**祝你使用愉快！** 🎉

---

**文档版本**: 1.0.0  
**更新时间**: 2026-01-24  
**FFmpegKit 版本**: 6.0
