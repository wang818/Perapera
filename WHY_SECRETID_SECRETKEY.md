# 为什么混元使用 SecretId/SecretKey？

## ❓ 问题

用户提问："混元不是用 SecretId 和 SecretKey 吗？"

## ✅ 答案

**是的！** 混元 API 确实使用 **SecretId 和 SecretKey** 进行认证，而不是单独的 API Key。

## 🔍 背景说明

### 腾讯云服务的标准认证方式

腾讯云的所有服务（包括混元）都使用统一的认证方式：

1. **SecretId**：用于标识 API 调用者的身份
2. **SecretKey**：用于生成请求签名的密钥

### 项目中的其他服务

在这个项目中，其他腾讯云服务也使用相同的认证方式：

- **COS（对象存储）**：使用 SecretId/SecretKey
- **ASR（语音识别）**：使用 SecretId/SecretKey
- **混元（大模型）**：使用 SecretId/SecretKey ✅

## 🔄 之前的实现问题

### 错误的实现（已修正）

之前的实现使用了 OpenAI 兼容接口的方式：

```swift
// ❌ 错误：使用 API Key
static var apiKey: String { ... }
static let baseURL = "https://api.hunyuan.cloud.tencent.com/v1"
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
```

**问题**：
- 这是 OpenAI 兼容接口的认证方式
- 不是腾讯云的标准认证方式
- 与项目中其他服务不一致

### 正确的实现（已更新）

现在使用腾讯云标准认证方式：

```swift
// ✅ 正确：使用 SecretId/SecretKey
static var secretId: String { ... }
static var secretKey: String { ... }
static let apiHost = "hunyuan.tencentcloudapi.com"

// 生成 TC3-HMAC-SHA256 签名
let signature = generateSignature(...)
request.setValue(signature, forHTTPHeaderField: "Authorization")
```

**优点**：
- 符合腾讯云 API 规范
- 与 COS、ASR 等服务一致
- 使用更安全的签名机制
- 支持所有腾讯云功能

## 📊 认证方式对比

| 特性 | API Key 方式 | SecretId/SecretKey 方式 |
|------|-------------|------------------------|
| **接口类型** | OpenAI 兼容接口 | 腾讯云原生 API |
| **认证方式** | Bearer Token | TC3-HMAC-SHA256 签名 |
| **API 域名** | api.hunyuan.cloud.tencent.com | hunyuan.tencentcloudapi.com |
| **与其他服务一致性** | ❌ 不一致 | ✅ 一致 |
| **安全性** | 中等 | 高（签名机制） |
| **功能完整性** | 基础功能 | 完整功能 |
| **推荐使用** | ❌ 不推荐 | ✅ 推荐 |

## 🔐 腾讯云 API v3 签名认证

### 认证流程

```
1. 准备请求参数
   ↓
2. 拼接规范请求串（Canonical Request）
   ↓
3. 拼接待签名字符串（String to Sign）
   ↓
4. 计算签名（使用 HMAC-SHA256）
   ↓
5. 拼接 Authorization 头部
   ↓
6. 发送请求
```

### 签名算法

```swift
// 1. 规范请求串
let canonicalRequest = """
POST
/
content-type:application/json; charset=utf-8
host:hunyuan.tencentcloudapi.com

content-type;host
\(sha256(requestBody))
"""

// 2. 待签名字符串
let stringToSign = """
TC3-HMAC-SHA256
\(timestamp)
\(date)/hunyuan/tc3_request
\(sha256(canonicalRequest))
"""

// 3. 计算签名
let secretDate = hmacSHA256(key: "TC3\(secretKey)", data: date)
let secretService = hmacSHA256(key: secretDate, data: "hunyuan")
let secretSigning = hmacSHA256(key: secretService, data: "tc3_request")
let signature = hmacSHA256Hex(key: secretSigning, data: stringToSign)

// 4. Authorization 头部
Authorization: TC3-HMAC-SHA256 Credential=\(secretId)/\(date)/hunyuan/tc3_request, SignedHeaders=content-type;host, Signature=\(signature)
```

## 📝 如何获取 SecretId 和 SecretKey

### 步骤 1：访问 CAM 控制台

访问：https://console.cloud.tencent.com/cam/capi

### 步骤 2：创建或查看密钥

1. 点击"新建密钥"（如果还没有）
2. 系统会生成 SecretId 和 SecretKey
3. **重要**：SecretKey 只显示一次，请立即保存！

### 步骤 3：复制密钥

- **SecretId**：类似 `AKIDxxxxxxxxxxxxxx`（公开标识）
- **SecretKey**：类似 `xxxxxxxxxxxxxxxx`（私密密钥）

### 步骤 4：配置到项目

编辑 `Perapera/Services/HunyuanConfig.local.swift`：

```swift
_localSecretId = "AKIDxxxxxxxxxxxxxx"    // 你的 SecretId
_localSecretKey = "xxxxxxxxxxxxxxxx"     // 你的 SecretKey
```

## 🔒 安全最佳实践

### 1. 保护 SecretKey

- ❌ 不要提交到 Git 仓库
- ❌ 不要在代码中硬编码
- ❌ 不要分享给他人
- ✅ 使用本地配置文件（已添加到 .gitignore）
- ✅ 定期更换密钥

### 2. 使用子账号

建议创建子账号并授予最小权限：

1. 访问 [CAM 用户管理](https://console.cloud.tencent.com/cam)
2. 创建子用户
3. 只授予混元服务的权限
4. 使用子账号的 SecretId/SecretKey

### 3. 监控使用情况

定期检查：
- API 调用量
- 费用消耗
- 异常访问

## 🎯 项目中的统一认证

现在项目中所有腾讯云服务都使用相同的认证方式：

```
┌─────────────────────────────────────┐
│   腾讯云 SecretId/SecretKey         │
│   (从 CAM 控制台获取)                │
└─────────────────────────────────────┘
                 │
        ┌────────┼────────┐
        ↓        ↓        ↓
    ┌─────┐  ┌─────┐  ┌──────┐
    │ COS │  │ ASR │  │ 混元  │
    └─────┘  └─────┘  └──────┘
     对象存储  语音识别  大模型
```

**优势**：
- 统一的配置方式
- 统一的代码结构
- 统一的错误处理
- 易于维护和扩展

## 📚 参考文档

### 官方文档

- [腾讯云 API 签名方法 v3](https://cloud.tencent.com/document/api/1729/101843)
- [混元 API 文档](https://cloud.tencent.com/document/product/1729/101848)
- [混元 ChatCompletions 接口](https://cloud.tencent.com/document/product/1729/105701)
- [CAM 密钥管理](https://console.cloud.tencent.com/cam/capi)

### 项目文档

- [快速开始](QUICK_START.md)
- [认证更新说明](AUTHENTICATION_UPDATE.md)
- [配置文件指南](CONFIG_FILES_GUIDE.md)

## ✅ 总结

1. **混元确实使用 SecretId/SecretKey**，这是腾讯云的标准认证方式
2. **已更新所有相关代码和文档**，使用正确的认证方式
3. **与项目中其他服务保持一致**，便于维护
4. **更安全、更标准、更完整**的实现

现在你可以使用与 COS、ASR 相同的 SecretId/SecretKey 来调用混元 API 了！🎉
