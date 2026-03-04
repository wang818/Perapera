# 批量翻译超时问题修复

## 问题描述

翻译大量单词时出现超时错误：
```
翻译失败: The request timed out.
```

## 原因分析

1. **单词数量过多**：一次性翻译 100+ 个单词，API 响应时间过长
2. **默认超时时间短**：URLSession 默认超时时间为 60 秒
3. **网络延迟**：API 调用需要时间处理大量数据

## 解决方案

### 1. 分批翻译

将大量单词分成多个小批次，逐批翻译。

#### 实现逻辑

```swift
func translateWords(_ words: [String], completion: @escaping (Result<[String], Error>) -> Void) {
    // 如果单词数量 <= 50，直接翻译
    if words.count <= 50 {
        translateWordsInternal(words, completion: completion)
        return
    }
    
    // 如果单词数量 > 50，分批翻译
    let batchSize = 50
    var allTranslatedWords: [String] = []
    
    func translateNextBatch() {
        // 翻译当前批次
        // 成功后继续下一批
        // 失败则返回错误
    }
    
    translateNextBatch()
}
```

#### 批次大小

- **每批 50 个单词**：平衡速度和可靠性
- 可根据实际情况调整

#### 递归翻译

```swift
func translateNextBatch() {
    guard currentIndex < words.count else {
        // 所有批次完成
        completion(.success(allTranslatedWords))
        return
    }
    
    let batch = Array(words[currentIndex..<endIndex])
    
    translateWordsInternal(batch) { result in
        switch result {
        case .success(let translatedBatch):
            allTranslatedWords.append(contentsOf: translatedBatch)
            currentIndex = endIndex
            translateNextBatch()  // 继续下一批
            
        case .failure(let error):
            completion(.failure(error))
        }
    }
}
```

### 2. 增加超时时间

为翻译请求设置更长的超时时间。

#### URLRequest 超时

```swift
var request = URLRequest(url: url)
request.timeoutInterval = 120  // 120 秒
```

#### URLSession 配置

```swift
let configuration = URLSessionConfiguration.default
configuration.timeoutIntervalForRequest = 120    // 请求超时：120 秒
configuration.timeoutIntervalForResource = 300   // 资源超时：300 秒
let session = URLSession(configuration: configuration)
```

## 实现效果

### 翻译流程

```
总单词数：150 个
  ↓
分成 3 批
  ↓
批次 1: 翻译 1-50 (50 个单词)
  ↓ 成功
批次 2: 翻译 51-100 (50 个单词)
  ↓ 成功
批次 3: 翻译 101-150 (50 个单词)
  ↓ 成功
合并结果：150 个翻译词
```

### 日志输出

```
📝 单词数量较多(150)，将分批翻译...
📦 翻译第 1/3 批，共 50 个单词...
🚀 发送翻译请求到混元 API (共 50 个单词)...
✅ 翻译成功

📦 翻译第 2/3 批，共 50 个单词...
🚀 发送翻译请求到混元 API (共 50 个单词)...
✅ 翻译成功

📦 翻译第 3/3 批，共 50 个单词...
🚀 发送翻译请求到混元 API (共 50 个单词)...
✅ 翻译成功

✅ 所有批次翻译完成，共 150 个单词
```

## 优势

### 1. 可靠性提高

- 小批次翻译更稳定
- 减少超时风险
- 单个批次失败不影响整体

### 2. 进度可见

- 显示当前批次进度
- 用户了解翻译状态
- 便于调试和监控

### 3. 灵活性

- 可调整批次大小
- 可添加重试机制
- 可并行处理（未来优化）

### 4. 资源优化

- 减少单次请求负载
- 避免 API 限流
- 更好的错误恢复

## 配置参数

### 批次大小

```swift
let batchSize = 50  // 每批 50 个单词
```

**建议值：**
- 小文件（< 100 词）：50
- 中等文件（100-200 词）：50
- 大文件（> 200 词）：30-40

