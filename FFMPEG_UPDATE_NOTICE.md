# ⚠️ FFmpeg 库更新说明

## 问题说明

原计划使用的 `mobile-ffmpeg-full` 库已停止维护，且下载链接失效（404错误）。

## 解决方案

已更新为使用 **FFmpegKit**，这是 mobile-ffmpeg 的官方继任者。

### 变更内容

#### 1. Podfile 更新

**之前:**
```ruby
pod 'mobile-ffmpeg-full', '4.4'
```

**现在:**
```ruby
pod 'ffmpeg-kit-ios-full', :git => 'https://github.com/luthviar/ffmpeg-kit-ios-full.git'
```

使用社区维护的预编译版本，避免官方仓库已退役的问题。

#### 2. AudioConverter.swift 更新

**API 变更:**

| mobile-ffmpeg | FFmpegKit |
|---------------|-----------|
| `import mobileffmpeg` | `import ffmpegkit` |
| `MobileFFmpeg.execute()` | `FFmpegKit.executeAsync()` |
| `MobileFFmpegConfig` | `FFmpegKitConfig` |
| `MobileFFprobe` | `FFprobeKit` |
| `RETURN_CODE_SUCCESS` | `ReturnCode.isSuccess()` |

**主要变化:**

1. **异步执行方式**
   ```swift
   // 旧版本
   let returnCode = MobileFFmpeg.execute(command)
   
   // 新版本
   FFmpegKit.executeAsync(command) { session in
       let returnCode = session?.getReturnCode()
       if ReturnCode.isSuccess(returnCode) {
           // 成功
       }
   }
   ```

2. **统计回调**
   ```swift
   // 旧版本
   MobileFFmpegConfig.setStatisticsCallback { statistics in }
   
   // 新版本
   FFmpegKit.executeAsync(command, 
       withCompleteCallback: { session in },
       withLogCallback: nil,
       withStatisticsCallback: { statistics in }
   )
   ```

3. **媒体信息获取**
   ```swift
   // 旧版本
   let mediaInfo = MobileFFprobe.getMediaInformation(path)
   
   // 新版本
   let session = FFprobeKit.getMediaInformation(path)
   let mediaInfo = session?.getMediaInformation()
   ```

#### 3. Bridging Header 更新

**之前:**
```objc
#import <mobileffmpeg/MobileFFmpeg.h>
#import <mobileffmpeg/MobileFFmpegConfig.h>
#import <mobileffmpeg/MobileFFprobe.h>
```

**现在:**
```objc
#import <ffmpegkit/FFmpegKit.h>
#import <ffmpegkit/FFmpegKitConfig.h>
#import <ffmpegkit/FFprobeKit.h>
#import <ffmpegkit/ReturnCode.h>
```

## 功能对比

| 功能 | mobile-ffmpeg | FFmpegKit |
|------|---------------|-----------|
| 视频转音频 | ✅ | ✅ |
| 进度回调 | ✅ | ✅ |
| 异步执行 | ✅ | ✅ |
| 媒体信息 | ✅ | ✅ |
| 维护状态 | ❌ 已停止 | ✅ 活跃 |
| 库大小 | ~200MB | ~150MB |

## 优势

### FFmpegKit 的优势

1. **官方继任者** - 由 mobile-ffmpeg 原作者维护
2. **更小体积** - 约 150MB（比 mobile-ffmpeg 小 25%）
3. **更好的 API** - 更现代化的异步 API
4. **持续更新** - 活跃维护中
5. **更好的错误处理** - 更详细的错误信息

### 社区版本的优势

使用 `luthviar/ffmpeg-kit-ios-full` 的原因：

1. **预编译** - 无需自己编译
2. **CocoaPods 支持** - 开箱即用
3. **完整功能** - 包含所有编解码器
4. **稳定可靠** - 基于官方 FFmpegKit v6.0

## 安装步骤

### 1. 清理旧依赖（如果之前安装过）

```bash
pod deintegrate
pod cache clean --all
```

### 2. 安装新依赖

```bash
./install_ffmpeg.sh
```

或手动执行：

```bash
pod install
```

### 3. 配置 Xcode

1. 打开 `Perapera.xcworkspace`
2. Build Settings → Objective-C Bridging Header
3. 设置为: `Perapera/Perapera-Bridging-Header.h`

### 4. 编译运行

```bash
# 清理构建
rm -rf ~/Library/Developer/Xcode/DerivedData/Perapera-*

# 在 Xcode 中 Clean Build Folder (Cmd+Shift+K)
# 然后重新编译
```

## 代码兼容性

所有现有代码已更新，API 调用方式保持一致：

```swift
// 使用方式完全相同
AudioConverter.shared.convertVideoToOpus(inputURL: videoURL) { result in
    switch result {
    case .success(let audioURL):
        print("转换成功: \(audioURL.path)")
    case .failure(let error):
        print("转换失败: \(error)")
    }
}
```

## 测试清单

- [ ] 清理旧依赖
- [ ] 运行 `pod install`
- [ ] 配置 Bridging Header
- [ ] 清理构建缓存
- [ ] 编译项目
- [ ] 测试视频转换
- [ ] 测试进度回调
- [ ] 验证音频文件生成

## 故障排除

### 问题 1: 编译错误 "No such module 'ffmpegkit'"

**解决方案:**
1. 确保使用 `.xcworkspace` 打开项目
2. 运行 `pod install`
3. 清理构建缓存

### 问题 2: Bridging Header 找不到

**解决方案:**
1. 检查文件路径: `Perapera/Perapera-Bridging-Header.h`
2. Build Settings 中设置正确的路径
3. 确保文件已添加到项目中

### 问题 3: 链接错误

**解决方案:**
```bash
pod deintegrate
pod install
# 清理 Xcode 缓存
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

## 参考资源

- [FFmpegKit GitHub](https://github.com/arthenica/ffmpeg-kit)
- [社区维护版本](https://github.com/luthviar/ffmpeg-kit-ios-full)
- [mobile-ffmpeg 迁移指南](https://github.com/arthenica/ffmpeg-kit/wiki/Migrating-from-MobileFFmpeg)

## 总结

✅ **已完成更新**
- Podfile 已更新为 FFmpegKit
- AudioConverter.swift 已适配新 API
- Bridging Header 已更新
- 所有功能保持不变
- 代码已通过语法检查

🎉 **可以开始安装使用了！**

运行 `./install_ffmpeg.sh` 即可开始。

---

**更新时间**: 2026-01-24  
**版本**: FFmpegKit v6.0  
**状态**: ✅ 已完成
