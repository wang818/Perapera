# 状态按钮功能

## 功能概述

将视频列表中的"未转换"、"未识别"、"未翻译"状态标签改为可点击的按钮，点击后自动执行相应的操作。

## 实现效果

### 之前（纯文本显示）

```
┌─────────────────────────────────────┐
│ 视频名称                             │
│ 本地视频  未转换  未识别  未翻译     │
└─────────────────────────────────────┘
```

### 现在（可点击按钮）

```
┌─────────────────────────────────────┐
│ 视频名称                             │
│ 本地视频  [未转换]  未识别  未翻译   │  ← 点击转换音频
│                                      │
│ 视频名称                             │
│ 本地视频  已转换  [未识别]  未翻译   │  ← 点击开始识别
│                                      │
│ 视频名称                             │
│ 本地视频  已转换  已识别  [未翻译]   │  ← 点击开始翻译
└─────────────────────────────────────┘
```

## 按钮状态逻辑

### 1. 音频转换按钮

**显示条件：**
- `!video.hasAudio` - 音频文件不存在

**点击行为：**
- 调用 `convertAudioForVideo(video)`
- 开始转换视频为 opus 音频

**视觉样式：**
- 灰色文字
- 浅灰色背景
- 圆角边框

### 2. 语音识别按钮

**显示条件：**
- `!video.hasRecognition && video.hasAudio` - 未识别但音频已转换

**点击行为：**
- 调用 `startRecognitionForVideo(video)`
- 上传音频到 COS
- 创建 ASR 识别任务
- 轮询查询识别结果

**视觉样式：**
- 橙色文字
- 浅橙色背景
- 圆角边框

**禁用状态：**
- 如果音频未转换，显示为灰色不可点击

### 3. 翻译按钮

**显示条件：**
- `!video.hasTranslation && video.hasRecognition` - 未翻译但已识别

**点击行为：**
- 调用 `startTranslationForVideo(video)`
- 读取识别结果 JSON
- 提取 words 数组
- 调用翻译 API
- 保存翻译结果

**视觉样式：**
- 紫色文字
- 浅紫色背景
- 圆角边框

**禁用状态：**
- 如果未识别，显示为灰色不可点击

## 代码实现

### 1. VideoRowView 修改

#### 添加闭包参数

```swift
struct VideoRowView: View {
    let video: VideoItem
    let onDelete: () -> Void
    let onConvertAudio: () -> Void        // 新增
    let onStartRecognition: () -> Void    // 新增
    let onStartTranslation: () -> Void    // 新增
}
```

#### 按钮实现

```swift
// 音频转换按钮
if !video.hasAudio {
    Button(action: onConvertAudio) {
        HStack(spacing: 4) {
            Image(systemName: "waveform")
            Text("未转换")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(4)
    }
}

// 识别按钮（需要音频已转换）
if !video.hasRecognition && video.hasAudio {
    Button(action: onStartRecognition) {
        HStack(spacing: 4) {
            Image(systemName: "text.bubble")
            Text("未识别")
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(4)
    }
}

// 翻译按钮（需要已识别）
if !video.hasTranslation && video.hasRecognition {
    Button(action: onStartTranslation) {
        HStack(spacing: 4) {
            Image(systemName: "globe")
            Text("未翻译")
        }
        .foregroundColor(.purple)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(4)
    }
}
```

### 2. HomeView 修改

#### 传递闭包

```swift
VideoRowView(
    video: video,
    onDelete: { deleteVideo(video) },
    onConvertAudio: { convertAudioForVideo(video) },
    onStartRecognition: { startRecognitionForVideo(video) },
    onStartTranslation: { startTranslationForVideo(video) }
)
```

#### 新增方法

##### convertAudioForVideo

```swift
private func convertAudioForVideo(_ video: VideoItem) {
    print("🎵 开始转换音频: \(video.name)")
    currentConvertingVideoId = video.id
    convertVideoToAudio(videoURL: video.actualVideoURL, videoId: video.id)
}
```

##### startRecognitionForVideo

```swift
private func startRecognitionForVideo(_ video: VideoItem) {
    guard video.hasAudio else { return }
    
    print("🎤 开始语音识别: \(video.name)")
    currentRecognizingVideoId = video.id
    
    // 上传音频到 COS
    COSUploadManager.shared.uploadFile(fileURL: video.audioURL) { result in
        switch result {
        case .success(let cosURL):
            // 创建识别任务
            ASRManager.shared.createRecognitionTask(audioURL: cosURL) { result in
                switch result {
                case .success(let taskId):
                    // 轮询查询结果
                    pollRecognitionResult(taskId: taskId, videoId: video.id)
                case .failure(let error):
                    print("❌ 创建识别任务失败")
                }
            }
        case .failure(let error):
            print("❌ 音频上传失败")
        }
    }
}
```

