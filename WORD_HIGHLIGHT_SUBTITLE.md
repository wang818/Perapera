# 词级别高亮字幕功能

## 功能概述

在视频播放页面的原始字幕位置，展示所有的 words 字段，并根据视频播放时间高亮显示当前正在说的词，实现卡拉 OK 式的字幕效果。

## 实现效果

### 视觉效果

```
┌─────────────────────────────────────────────┐
│  日文字幕（翻译结果）                        │
├─────────────────────────────────────────────┤
│  在我 身后 的 就是 特斯拉 应对 国产 电车...  │
│  ^^^^                                        │
│  (黄色高亮 + 加粗 + 背景色)                  │
└─────────────────────────────────────────────┘
```

### 交互效果

1. **高亮显示**：当前播放的词显示为黄色加粗
2. **背景高亮**：当前词有淡黄色背景
3. **自动滚动**：字幕区域自动滚动，保持当前词在中心位置
4. **流畅切换**：词与词之间平滑过渡，带动画效果

## 代码实现

### 1. 数据模型更新 (SubtitleModel.swift)

#### 修改字幕加载逻辑

**之前：** 将长段文本按 8 个词一组分割成多个字幕项

**现在：** 为每个大段创建一个字幕项，保留完整的 words 数组

```swift
// 为整个大段创建一个字幕项
let subtitle = SubtitleItem(
    startTime: startTime,
    endTime: endTime,
    originalText: detail.FinalSentence,  // 完整句子
    translatedText: "",
    words: wordTimings  // 所有词的时间信息
)
```

**优势：**
- 保持句子的完整性
- 所有词都在一个字幕项中
- 便于实现词级别的高亮

### 2. 视图组件 (VideoPlayerView.swift)

#### 新增 WordHighlightSubtitleView 组件

**功能：**
- 横向滚动显示所有词
- 根据播放时间高亮当前词
- 自动滚动到当前词的位置

**核心代码：**

```swift
struct WordHighlightSubtitleView: View {
    let words: [WordTiming]
    let currentTime: Double
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        let isActive = currentTime >= word.startTime && currentTime <= word.endTime
                        
                        Text(word.word)
                            .font(.subheadline)
                            .fontWeight(isActive ? .bold : .regular)
                            .foregroundColor(isActive ? .yellow : .white)
                            .padding(.horizontal, 2)
                            .background(isActive ? Color.yellow.opacity(0.2) : Color.clear)
                            .cornerRadius(4)
                            .id(index)
                            .onChange(of: isActive) { newValue in
                                if newValue {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        proxy.scrollTo(index, anchor: .center)
                                    }
                                }
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
    }
}
```

#### 修改字幕区域显示逻辑

```swift
// 原文字幕（下）- 中文，带词级别高亮
if let subtitle = viewModel.currentSubtitle, let words = subtitle.words {
    // 有 words 数组，使用词高亮组件
    WordHighlightSubtitleView(
        words: words,
        currentTime: viewModel.currentTime
    )
    .frame(height: 80)
} else {
    // 没有 words 数组，使用普通字幕组件
    SubtitleRow(
        text: viewModel.currentSubtitle?.originalText ?? "",
        isActive: viewModel.currentSubtitle != nil,
        language: .original,
        placeholder: "原文字幕"
    )
    .frame(height: 60)
}
```

## 技术细节

### 1. 词的高亮判断

```swift
let isActive = currentTime >= word.startTime && currentTime <= word.endTime
```

- 当前播放时间在词的时间范围内，则高亮该词
- 每个词都有独立的 `startTime` 和 `endTime`

### 2. 自动滚动

```swift
.onChange(of: isActive) { newValue in
    if newValue {
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(index, anchor: .center)
        }
    }
}
```

- 使用 `ScrollViewReader` 实现自动滚动
- 当词变为高亮状态时，滚动到该词的位置
- 使用 `.center` 锚点，保持当前词在中心
- 添加 0.3 秒的缓动动画

### 3. 视觉样式

```swift
.font(.subheadline)                                    // 字体大小
.fontWeight(isActive ? .bold : .regular)               // 高亮时加粗
.foregroundColor(isActive ? .yellow : .white)          // 高亮时黄色
.background(isActive ? Color.yellow.opacity(0.2) : .clear)  // 高亮时背景
.cornerRadius(4)                                       // 圆角
```

### 4. 性能优化

- 使用 `ForEach` 的 `id: \.offset` 避免重复渲染
- 只在 `isActive` 变化时触发滚动
- 使用 `onChange` 而不是持续监听

## 数据流

