# 词级别翻译功能

## 功能概述

翻译只翻译 words 里对应的单词，翻译后的结果直接保存到 `{videoId}_translation.txt` 文件中，视频播放页面的翻译结果区域也和原文一样使用词高亮效果显示译文。

## 实现效果

### 视频播放页面

```
┌─────────────────────────────────────────────┐
│  私の 後ろ の は テスラ 対応 国産 電車...    │  ← 日文翻译（词高亮）
│  ^^^^                                        │
├─────────────────────────────────────────────┤
│  在我 身后 的 就是 特斯拉 应对 国产 电车...  │  ← 中文原文（词高亮）
│  ^^^^                                        │
└─────────────────────────────────────────────┘
```

### 翻译文件格式

`{videoId}_translation.txt`:
```
私の
後ろ
の
は
テスラ
対応
国産
電車
...
```

每行一个翻译后的词，顺序与原文 words 数组一致。

## 实现细节

### 1. 翻译逻辑修改 (HomeView.swift)

#### translateRecognitionResult 方法

**功能：**
- 读取 ASR JSON 文件
- 提取所有 ResultDetail 中的 Words 数组
- 调用翻译 API 翻译所有单词
- 保存为简单文本格式

**代码流程：**

```swift
1. 读取 {videoId}.json 文件
   ↓
2. 解析 Response.Data.ResultDetail
   ↓
3. 收集所有 Words 数组中的 Word 字段
   ↓
4. 调用 HunyuanManager.shared.translateWords()
   ↓
5. 保存翻译结果到 {videoId}_translation.txt
```

#### saveTranslationResultToTxt 方法

**功能：**
- 将翻译后的单词数组保存为文本文件
- 每行一个词，不包含其他信息

**文件格式：**
```
word1
word2
word3
...
```

### 2. 翻译 API 封装 (HunyuanManager.swift)

#### 新增公开方法

```swift
func translateWords(_ words: [String], completion: @escaping (Result<[String], Error>) -> Void)
```

**功能：**
- 接收单词数组
- 调用混元 API 进行批量翻译
- 返回翻译后的单词数组

**内部实现：**
- 构建 JSON 格式的提示词
- 要求 API 返回 `{"JaJPWords": ["词1", "词2", ...]}`
- 解析响应并提取翻译结果

### 3. 字幕模型更新 (SubtitleModel.swift)

#### SubtitleItem 新增字段

```swift
struct SubtitleItem {
    let words: [WordTiming]?           // 原文词时间信息
    let translatedWords: [WordTiming]? // 译文词时间信息
}
```

**translatedWords 结构：**
- 与 words 数组长度相同
- 每个元素的时间信息与原文对应
- word 字段为翻译后的日文

### 4. 字幕加载逻辑 (VideoPlayerViewModel.swift)

#### loadTranslations 方法

**功能：**
- 读取 `{videoId}_translation.txt` 文件
- 按行分割获取翻译后的单词数组
- 调用 applyTranslationsToSubtitles 应用翻译

#### applyTranslationsToSubtitles 方法

**功能：**
- 遍历所有字幕项
- 为每个字幕项创建 translatedWords 数组
- 保持时间信息与原文一致

**代码逻辑：**

```swift
for subtitle in subtitles {
    for word in subtitle.words {
        // 创建翻译后的 WordTiming
        translatedWord = WordTiming(
            word: translatedWords[index],  // 翻译后的词
            startTime: word.startTime,     // 保持原文时间
            endTime: word.endTime
        )
    }
}
```

### 5. 视图显示 (VideoPlayerView.swift)

#### 字幕区域布局

```swift
VStack {
    // 上：日文翻译（词高亮）
    if let translatedWords = subtitle.translatedWords {
        WordHighlightSubtitleView(words: translatedWords, currentTime: currentTime)
    }
    
    Divider()
    
    // 下：中文原文（词高亮）
    if let words = subtitle.words {
        WordHighlightSubtitleView(words: words, currentTime: currentTime)
    }
}
```

## 数据流

### 翻译流程

```
ASR 识别完成
  ↓
读取 {videoId}.json
  ↓
提取所有 Words 数组
  ↓
调用翻译 API
  ↓
保存到 {videoId}_translation.txt
  ↓
刷新视频列表
```

### 播放流程

```
打开视频播放器
  ↓
加载 {videoId}.json（原文）
  ↓
加载 {videoId}_translation.txt（译文）
  ↓
合并为 SubtitleItem（包含 words 和 translatedWords）
  ↓
根据播放时间高亮显示
```

## 文件格式示例

### 输入：{videoId}.json

```json
{
  "Response": {
    "Data": {
      "ResultDetail": [
        {
          "Words": [
            {"Word": "在我", "OffsetStartMs": 190, "OffsetEndMs": 600},
            {"Word": "身后", "OffsetStartMs": 600, "OffsetEndMs": 930},
            {"Word": "的", "OffsetStartMs": 930, "OffsetEndMs": 1095}
          ]
        }
      ]
    }
  }
}
```

### 输出：{videoId}_translation.txt

```
私の
後ろ
の
```

### 内存中的数据结构

