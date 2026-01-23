# 视频列表本地存储功能说明

## 功能概述

实现了视频列表的本地存储功能，支持：
- ✅ YouTube 视频链接保存
- ✅ 本地文件导入
- ✅ 相册视频选择
- ✅ 视频缩略图生成
- ✅ 数据持久化（UserDefaults）
- ✅ 滑动删除功能

## 核心组件

### 1. VideoItem 模型
```swift
struct VideoItem: Codable, Identifiable {
    let id: String              // UUID 唯一标识
    let name: String            // 视频名称
    let posterImageData: Data?  // 海报图片数据
    let videoURL: String        // 视频地址
    let createdAt: Date         // 创建时间
}
```

### 2. VideoStorageManager 存储管理器

**主要方法：**
- `saveVideos(_:)` - 保存视频列表
- `loadVideos()` - 读取视频列表
- `addVideo(name:posterImage:videoURL:)` - 添加单个视频
- `deleteVideo(id:)` - 删除视频
- `updateVideo(id:name:posterImage:videoURL:)` - 更新视频
- `clearAllVideos()` - 清空所有视频

**特性：**
- 自动压缩图片（最大 300px，JPEG 质量 0.7）
- 使用 UserDefaults 存储
- 线程安全的单例模式

## 使用方法

### 添加视频

```swift
// 方式1: 直接添加
VideoStorageManager.shared.addVideo(
    name: "我的视频",
    posterImage: UIImage(named: "poster"),
    videoURL: "https://example.com/video.mp4"
)

// 方式2: YouTube 链接
VideoStorageManager.shared.addVideo(
    name: "YouTube - dQw4w9WgXcQ",
    posterImage: UIImage(systemName: "video.fill"),
    videoURL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
)
```

### 读取视频列表

```swift
let videos = VideoStorageManager.shared.loadVideos()
print("共有 \(videos.count) 个视频")
```

### 删除视频

```swift
VideoStorageManager.shared.deleteVideo(id: "video-uuid")
```

### 更新视频

```swift
VideoStorageManager.shared.updateVideo(
    id: "video-uuid",
    name: "新名称",
    posterImage: newImage,
    videoURL: "new-url"
)
```

## UI 界面

### HomeView 功能
1. **空状态显示** - 无视频时显示提示
2. **视频列表** - 显示所有已保存的视频
3. **添加视频** - 支持三种方式：
   - YouTube 链接输入
   - 本地文件选择
   - 相册视频选择
4. **滑动删除** - 左滑删除视频

### VideoRowView 视频行
- 显示视频缩略图（120x80）
- 显示视频名称（最多2行）
- 显示创建时间
- 显示视频来源标签（YouTube/本地）
- 支持滑动删除

## 数据存储

### 存储位置
- **UserDefaults** - 键名: `saved_video_list`
- 适合中小型数据（建议 < 100 个视频）

### 数据格式
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "我的视频",
    "posterImageData": "<base64-encoded-image>",
    "videoURL": "https://example.com/video.mp4",
    "createdAt": "2026-01-23T10:30:00Z"
  }
]
```

## 性能优化

1. **图片压缩**
   - 自动调整尺寸到 300px
   - JPEG 压缩质量 0.7
   - 减少存储空间占用

2. **懒加载**
   - 视频列表按需加载
   - 缩略图按需解码

3. **内存管理**
   - 使用 Data 存储图片
   - 避免大量 UIImage 常驻内存

## 注意事项

1. **存储限制**
   - UserDefaults 建议存储 < 1MB 数据
   - 如果视频很多，考虑迁移到 FileManager

2. **视频路径**
   - 本地视频使用绝对路径
   - 远程视频使用完整 URL

3. **缩略图生成**
   - 仅对本地视频生成缩略图
   - YouTube 视频使用默认图标

4. **数据迁移**
   - 如需更换存储方案，保持 VideoItem 模型不变
   - 只需修改 VideoStorageManager 实现

## 扩展建议

### 如果视频数量增多，可以迁移到 FileManager：

```swift
// 保存到 Documents 目录
func saveVideosToFile(_ videos: [VideoItem]) {
    let url = getDocumentsDirectory()
        .appendingPathComponent("videos.json")
    
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    
    if let data = try? encoder.encode(videos) {
        try? data.write(to: url)
    }
}

// 从文件读取
func loadVideosFromFile() -> [VideoItem] {
    let url = getDocumentsDirectory()
        .appendingPathComponent("videos.json")
    
    guard let data = try? Data(contentsOf: url) else {
        return []
    }
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    
    return (try? decoder.decode([VideoItem].self, from: data)) ?? []
}
```

## 测试建议

1. 添加不同类型的视频（YouTube、本地、相册）
2. 测试删除功能
3. 测试应用重启后数据是否保留
4. 测试大量视频时的性能
5. 测试图片压缩效果

## 完成 ✅

视频列表本地存储功能已完整实现，可以开始使用！
