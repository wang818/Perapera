# 腾讯云 COS 上传功能配置指南

## 概述
本项目已集成腾讯云对象存储（COS）SDK，用于上传用户选择的音频文件（包括 opus 格式）到云端。

## 安装步骤

### 1. 安装依赖
在项目根目录运行以下命令安装 CocoaPods 依赖：

```bash
pod install
```

### 2. 配置 COS 凭证

打开 `Perapera/Services/COSConfig.swift` 文件，替换以下配置信息：

```swift
/// 腾讯云 SecretId
static let secretId = "YOUR_SECRET_ID"  // 替换为你的 SecretId

/// 腾讯云 SecretKey
static let secretKey = "YOUR_SECRET_KEY"  // 替换为你的 SecretKey

/// COS 存储桶名称
static let bucket = "YOUR_BUCKET_NAME"  // 替换为你的存储桶名称（格式：bucket-appid）

/// COS 地域
static let region = "ap-guangzhou"  // 替换为你的存储桶所在地域
```

### 3. 获取腾讯云凭证

1. 登录 [腾讯云控制台](https://console.cloud.tencent.com/)
2. 进入 **访问管理** > **API密钥管理**
3. 创建或查看你的 SecretId 和 SecretKey
4. 进入 **对象存储** > **存储桶列表**
5. 创建存储桶或使用现有存储桶，记录存储桶名称和地域

### 4. 配置存储桶权限

确保你的 COS 存储桶已配置适当的访问权限：

1. 在腾讯云控制台进入你的存储桶
2. 点击 **权限管理** > **存储桶访问权限**
3. 根据需求配置公有读私有写或其他权限策略

## 使用说明

### 上传单个文件

用户在 HomeView 中选择文件后，系统会自动上传到 COS：

```swift
COSUploadManager.shared.uploadFile(
    fileURL: url,
    progress: { progress in
        print("上传进度: \(Int(progress * 100))%")
    },
    completion: { result in
        switch result {
        case .success(let cosURL):
            print("文件上传成功: \(cosURL)")
        case .failure(let error):
            print("上传失败: \(error)")
        }
    }
)
```

### 上传多个文件

```swift
COSUploadManager.shared.uploadFiles(
    fileURLs: [url1, url2, url3],
    progress: { progress in
        print("总体进度: \(Int(progress * 100))%")
    },
    completion: { result in
        switch result {
        case .success(let urls):
            print("所有文件上传成功: \(urls)")
        case .failure(let error):
            print("上传失败: \(error)")
        }
    }
)
```

## 文件命名规则

上传的文件会自动重命名，格式为：
```
audio/原文件名_时间戳_UUID.扩展名
```

例如：`audio/recording_1704700800_a1b2c3d4.opus`

## 支持的文件格式

- 音频文件：`.audio` 类型（mp3, m4a, wav, aac 等）
- 视频文件：`.movie` 类型（mp4, mov 等）
- Opus 文件：`.opus` 格式

## 注意事项

### 安全性
- **不要将 SecretId 和 SecretKey 提交到版本控制系统**
- 建议使用环境变量或配置文件管理敏感信息
- 生产环境建议使用临时密钥（STS）而非永久密钥

### 最佳实践
1. 在 `.gitignore` 中添加配置文件（如果使用独立配置文件）
2. 使用 CAM（访问管理）创建具有最小权限的子账号
3. 定期轮换 API 密钥
4. 监控 COS 使用量和费用

## 文件结构

```
Perapera/
├── Services/
│   ├── COSConfig.swift          # COS 配置文件
│   └── COSUploadManager.swift   # COS 上传管理器
├── Views/
│   └── HomeView/
│       └── HomeView.swift       # 集成了文件选择和上传功能
└── Podfile                      # 添加了 QCloudCOSXML 依赖
```

## 故障排除

### 上传失败
1. 检查 SecretId 和 SecretKey 是否正确
2. 确认存储桶名称和地域配置正确
3. 检查网络连接
4. 查看控制台日志获取详细错误信息

### 权限错误
1. 确认 API 密钥有 COS 写入权限
2. 检查存储桶访问策略配置

### 文件访问失败
1. 确认文件 URL 的安全作用域访问权限
2. 检查文件是否存在且可读

## 相关文档

- [腾讯云 COS iOS SDK 文档](https://cloud.tencent.com/document/product/436/11280)
- [腾讯云 COS 控制台](https://console.cloud.tencent.com/cos)
- [API 密钥管理](https://console.cloud.tencent.com/cam/capi)
