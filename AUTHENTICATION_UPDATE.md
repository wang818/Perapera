# 混元认证方式更新说明

## 📋 更新概述

混元 API 的认证方式已从 **API Key** 更新为 **SecretId/SecretKey**，与腾讯云其他服务（COS、ASR）保持一致。

## 🔄 变更内容

### 1. 认证方式变更

#### 之前（API Key）
```swift
// 使用 OpenAI 兼容接口
static var apiKey: String { ... }
static let baseURL = "https://api.hunyuan.cloud.tencent.com/v1"
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
```

#### 现在（SecretId/SecretKey）
```swift
// 使用腾讯云 API v3 签名认证
static var secretId: String { ... }
static var secretKey: String { ... }
static let apiHost = "hunyuan.tencentcloudapi.com"

// 生成 TC3-HMAC-SHA256 签名
let signature = generateSignature(...)
request.setValue(signature, forHTTPHeaderField: "Authorization")
```

### 2. 更新的文件

#### 代码文件
- ✅ `Perapera/Services/HunyuanConfig.swift`
  - 将 `_localAPIKey` 改为 `_localSecretId` 和 `_localSecretKey`
  - 更新 API 域名为 `hunyuan.tencentcloudapi.com`
  - 添加 API 版本和服务名称配置

- ✅ `Perapera/Services/HunyuanConfig.local.swift`
  - 更新配置方法，使用 SecretId 和 SecretKey
  - 添加获取密钥的链接说明

- ✅ `Perapera/Services/HunyuanManager.swift`
  - 更新响应模型以匹配腾讯云 API 格式
  - 实现 TC3-HMAC-SHA256 签名算法
  - 添加签名生成相关方法（参考 ASRManager）
  - 更新请求头部字段

#### 文档文件
- ✅ `QUICK_START.md` - 更新快速开始指南
- ✅ `HUNYUAN_SETUP_README.md` - 更新详细配置说明
- ✅ `CONFIG_FILES_GUIDE.md` - 更新配置文件指南
- ✅ `FINAL_SETUP_SUMMARY.md` - 更新最终配置总结

## 🔐 认证方式对比

### API Key 方式（旧）
- **优点**：简单易用，类似 OpenAI API
- **缺点**：不是腾讯云标准认证方式
- **适用场景**：OpenAI 兼容接口

### SecretId/SecretKey 方式（新）
- **优点**：
  - 腾讯云标准认证方式
  - 与 COS、ASR 等服务一致
  - 更安全的签名机制
  - 支持更多高级功能
- **适用场景**：腾讯云原生 API

## 📝 配置步骤

### 1. 获取密钥

访问 https://console.cloud.tencent.com/cam/capi 获取：
- **SecretId**：类似 `AKIDxxxxxxxxxxxxxx`
- **SecretKey**：类似 `xxxxxxxxxxxxxxxx`

### 2. 配置文件

编辑 `Perapera/Services/HunyuanConfig.local.swift`：

```swift
extension HunyuanConfig {
    static func setupLocalCredentials() {
        print("🔧 开始设置混元本地凭证...")
        _localSecretId = "YOUR_SECRET_ID_HERE"      // ← 填入你的 SecretId
        _localSecretKey = "YOUR_SECRET_KEY_HERE"    // ← 填入你的 SecretKey
        print("✅ 混元本地凭证设置完成")
        print("   SecretId: \(_localSecretId.prefix(10))...")
        print("   SecretKey: \(_localSecretKey.prefix(10))...")
    }
}
```

### 3. 开通服务

访问 https://console.cloud.tencent.com/hunyuan 开通混元服务

## 🔧 技术实现

### 签名算法（TC3-HMAC-SHA256）