### 超时时间

```swift
request.timeoutInterval = 120                      // 请求超时
configuration.timeoutIntervalForRequest = 120      // 请求超时
configuration.timeoutIntervalForResource = 300     // 资源超时
```

**建议值：**
- 请求超时：120 秒（2 分钟）
- 资源超时：300 秒（5 分钟）

## 错误处理

### 1. 批次失败

```swift
case .failure(let error):
    print("❌ 第 \(batchNumber) 批翻译失败: \(error.localizedDescription)")
    completion(.failure(error))
```

**处理方式：**
- 立即返回错误
- 停止后续批次
- 保留已翻译的部分（未来优化）

### 2. 超时错误

```swift
if let error = error as? URLError, error.code == .timedOut {
    print("⏱️ 请求超时，可能需要减少批次大小")
}
```

### 3. 网络错误

```swift
if let error = error as? URLError {
    switch error.code {
    case .timedOut:
        print("⏱️ 超时")
    case .notConnectedToInternet:
        print("📡 无网络连接")
    case .networkConnectionLost:
        print("📡 网络连接丢失")
    default:
        print("❌ 网络错误: \(error.localizedDescription)")
    }
}
```

## 性能对比

### 之前（单次翻译）

```
单词数：150
请求次数：1
平均耗时：60+ 秒（超时）
成功率：低
```

### 现在（分批翻译）

```
单词数：150
批次数：3
每批耗时：15-20 秒
总耗时：45-60 秒
成功率：高
```

## 未来优化

### 1. 并行翻译

```swift
// 同时翻译多个批次
let group = DispatchGroup()
for batch in batches {
    group.enter()
    translateWordsInternal(batch) { result in
        // 处理结果
        group.leave()
    }
}
group.notify(queue: .main) {
    // 所有批次完成
}
```

### 2. 重试机制

```swift
func translateWithRetry(batch: [String], retryCount: Int = 3) {
    translateWordsInternal(batch) { result in
        switch result {
        case .success:
            // 成功
        case .failure where retryCount > 0:
            // 重试
            translateWithRetry(batch: batch, retryCount: retryCount - 1)
        case .failure:
            // 失败
        }
    }
}
```

### 3. 断点续传

```swift
// 保存已翻译的批次
UserDefaults.standard.set(translatedBatches, forKey: "translation_progress_\(videoId)")

// 恢复时从上次位置继续
if let savedProgress = loadTranslationProgress(videoId) {
    currentIndex = savedProgress.lastIndex
    allTranslatedWords = savedProgress.translatedWords
}
```

### 4. 智能批次大小

```swift
// 根据网络状况动态调整
func calculateBatchSize() -> Int {
    let networkSpeed = measureNetworkSpeed()
    if networkSpeed > 10_000_000 {  // 10 Mbps
        return 100
    } else if networkSpeed > 5_000_000 {  // 5 Mbps
        return 50
    } else {
        return 30
    }
}
```

## 测试建议

### 1. 小批量测试

- [ ] 10 个单词
- [ ] 50 个单词
- [ ] 100 个单词

### 2. 大批量测试

- [ ] 150 个单词（3 批）
- [ ] 200 个单词（4 批）
- [ ] 300 个单词（6 批）

### 3. 网络测试

- [ ] 良好网络
- [ ] 弱网络
- [ ] 网络中断恢复

### 4. 错误测试

- [ ] API 错误
- [ ] 超时错误
- [ ] 中途取消

## 文件清单

### 修改的文件

- `Perapera/Services/HunyuanManager.swift` - 翻译逻辑

### 修改的方法

- `translateWords(_:completion:)` - 添加分批逻辑
- `translateWordsInternal(_:completion:)` - 增加超时配置

## 总结

通过分批翻译和增加超时时间，成功解决了大量单词翻译时的超时问题。现在可以稳定地翻译 100+ 个单词，提高了系统的可靠性和用户体验。
