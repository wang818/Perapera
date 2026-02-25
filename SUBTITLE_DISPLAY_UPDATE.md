# 字幕显示功能更新

## 更新概述

根据 ASR 识别结果的 JSON 文件（如 123.json）重新实现了字幕加载和显示功能。

## 123.json 数据结构分析

```json
{
  "Response": {
    "Data": {
      "AudioDuration": 104.095063,
      "ResultDetail": [
        {
          "FinalSentence": "完整的句子文本",
          "StartMs": 180,      // 开始时间（毫秒）
          "EndMs": 60660,      // 结束时间（毫秒）
          "Words": [           // 词级别的时间信息
            {
              "Word": "在我",
              "OffsetStartMs": 190,
              "OffsetEndMs": 600
            },
            ...
          ]
        }
      ]
    }
  }
}
```

### 关键发现

1. ResultDetail 数组通常只有 2-3 个大段，每段时长 30-60 秒
2. 每个大段包含完整的句子文本（FinalSentence）
3. Words 数组提供了词级别的精确时间信息
4. 时间单位为毫秒，需要转换为秒

## 实现方案

### 1. 数据模型更新 (SubtitleModel.swift)

#### 新增 ASR 响应模型
```swift
struct ASRResponse: Codable
struct ASRData: Codable
struct ASRResultDetail: Codable
struct ASRWord: Codable
```

#### 扩展 SubtitleItem
```swift
struct SubtitleItem {
    let words: [WordTiming]?  // 新增：词级别时间信息
}

struct WordTiming: Codable {
    let word: String
    let startTime: Double
    let endTime: Double
}
```

### 2. 字幕加载逻辑 (SubtitleManager)

#### loadSubtitlesFromASRFile() 方法

**功能：**
- 从 Documents 目录读取 `{videoId}.json` 文件
- 解析 ASR 识别结果
- 将 Words 数组按 8 个词一组分割成多个字幕项
- 时间从毫秒转换为秒

**分组策略：**
```swift
let wordsPerSubtitle = 8  // 每个字幕显示约 8 个词
```

这样可以将长段文本分割成合适长度的字幕，便于阅读。

### 3. 字幕显示更新 (VideoPlayerView)

#### 双行字幕显示
- 上行：翻译字幕（日文）- 黄色高亮
- 下行：原文字幕（中文）- 黄色高亮
- 灰色：占位符文本

#### 调试信息
显示当前字幕索引：`字幕 1/25`

### 4. ViewModel 更新 (VideoPlayerViewModel)

#### 字幕加载优先级
```swift
1. 优先从 ASR JSON 文件加载（{videoId}.json）
2. 如果没有，从 UserDefaults 加载已保存的字幕
3. 如果都没有，生成测试用的默认字幕
```

#### 字幕切换跟踪
```swift
@Published var currentSubtitleIndex: Int = -1
```

在控制台输出字幕切换日志：
```
📝 字幕切换: [1/25] 5.2s - 在我身后的就是特斯拉应对...
```

## 使用方法

### 1. 准备 JSON 文件

将 ASR 识别结果保存为 `{videoId}.json`，放在 Documents 目录：

```swift
// 示例路径
/Users/xxx/Library/Developer/CoreSimulator/Devices/.../Documents/{videoId}.json
```

### 2. 播放视频

打开视频播放器，系统会自动：
1. 查找对应的 JSON 文件
2. 解析并生成字幕
3. 根据播放时间显示对应字幕

### 3. 查看日志

在 Xcode 控制台查看字幕加载和切换日志：

```
🔍 尝试加载 ASR 文件: /path/to/{videoId}.json
✅ 从 ASR 文件加载字幕成功，共 25 条
📝 字幕切换: [1/25] 0.2s - 在我身后的就是特斯拉...
```

## 测试建议

### 1. 复制测试文件

```bash
# 假设视频 ID 为 "test-video-123"
cp 123.json ~/Library/Developer/CoreSimulator/Devices/.../Documents/test-video-123.json
```

### 2. 验证功能

- [ ] 字幕能正确加载
- [ ] 字幕时间同步准确
- [ ] 字幕切换流畅
- [ ] 长文本能正确分段
- [ ] 调试信息显示正确

## 后续优化方向

1. **智能分段**：根据标点符号和语义分割字幕，而不是固定 8 个词
2. **字幕翻译**：集成翻译 API，自动生成日文字幕
3. **字幕编辑**：允许用户手动调整字幕时间和文本
4. **字幕导出**：支持导出为 SRT、VTT 等标准格式
5. **高亮当前词**：使用 Words 数组实现卡拉 OK 式的词级别高亮

## 文件清单

### 修改的文件
- `Perapera/Models/SubtitleModel.swift` - 数据模型和加载逻辑
- `Perapera/Views/VideoPlayerView/VideoPlayerView.swift` - UI 显示
- `Perapera/Views/VideoPlayerView/VideoPlayerViewModel.swift` - 业务逻辑

### 测试文件
- `123.json` - ASR 识别结果示例