```swift
// 1. 拼接规范请求串
let canonicalRequest = "\(httpMethod)\n\(uri)\n\(queryString)\n\(headers)\n\(signedHeaders)\n\(hashedPayload)"

// 2. 拼接待签名字符串
let stringToSign = "\(algorithm)\n\(timestamp)\n\(credentialScope)\n\(hashedCanonicalRequest)"

// 3. 计算签名
let secretDate = hmacSHA256(key: "TC3\(secretKey)", data: date)
let secretService = hmacSHA256(key: secretDate, data: service)
let secretSigning = hmacSHA256(key: secretService, data: "tc3_request")
let signature = hmacSHA256Hex(key: secretSigning, data: stringToSign)

// 4. 拼接 Authorization
return "\(algorithm) Credential=\(secretId)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
```

### 请求头部

```swift
request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
request.setValue("2023-09-01", forHTTPHeaderField: "X-TC-Version")
request.setValue("ChatCompletions", forHTTPHeaderField: "X-TC-Action")
request.setValue("\(timestamp)", forHTTPHeaderField: "X-TC-Timestamp")
request.setValue(signature, forHTTPHeaderField: "Authorization")
```

### 响应格式

```json
{
  "Response": {
    "RequestId": "xxx",
    "Choices": [
      {
        "Message": {
          "Role": "assistant",
          "Content": "{\"JaJPWords\": [...]}"
        },
        "FinishReason": "stop"
      }
    ],
    "Usage": {
      "PromptTokens": 100,
      "CompletionTokens": 50,
      "TotalTokens": 150
    }
  }
}
```

## ✅ 验证更新

### 控制台输出

更新后，控制台应显示：

```
🚀 HunyuanLocalConfigInitializer 初始化...
🔧 开始设置混元本地凭证...
✅ 混元本地凭证设置完成
   SecretId: AKIDxxxxxx...
   SecretKey: xxxxxxxxxx...

🚀 发送翻译请求到混元 API...
📤 请求体: {"Model":"hunyuan-turbo","Messages":[...]}
📥 API 响应: {"Response":{"RequestId":"xxx","Choices":[...]}}
✅ 翻译成功，共 150 个日文单词
```

### 常见错误

#### 1. 签名错误
```
API 错误: AuthFailure.SignatureFailure
```
**解决方案**：
- 检查 SecretId 和 SecretKey 是否正确
- 确认系统时间是否准确

#### 2. 鉴权失败
```
API 错误: AuthFailure.SecretIdNotFound
```
**解决方案**：
- 确认 SecretId 是否有效
- 检查密钥是否被禁用

#### 3. 服务未开通
```
API 错误: FailedOperation.ServiceNotActivated
```
**解决方案**：
- 访问混元控制台开通服务

## 📚 参考文档

- [腾讯云 API 签名方法 v3](https://cloud.tencent.com/document/api/1729/101843)
- [混元 API 文档](https://cloud.tencent.com/document/product/1729/101848)
- [混元 ChatCompletions 接口](https://cloud.tencent.com/document/product/1729/105701)
- [腾讯云 CAM 密钥管理](https://console.cloud.tencent.com/cam/capi)

## 🎯 迁移检查清单

如果你之前使用 API Key 方式，请按以下步骤迁移：

- [ ] 获取腾讯云 SecretId 和 SecretKey
- [ ] 更新 HunyuanConfig.local.swift 配置
- [ ] 开通混元服务
- [ ] 清理并重新构建项目（⌘⇧K + ⌘B）
- [ ] 运行应用并测试翻译功能
- [ ] 检查控制台输出是否正常
- [ ] 验证翻译结果是否正确

## 💡 优势总结

1. **统一认证**：与 COS、ASR 使用相同的认证方式
2. **更安全**：使用签名算法，密钥不会在网络传输
3. **标准化**：符合腾讯云 API 规范
4. **易维护**：代码结构与其他服务一致
5. **功能完整**：支持腾讯云所有高级功能

## 🎉 完成

现在混元 API 已使用标准的腾讯云认证方式，与项目中的其他腾讯云服务保持一致！
