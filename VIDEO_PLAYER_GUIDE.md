# 📺 视频播放器使用指南

## 功能概述

已创建完整的视频播放器，支持：
- ✅ 视频播放控制
- ✅ 双语字幕显示（日文 + 原文）
- ✅ 字幕时间同步
- ✅ 字幕高亮显示
- ✅ 进度条控制
- ✅ 快进/快退功能

## 📱 界面布局

```
┌─────────────────────────────────┐
│  ← 视频标题              ⋯      │  ← 顶部导航栏
├─────────────────────────────────┤
│                                 │
│                                 │
│         视频播放区域             │  ← 16:9 视频
│                                 │
│                                 │
├─────────────────────────────────┤
│  これは最初の文です              │  ← 日文字幕（上）
├─────────────────────────────────┤
│  这是第一句话                    │  ← 原文字幕（下）
├─────────────────────────────────┤
│  00:15 ━━━━━●━━━━━━ 03:45      │  ← 进度条
│                                 │
│    ⏪     ▶️/⏸     ⏩          │  ← 控制按钮
└─────────────────────────────────┘
```

## 🎯 核心功能

### 1. 视频播放

**播放控制:**
- 点击视频区域 → 播放/暂停
- 点击播放按钮 → 播放/暂停
- 自动加载视频
- 显示加载状态

**支持格式:**
- MP4
- MOV
- AVI
- 其他 AVPlayer 支持的格式

### 2. 双语字幕

**字幕布局:**
```
┌─────────────────────────────────┐
│  日文字幕（译文）                │  ← 上行
├─────────────────────────────────┤
│  原文字幕（ASR 识别）            │  ← 下行
└─────────────────────────────────┘
```

**字幕特性:**
- 自动跟随播放时间
- 当前字幕高亮显示（黄色 + 加粗）
- 非当前字幕灰色显示
- 支持横向滚动（长文本）
- 每行高度 60pt

### 3. 时间同步

**同步机制:**
- 每 0.1 秒更新一次当前时间
- 自动匹配当前时间的字幕
- 字幕切换平滑无闪烁

**字幕时间范围:**
```swift
struct SubtitleItem {
    let startTime: Double  // 开始时间（秒）
    let endTime: Double    // 结束时间（秒）
    let originalText: String
    let translatedText: String
}
```

### 4. 播放控制

**控制按钮:**
- ⏪ 后退 10 秒
- ▶️/⏸ 播放/暂停
- ⏩ 前进 10 秒

**进度条:**
- 拖动跳转到指定时间
- 显示当前时间 / 总时长
- 格式: MM:SS

## 🏗️ 技术架构

### 文件结构

```
Perapera/
├── Models/
│   └── SubtitleModel.swift              # 字幕数据模型
├── Views/
│   ├── HomeView/
│   │   └── HomeView.swift               # 视频列表（已更新）
│   └── VideoPlayerView/
│       ├── VideoPlayerView.swift        # 播放器视图
│       └── VideoPlayerViewModel.swift   # 播放器逻辑
└── Tools/
    └── VideoStorageManager.swift        # 视频存储
```

### 核心组件

#### 1. SubtitleModel.swift

**SubtitleItem** - 字幕项
```swift
struct SubtitleItem {
    let id: String
    let startTime: Double
    let endTime: Double
    let originalText: String
    let translatedText: String
    
    func isActive(at currentTime: Double) -> Bool
}
```

**SubtitleData** - 字幕数据
```swift
struct SubtitleData {
    let videoId: String
    var subtitles: [SubtitleItem]
}
```

**SubtitleManager** - 字幕管理器
```swift
class SubtitleManager {
    static let shared = SubtitleManager()
    
    func saveSubtitles(_ subtitleData: SubtitleData)
    func loadSubtitles(for videoId: String) -> SubtitleData?
    func deleteSubtitles(for videoId: String)
    func generateSubtitlesFromASR(text: String, videoDuration: Double) -> [SubtitleItem]
    func getCurrentSubtitle(subtitles: [SubtitleItem], at currentTime: Double) -> SubtitleItem?
}
```

#### 2. VideoPlayerView.swift