```swift
SubtitleItem(
    startTime: 0.19,
    endTime: 1.095,
    originalText: "在我身后的",
    translatedText: "私の後ろの",
    words: [
        WordTiming(word: "在我", startTime: 0.19, endTime: 0.60),
        WordTiming(word: "身后", startTime: 0.60, endTime: 0.93),
        WordTiming(word: "的", startTime: 0.93, endTime: 1.095)
    ],
    translatedWords: [
        WordTiming(word: "私の", startTime: 0.19, endTime: 0.60),
        WordTiming(word: "後ろ", startTime: 0.60, endTime: 0.93),
        WordTiming(word: "の", startTime: 0.93, endTime: 1.095)
    ]
)
```

## 优势

### 1. 精确对应

- 每个原文词都有对应的译文词
- 时间信息完全一致
- 便于实现词级别的同步高亮

### 2. 简单格式

- 翻译文件格式简单，易于编辑
- 每行一个词，便于人工校对
- 文件大小小，加载快速

### 3. 灵活性

- 可以手动编辑翻译文件
- 支持重新翻译（覆盖文件）
- 易于导入导出

### 4. 用户体验

- 双语字幕同步高亮
- 清晰的视觉对应关系
- 适合语言学习场景

## 翻译 API 调用

### 请求格式

```json
{
  "Model": "hunyuan-lite",
  "Messages": [
    {
      "Role": "user",
      "Content": "请将以下中文单词翻译成日文...\n输入单词数组：[\"在我\", \"身后\", \"的\", ...]"
    }
  ],
  "Temperature": 0.3
}
```

### 响应格式

```json
{
  "Response": {
    "Choices": [
      {
        "Message": {
          "Content": "{\"JaJPWords\": [\"私の\", \"後ろ\", \"の\", ...]}"
        }
      }
    ]
  }
}
```

## 错误处理

### 1. JSON 文件不存在

```swift
guard FileManager.default.fileExists(atPath: jsonFilePath.path) else {
    print("❌ 无法读取 JSON 文件")
    return
}
```

### 2. Words 数组为空

```swift
if allWords.isEmpty {
    print("❌ 没有找到 words 数组")
    return
}
```

### 3. 翻译失败

```swift
case .failure(let error):
    print("❌ 翻译失败: \(error.localizedDescription)")
    viewModel.translationResult = "翻译失败"
```

### 4. 翻译文件不存在

```swift
guard FileManager.default.fileExists(atPath: translationFilePath.path) else {
    print("📭 没有找到翻译文件")
    // 降级为普通字幕显示
    return
}
```

## 日志输出

### 翻译过程

```
🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟
🚀 开始翻译识别结果（词级别）
🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟

📝 准备翻译 150 个单词...
🚀 发送翻译请求到混元 API...
✅ 翻译成功，共 150 个日文单词

============================================================
💾 翻译结果已保存为 TXT 文件
============================================================
📝 文件名: {videoId}_translation.txt
📂 文件路径: /path/to/Documents/{videoId}_translation.txt
📊 单词数量: 150
============================================================
```

### 加载过程

```
✅ 从 ASR 文件加载字幕成功，共 2 条
✅ 加载翻译结果成功，共 150 个词
✅ 翻译已应用到 2 条字幕
```

## 测试建议

### 1. 翻译功能测试

- [ ] 能正确提取 words 数组
- [ ] 翻译 API 调用成功
- [ ] 翻译结果保存正确
- [ ] 文件格式符合预期

### 2. 加载功能测试

- [ ] 能正确读取翻译文件
- [ ] 翻译应用到字幕正确
- [ ] 时间信息保持一致
- [ ] 词数量匹配

### 3. 显示功能测试

- [ ] 双语字幕都能高亮
- [ ] 高亮时间同步
- [ ] 自动滚动正常
- [ ] 降级显示正常（无翻译时）

### 4. 边界情况测试

- [ ] 翻译文件不存在
- [ ] 翻译词数不匹配
- [ ] 空的 words 数组
- [ ] 翻译 API 失败

## 文件清单

### 修改的文件

- `Perapera/Views/HomeView/HomeView.swift` - 翻译逻辑和保存
- `Perapera/Services/HunyuanManager.swift` - 翻译 API 封装
- `Perapera/Models/SubtitleModel.swift` - 数据模型
- `Perapera/Views/VideoPlayerView/VideoPlayerViewModel.swift` - 加载逻辑
- `Perapera/Views/VideoPlayerView/VideoPlayerView.swift` - 显示逻辑

### 新增功能

- 词级别翻译
- 简单文本格式保存
- 双语词高亮显示
- 翻译结果加载和应用

## 使用流程

### 1. 上传视频并识别

```
用户上传视频 → 提取音频 → ASR 识别 → 保存 {videoId}.json
```

### 2. 翻译

```
自动触发翻译 → 提取 words → 调用 API → 保存 {videoId}_translation.txt
```

### 3. 播放

```
打开播放器 → 加载原文和译文 → 合并为字幕 → 词高亮显示
```

## 总结

通过词级别的翻译和高亮显示，用户可以清楚地看到每个原文词对应的译文词，配合时间同步，提供了优秀的双语学习体验。翻译结果保存为简单的文本格式，便于编辑和管理。
