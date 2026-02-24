# 配置文件说明

## 📁 配置文件结构

项目中有两套配置文件，分别用于不同的服务：

### 1. COS（对象存储）配置

```
Perapera/Services/
├── COSConfig.swift        # COS 配置（公共配置）
└── COSConfig.local.swift  # COS 本地配置（包含密钥）
```

**用途**：
- 上传音频文件到腾讯云 COS
- 生成文件访问 URL

**配置内容**：
- SecretId
- SecretKey
- Bucket 名称
- 地域信息

### 2. 混元（大模型）配置

```
Perapera/Services/
├── HunyuanConfig.swift        # 混元配置（公共配置）
└── HunyuanConfig.local.swift  # 混元本地配置（包含密钥）
```

**用途**：
- 调用混元大模型 API
- 翻译文本

**配置内容**：
- SecretId
- SecretKey
- API 端点
- 模型参数

**认证方式**：
- 使用腾讯云 API v3 签名认证（与 COS、ASR 相同）
- TC3-HMAC-SHA256 签名算法

## 🔧 配置方法

### COSConfig.local.swift

```swift
//
//  COSConfig.local.swift
//  Perapera
//
//  本地配置文件 - 不要提交到 Git
//

import Foundation

// 设置本地开发环境的凭证
extension COSConfig {
    static func setupLocalCredentials() {
        print("🔧 开始设置本地凭证...")
        _localSecretId = "YOUR_SECRET_ID"      // ← 填入你的 SecretId
        _localSecretKey = "YOUR_SECRET_KEY"    // ← 填入你的 SecretKey
        print("✅ 本地凭证设置完成")
        print("   SecretId: \(_localSecretId.prefix(10))...")
        print("   SecretKey: \(_localSecretKey.prefix(10))...")
    }
}

// 自动初始化
private class LocalConfigInitializer {
    static let shared = LocalConfigInitializer()
    private init() {
        print("🚀 LocalConfigInitializer 初始化...")
        COSConfig.setupLocalCredentials()
    }
}

private let _initLocalConfig = LocalConfigInitializer.shared
```

### HunyuanConfig.local.swift

```swift
//
//  HunyuanConfig.local.swift
//  Perapera
//
//  本地配置文件 - 不要提交到 Git
//

import Foundation

// 设置混元 SecretId 和 SecretKey
extension HunyuanConfig {
    static func setupLocalCredentials() {
        print("🔧 开始设置混元本地凭证...")
        // TODO: 请在这里填入你的腾讯云 SecretId 和 SecretKey
        // 获取方式：https://console.cloud.tencent.com/cam/capi
        _localSecretId = "YOUR_SECRET_ID_HERE"      // ← 填入你的 SecretId
        _localSecretKey = "YOUR_SECRET_KEY_HERE"    // ← 填入你的 SecretKey
        print("✅ 混元本地凭证设置完成")
        print("   SecretId: \(_localSecretId.prefix(10))...")
        print("   SecretKey: \(_localSecretKey.prefix(10))...")
    }
}

// 自动初始化
private class HunyuanLocalConfigInitializer {
    static let shared = HunyuanLocalConfigInitializer()
    private init() {
        print("🚀 HunyuanLocalConfigInitializer 初始化...")
        HunyuanConfig.setupLocalCredentials()
    }
}

private let _initHunyuanLocalConfig = HunyuanLocalConfigInitializer.shared
```

## 🔐 安全性

### .gitignore 配置

确保以下文件已添加到 `.gitignore`：

```gitignore
# Local configuration files with credentials
Perapera/Services/COSConfig.local.swift
Perapera/Services/HunyuanConfig.local.swift
```

### 为什么要分离配置文件？

1. **安全性**：敏感信息（密钥、API Key）不会被提交到代码仓库
2. **灵活性**：每个开发者可以使用自己的凭证
3. **职责分离**：公共配置和私有配置分开管理
4. **团队协作**：团队成员可以使用不同的测试账号

## 🚀 自动初始化机制

两个配置文件都使用了自动初始化机制：

```swift
private class LocalConfigInitializer {
    static let shared = LocalConfigInitializer()
    private init() {
        // 在类初始化时自动调用配置方法
        COSConfig.setupLocalCredentials()
    }
}

// 创建静态实例，触发初始化
private let _initLocalConfig = LocalConfigInitializer.shared
```

**工作原理**：
1. Swift 在加载类时会创建静态实例
2. 创建实例时会调用 `init()` 方法
3. `init()` 方法中调用配置方法
4. 配置在应用启动时自动完成

**优点**：
- 无需手动调用配置方法
- 确保配置在使用前已完成
- 代码简洁，使用方便

## 📝 配置优先级

两个配置文件都支持多种配置方式，优先级如下：

### Debug 模式
1. 本地配置文件（`_localSecretId`、`_localAPIKey`）
2. 环境变量（`COS_SECRET_ID`、`HUNYUAN_API_KEY`）

### Release 模式
1. 环境变量（`COS_SECRET_ID`、`HUNYUAN_API_KEY`）

**示例代码**（HunyuanConfig.swift）：

```swift
static var secretId: String {
    #if DEBUG
    let id = _localSecretId.isEmpty ? 
        (ProcessInfo.processInfo.environment["HUNYUAN_SECRET_ID"] ?? "") : 
        _localSecretId
    if id.isEmpty {
        print("⚠️ HunyuanConfig.secretId 为空!")
    }
    return id
    #else
    return ProcessInfo.processInfo.environment["HUNYUAN_SECRET_ID"] ?? ""
    #endif
}
```

## 🔍 调试配置

### 查看配置是否加载成功

运行应用后，在 Xcode 控制台查看：

```
🚀 LocalConfigInitializer 初始化...
🔧 开始设置本地凭证...
✅ 本地凭证设置完成
   SecretId: AKIDthMqQx...
   SecretKey: 5A6qRpCON9...

🚀 HunyuanLocalConfigInitializer 初始化...
🔧 开始设置混元本地凭证...
✅ 混元本地凭证设置完成
   SecretId: AKIDxxxxxx...
   SecretKey: xxxxxxxxxx...
```

### 常见问题

**问题 1：配置未加载**
- 检查文件是否已添加到 Xcode 项目
- 确认文件在 Build Phases > Compile Sources 中

**问题 2：配置为空**
- 检查是否正确填写了密钥
- 确认没有多余的空格或引号
- 查看控制台的警告信息

**问题 3：配置冲突**
- 确保只在一个地方配置（本地文件或环境变量）
- 优先使用本地文件配置（开发环境）

## 📚 相关文档

- [快速开始指南](QUICK_START.md)
- [混元配置说明](HUNYUAN_SETUP_README.md)
- [COS 配置说明](COS_SETUP_README.md)

## 💡 最佳实践

1. **开发环境**：使用本地配置文件
2. **生产环境**：使用环境变量
3. **团队协作**：提供配置模板文件
4. **安全审查**：定期检查 .gitignore 配置
5. **密钥轮换**：定期更新 API 密钥