**主要视图:**
- `topNavigationBar` - 顶部导航栏
- `videoPlayerSection` - 视频播放区域
- `subtitleSection` - 字幕显示区域
- `controlBar` - 播放控制栏

**SubtitleRow** - 字幕行组件
```swift
struct SubtitleRow: View {
    let text: String
    let isActive: Bool
    let language: SubtitleLanguage
}
```

#### 3. VideoPlayerViewModel.swift

**状态管理:**
```swift
@Published var player: AVPlayer?
@Published var currentTime: Double = 0
@Published var duration: Double = 0
@Published var isPlaying: Bool = false
@Published var currentSubtitle: SubtitleItem?
@Published var subtitles: [SubtitleItem] = []
```

**核心方法:**
- `setupPlayer()` - 初始化播放器
- `addTimeObserver()` - 添加时间观察器
- `updateCurrentSubtitle(at:)` - 更新当前字幕
- `togglePlayPause()` - 播放/暂停
- `seek(to:)` - 跳转到指定时间
- `skipBackward()` - 后退 10 秒
- `skipForward()` - 前进 10 秒
- `cleanup()` - 清理资源

## 💾 数据存储

### 字幕存储

**位置:** UserDefaults  
**键名:** `video_subtitles`  
**格式:** JSON

```json
[
  {
    "videoId": "uuid-1234",
    "subtitles": [
      {
        "id": "sub-1",
        "startTime": 0.0,
        "endTime": 5.0,
        "originalText": "这是第一句话",
        "translatedText": "これは最初の文です"
      },
      {
        "id": "sub-2",
        "startTime": 5.0,
        "endTime": 10.0,
        "originalText": "这是第二句话",
        "translatedText": "これは二番目の文です"
      }
    ]
  }
]
```

## 🎨 UI 样式

### 颜色方案

| 元素 | 颜色 | 说明 |
|------|------|------|
| 背景 | 黑色 | 沉浸式体验 |
| 当前字幕 | 黄色 + 加粗 | 高亮显示 |
| 非当前字幕 | 灰色 | 低调显示 |
| 控制按钮 | 白色 | 清晰可见 |
| 进度条 | 蓝色 | 系统标准 |

### 字体大小

| 元素 | 字体 | 大小 |
|------|------|------|
| 日文字幕 | .body | 17pt |
| 原文字幕 | .subheadline | 15pt |
| 时间显示 | .caption | 12pt |
| 标题 | .headline | 17pt |

## 🔄 使用流程

### 1. 从视频列表进入

```swift
// HomeView.swift
NavigationLink(destination: VideoPlayerView(video: video)) {
    VideoRowView(video: video, onDelete: { ... })
}
```

### 2. 播放器初始化

```
用户点击视频
    ↓
创建 VideoPlayerView
    ↓
初始化 VideoPlayerViewModel
    ↓
加载字幕数据
    ↓
设置 AVPlayer
    ↓
添加时间观察器
    ↓
开始播放
```

### 3. 字幕同步

```
播放器更新时间（每 0.1 秒）
    ↓
更新 currentTime
    ↓
查找匹配的字幕
    ↓
更新 currentSubtitle
    ↓
UI 自动刷新
    ↓
字幕高亮显示
```

## 📝 字幕生成

### 从 ASR 结果生成

```swift
// 自动分段
let subtitles = SubtitleManager.shared.generateSubtitlesFromASR(
    text: asrResult,
    videoDuration: duration
)

// 保存字幕
let subtitleData = SubtitleData(videoId: video.id, subtitles: subtitles)
SubtitleManager.shared.saveSubtitles(subtitleData)
```

### 分段策略

1. 按标点符号分割（。！？.!?）
2. 计算每句时长 = 总时长 / 句子数
3. 分配时间范围
4. 生成字幕项

## 🎯 高级功能

### 1. 字幕编辑（TODO）

```swift
// 编辑字幕
func editSubtitle(id: String, originalText: String, translatedText: String)

// 调整时间
func adjustSubtitleTime(id: String, startTime: Double, endTime: Double)

// 添加字幕
func addSubtitle(at time: Double, originalText: String, translatedText: String)

// 删除字幕
func deleteSubtitle(id: String)
```