##### startTranslationForVideo

```swift
private func startTranslationForVideo(_ video: VideoItem) {
    guard video.hasRecognition else { return }
    
    print("🌐 开始翻译: \(video.name)")
    
    // 读取识别结果
    let recognitionData = try Data(contentsOf: video.recognitionURL)
    
    // 解析获取识别文本
    if let result = parseRecognitionResult(recognitionData) {
        // 开始翻译
        translateRecognitionResult(videoId: video.id, recognizedText: result)
    }
}
```

## 用户体验

### 1. 一键操作

用户无需进入详情页面，直接在列表中点击按钮即可执行操作。

### 2. 状态依赖

按钮会根据前置条件自动启用/禁用：
- 未转换 → 可点击
- 已转换但未识别 → 识别按钮可点击
- 已识别但未翻译 → 翻译按钮可点击

### 3. 视觉反馈

- 可点击按钮：彩色背景
- 不可点击状态：灰色文字
- 已完成状态：彩色文字（无背景）

### 4. 自动刷新

操作完成后自动刷新列表，更新状态显示。

## 操作流程

### 完整流程

```
1. 上传视频
   ↓
2. 点击 [未转换] 按钮
   ↓ 转换音频
3. 点击 [未识别] 按钮
   ↓ 上传 COS → ASR 识别
4. 点击 [未翻译] 按钮
   ↓ 翻译 words
5. 完成 ✅
```

### 单步操作

用户也可以只执行某一步：
- 只转换音频
- 只识别（如果音频已存在）
- 只翻译（如果识别结果已存在）

## 状态图示

```
┌─────────────────────────────────────────────────┐
│ 状态 1: 刚上传                                   │
│ [未转换]  未识别  未翻译                         │
│  ↓ 点击                                          │
│ 转换中...                                        │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│ 状态 2: 音频已转换                               │
│ 已转换  [未识别]  未翻译                         │
│         ↓ 点击                                   │
│         识别中...                                │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│ 状态 3: 已识别                                   │
│ 已转换  已识别  [未翻译]                         │
│                 ↓ 点击                           │
│                 翻译中...                        │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│ 状态 4: 全部完成                                 │
│ 已转换  已识别  已翻译                           │
│ ✅ 可以播放                                      │
└─────────────────────────────────────────────────┘
```

## 错误处理

### 1. 前置条件检查

```swift
guard video.hasAudio else {
    print("❌ 音频文件不存在，无法识别")
    return
}
```

### 2. 文件存在性检查

```swift
guard FileManager.default.fileExists(atPath: video.audioURL.path) else {
    print("❌ 音频文件不存在")
    return
}
```

### 3. API 调用失败

```swift
case .failure(let error):
    print("❌ 操作失败: \(error.localizedDescription)")
    // 重置状态
    currentConvertingVideoId = nil
```

## 优势

### 1. 便捷性

- 无需进入详情页
- 一键完成操作
- 减少操作步骤

### 2. 直观性

- 清晰的状态显示
- 明确的操作提示
- 视觉反馈明显

### 3. 智能性

- 自动判断前置条件
- 禁用不可用操作
- 防止误操作

### 4. 效率

- 批量处理多个视频
- 快速完成工作流
- 提高生产力

## 测试建议

### 1. 功能测试

- [ ] 点击"未转换"按钮能开始转换
- [ ] 点击"未识别"按钮能开始识别
- [ ] 点击"未翻译"按钮能开始翻译
- [ ] 操作完成后状态正确更新

### 2. 状态测试

- [ ] 音频未转换时识别按钮不可点击
- [ ] 未识别时翻译按钮不可点击
- [ ] 已完成的状态显示为文字（非按钮）

### 3. 错误测试

- [ ] 文件不存在时的错误处理
- [ ] API 调用失败时的错误处理
- [ ] 网络异常时的错误处理

### 4. UI 测试

- [ ] 按钮样式正确
- [ ] 颜色区分明显
- [ ] 点击区域合适

## 文件清单

### 修改的文件

- `Perapera/Views/HomeView/HomeView.swift` - 主要修改

### 新增方法

- `convertAudioForVideo(_:)` - 转换音频
- `startRecognitionForVideo(_:)` - 开始识别
- `startTranslationForVideo(_:)` - 开始翻译

### 修改的组件

- `VideoRowView` - 添加闭包参数和按钮

## 总结

通过将状态标签改为可点击按钮，用户可以直接在列表中执行操作，大大提高了使用效率。按钮会根据前置条件自动启用/禁用，防止误操作，提供了更好的用户体验。
