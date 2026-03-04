# ASR 原始 JSON 保存功能

## 更新概述

修改了 ASR 识别结果的保存逻辑，现在直接保存 API 返回的原始 JSON 响应，而不是处理后的自定义格式。

## 修改内容

### 1. ASRManager.swift

#### queryRecognitionResult 方法签名变更

**之前：**
```swift
func queryRecognitionResult(
    taskId: Int,
    completion: @escaping (Result<ASRResultResponse.TaskResult, Error>) -> Void
)
```

**现在：**
```swift
func queryRecognitionResult(
    taskId: Int,
    completion: @escaping (Result<(taskResult: ASRResultResponse.TaskResult, rawJSON: Data), Error>) -> Void
)
```

**改动说明：**
- 返回值从单一的 `TaskResult` 改为元组 `(taskResult, rawJSON)`
- `taskResult`: 解析后的结果对象，用于判断状态和获取文本
- `rawJSON`: API 返回的原始 JSON Data，用于直接保存到文件

### 2. HomeView.swift

#### pollRecognitionResult 方法

**改动：**
```swift
// 之前
case .success(let taskResult):
    // 只能获取解析后的结果

// 现在
case .success(let (taskResult, rawJSON)):
    // 同时获取解析结果和原始 JSON
```

#### 新增 saveRawRecognitionJSON 方法

**功能：**
- 直接保存 ASR API 返回的原始 JSON 响应
- 不做任何处理或转换
- 保持完整的数据结构，包括 Words 数组等详细信息

**代码：**
```swift
private func saveRawRecognitionJSON(videoId: String, rawJSON: Data, recognizedText: String) {
    let fileURL = documentsDirectory.appendingPathComponent("\(videoId).json")
    try rawJSON.write(to: fileURL)
    // ...
}
```

#### 删除 saveRecognitionResultToJSON 方法

**原因：**
- 旧方法会创建自定义格式的 JSON，丢失了原始数据
- 新方法直接保存原始响应，保留所有信息

#### 修改 translateRecognitionResult 方法

**改动：**
```swift
// 之前
private func translateRecognitionResult(videoId: String, jsonData: Data)

// 现在
private func translateRecognitionResult(videoId: String, recognizedText: String)
```

**原因：**
- 不再需要从 JSON 中解析文本
- 直接使用已经解析好的 `recognizedText`

## 保存的 JSON 格式

### 原始 ASR API 响应格式

```json
{
  "Response": {
    "RequestId": "c633907c-a31d-4bff-8c63-9bb09df7b066",
    "Data": {
      "TaskId": 14149671390,
      "Status": 2,
      "StatusStr": "success",
      "AudioDuration": 104.095063,
      "Result": "完整的识别文本...",
      "ResultDetail": [
        {
          "FinalSentence": "句子文本",
          "SliceSentence": "分词结果",
          "StartMs": 180,
          "EndMs": 60660,
          "SpeechSpeed": 4.6,
          "WordsNum": 150,
          "Words": [
            {
              "Word": "在我",
              "OffsetStartMs": 190,
              "OffsetEndMs": 600
            }
            // ... 更多词
          ]
        }
        // ... 更多句子
      ]
    }
  }
}
```

### 之前的自定义格式（已废弃）

```json
{
  "videoId": "xxx",
  "taskId": 123,
  "recognizedText": "识别文本",
  "timestamp": 1234567890,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

## 优势

### 1. 保留完整信息

原始 JSON 包含：
- ✅ 完整的句子文本（FinalSentence）
- ✅ 分词结果（SliceSentence）
- ✅ 词级别的时间信息（Words 数组）
- ✅ 语速、词数等元数据
- ✅ 音频时长（AudioDuration）

### 2. 兼容字幕显示

- 字幕加载器（SubtitleManager）已经支持解析这种格式
- 可以利用 Words 数组实现精确的字幕同步
- 支持按词分组显示字幕

### 3. 便于调试

- 保存完整的 API 响应，便于排查问题
- 可以直接查看原始数据结构
- 不会因为自定义处理而丢失信息

### 4. 未来扩展

- 可以利用更多的元数据（语速、情绪等）
- 支持说话人识别（SpeakerId）
- 支持情绪分析（EmotionType）

## 日志输出

### 保存成功日志

```
============================================================
💾 ASR 原始 JSON 已保存
============================================================
📝 文件名: {videoId}.json
📂 文件路径: /path/to/Documents/{videoId}.json
🆔 视频ID: {videoId}
📄 识别文本长度: 234 字符
📦 JSON 文件大小: 15.2 KB

📋 JSON 内容预览:
{
  "Response": {
    "RequestId": "...",
    "Data": {
      ...
    }
  }
}
... (共 15234 字符)
============================================================
```

## 使用流程

### 1. 音频识别

```
用户上传视频
  ↓
提取音频（opus 格式）
  ↓
上传到 COS
  ↓
调用 ASR API 创建识别任务
  ↓
轮询查询识别结果
```

### 2. 保存结果

```
识别成功（Status = 2）
  ↓
获取原始 JSON Data
  ↓
直接写入 {videoId}.json
  ↓
刷新视频列表
  ↓
自动触发翻译
```

### 3. 字幕显示

```
打开视频播放器
  ↓
加载 {videoId}.json
  ↓
解析 ResultDetail 数组
  ↓
按 Words 分组生成字幕
  ↓
根据播放时间显示字幕
```

## 测试验证

### 1. 检查文件内容

```bash
# 查看保存的 JSON 文件
cat ~/Library/Developer/CoreSimulator/Devices/.../Documents/{videoId}.json | python3 -m json.tool
```

### 2. 验证数据结构

```bash
# 检查是否包含 Response.Data.ResultDetail
cat {videoId}.json | python3 -c "import json, sys; data = json.load(sys.stdin); print('ResultDetail 数量:', len(data['Response']['Data']['ResultDetail']))"
```

### 3. 验证 Words 数组

```bash
# 检查第一个句子的词数
cat {videoId}.json | python3 -c "import json, sys; data = json.load(sys.stdin); words = data['Response']['Data']['ResultDetail'][0]['Words']; print('第一句词数:', len(words))"
```

## 兼容性说明

### 向后兼容

- 旧的自定义格式 JSON 文件仍然可以读取（如果存在）
- SubtitleManager 会优先尝试加载新格式
- 如果新格式不存在，会尝试从 UserDefaults 加载

### 迁移建议

如果已有旧格式的 JSON 文件：
1. 可以删除旧文件，重新识别
2. 或者保留旧文件，新识别的视频会使用新格式

## 文件清单

### 修改的文件

- `Perapera/Services/ASRManager.swift` - 返回原始 JSON
- `Perapera/Views/HomeView/HomeView.swift` - 保存原始 JSON

### 相关文件

- `Perapera/Models/SubtitleModel.swift` - 解析 JSON 生成字幕
- `Perapera/Views/VideoPlayerView/VideoPlayerViewModel.swift` - 加载字幕

## 注意事项

1. **文件大小**：原始 JSON 比自定义格式大，但包含更多信息
2. **解析性能**：首次加载时需要解析完整的 JSON，但已优化
3. **存储空间**：建议定期清理不需要的识别结果文件