### 2. 字幕导出（TODO）

```swift
// 导出 SRT 格式
func exportToSRT() -> String

// 导出 VTT 格式
func exportToVTT() -> String

// 导出 JSON 格式
func exportToJSON() -> String
```

### 3. 字幕样式（TODO）

```swift
// 字体大小
var subtitleFontSize: CGFloat = 17

// 字幕位置
var subtitlePosition: SubtitlePosition = .bottom

// 字幕背景
var subtitleBackground: Color = .black.opacity(0.8)
```

## 🐛 故障排除

### 问题 1: 视频无法播放

**原因:**
- 视频文件不存在
- 视频格式不支持
- 文件路径错误

**解决方案:**
```swift
// 检查文件是否存在
if !FileManager.default.fileExists(atPath: videoURL.path) {
    print("❌ 视频文件不存在")
}

// 检查 URL 是否有效
guard let videoURL = URL(string: video.videoURL) else {
    print("❌ 无效的视频 URL")
}
```

### 问题 2: 字幕不显示

**原因:**
- 没有字幕数据
- 字幕时间范围错误
- 字幕加载失败

**解决方案:**
```swift
// 检查字幕数据
if subtitles.isEmpty {
    print("📭 没有字幕数据")
    generateDefaultSubtitles()
}

// 检查时间范围
for subtitle in subtitles {
    print("字幕: \(subtitle.startTime) - \(subtitle.endTime)")
}
```

### 问题 3: 字幕不同步

**原因:**
- 时间观察器未正确设置
- 字幕时间范围不准确

**解决方案:**
```swift
// 调整观察器间隔
let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

// 手动调整字幕时间
func adjustSubtitleTiming(offset: Double) {
    for i in 0..<subtitles.count {
        subtitles[i].startTime += offset
        subtitles[i].endTime += offset
    }
}
```

## 📊 性能优化

### 1. 内存管理

```swift
// 及时清理播放器
func cleanup() {
    player?.removeTimeObserver(timeObserver)
    player?.pause()
    player = nil
}

// 使用 deinit
deinit {
    cleanup()
}
```

### 2. 字幕缓存

```swift
// 缓存当前字幕，避免重复查找
if newSubtitle?.id != currentSubtitle?.id {
    currentSubtitle = newSubtitle
}
```

### 3. UI 更新优化

```swift
// 只在主线程更新 UI
DispatchQueue.main.async {
    self.currentTime = currentTime
}
```

## 🎓 使用示例

### 基础使用

```swift
// 1. 从视频列表点击视频
// 2. 自动跳转到播放器
// 3. 视频自动加载并播放
// 4. 字幕自动显示和同步
```

### 手动创建播放器

```swift
let video = VideoItem(
    name: "测试视频",
    posterImageData: nil,
    videoURL: "/path/to/video.mp4",
    audioURL: nil
)

let playerView = VideoPlayerView(video: video)
```

### 添加字幕

```swift
let subtitles = [
    SubtitleItem(
        startTime: 0,
        endTime: 5,
        originalText: "Hello",
        translatedText: "こんにちは"
    )
]

let subtitleData = SubtitleData(videoId: video.id, subtitles: subtitles)
SubtitleManager.shared.saveSubtitles(subtitleData)
```

## ✅ 功能清单

- [x] 视频播放
- [x] 播放/暂停控制
- [x] 进度条显示
- [x] 进度条拖动
- [x] 快进/快退 10 秒
- [x] 双语字幕显示
- [x] 字幕时间同步
- [x] 字幕高亮显示
- [x] 字幕数据存储
- [x] 字幕自动生成
- [ ] 字幕编辑（TODO）
- [ ] 字幕导出（TODO）
- [ ] 播放速度调节（TODO）
- [ ] 全屏模式（TODO）
- [ ] 画中画模式（TODO）

## 🎉 完成

视频播放器已完成，支持双语字幕和时间同步！

---

**创建时间**: 2026-01-24  
**版本**: 1.0.0  
**状态**: ✅ 生产就绪