```
ASR JSON 文件
  ↓
解析 ResultDetail
  ↓
提取 Words 数组
  ↓
创建 WordTiming 对象
  ↓
存储在 SubtitleItem.words
  ↓
传递给 WordHighlightSubtitleView
  ↓
根据 currentTime 高亮显示
```

## 示例数据

### Words 数组结构

```swift
[
    WordTiming(word: "在我", startTime: 0.19, endTime: 0.60),
    WordTiming(word: "身后", startTime: 0.60, endTime: 0.93),
    WordTiming(word: "的", startTime: 0.93, endTime: 1.095),
    WordTiming(word: "就是", startTime: 1.095, endTime: 1.38),
    // ... 更多词
]
```

### 播放时间与高亮

| 播放时间 | 高亮的词 | 说明 |
|---------|---------|------|
| 0.3s    | "在我"  | 0.19 ≤ 0.3 ≤ 0.60 |
| 0.7s    | "身后"  | 0.60 ≤ 0.7 ≤ 0.93 |
| 1.0s    | "的"    | 0.93 ≤ 1.0 ≤ 1.095 |
| 1.2s    | "就是"  | 1.095 ≤ 1.2 ≤ 1.38 |

## 兼容性处理

### 有 Words 数组

```swift
if let words = subtitle.words {
    // 使用词高亮组件
    WordHighlightSubtitleView(words: words, currentTime: currentTime)
}
```

### 没有 Words 数组

```swift
else {
    // 使用普通字幕组件
    SubtitleRow(text: subtitle.originalText, ...)
}
```

**适用场景：**
- 旧的识别结果（没有 Words 数组）
- 手动添加的字幕
- 识别失败的情况

## 用户体验

### 优点

1. **精确同步**：词级别的时间精度，同步更准确
2. **易于跟读**：高亮显示帮助用户跟随语音
3. **学习辅助**：适合语言学习场景
4. **视觉反馈**：清晰的视觉提示，增强沉浸感

### 改进空间

1. **多行显示**：长句子可以换行显示
2. **字体大小**：可以根据设备调整字体
3. **颜色主题**：支持自定义高亮颜色
4. **速度控制**：支持调整播放速度

## 测试建议

### 1. 基本功能测试

- [ ] 词能正确高亮
- [ ] 高亮随播放时间变化
- [ ] 自动滚动到当前词
- [ ] 动画流畅

### 2. 边界情况测试

- [ ] 没有 Words 数组时的降级显示
- [ ] 只有一个词的情况
- [ ] 词之间有间隔的情况
- [ ] 快进/快退时的表现

### 3. 性能测试

- [ ] 长句子（100+ 词）的性能
- [ ] 快速切换字幕时的性能
- [ ] 内存占用是否正常

## 调试技巧

### 1. 查看当前高亮的词

```swift
// 在 WordHighlightSubtitleView 中添加
.onChange(of: isActive) { newValue in
    if newValue {
        print("🎯 高亮词: \(word.word), 时间: \(word.startTime)-\(word.endTime)")
    }
}
```

### 2. 查看 Words 数组

```swift
// 在 loadSubtitles() 中添加
print("📝 字幕 \(index): \(subtitle.originalText)")
print("   词数: \(subtitle.words?.count ?? 0)")
```

### 3. 查看播放时间

```swift
// 在 updateCurrentSubtitle() 中添加
print("⏱️ 当前时间: \(String(format: "%.2f", time))s")
```

## 文件清单

### 修改的文件

- `Perapera/Models/SubtitleModel.swift` - 修改字幕加载逻辑
- `Perapera/Views/VideoPlayerView/VideoPlayerView.swift` - 添加词高亮组件

### 新增组件

- `WordHighlightSubtitleView` - 词级别高亮字幕视图

## 效果预览

```
播放时间: 0.3s
┌─────────────────────────────────────────────┐
│  在我 身后 的 就是 特斯拉 应对 国产 电车...  │
│  ^^^^                                        │
└─────────────────────────────────────────────┘

播放时间: 0.7s
┌─────────────────────────────────────────────┐
│  在我 身后 的 就是 特斯拉 应对 国产 电车...  │
│      ^^^^                                    │
└─────────────────────────────────────────────┘

播放时间: 1.2s
┌─────────────────────────────────────────────┐
│  在我 身后 的 就是 特斯拉 应对 国产 电车...  │
│              ^^^^                            │
└─────────────────────────────────────────────┘
```

## 总结

通过词级别的高亮显示，用户可以清楚地看到当前正在说的词，配合自动滚动功能，提供了类似卡拉 OK 的沉浸式体验。这对于语言学习、跟读练习等场景特别有用。
