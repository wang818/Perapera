# 混元大模型集成说明

## 功能说明

已成功集成腾讯混元大模型，实现以下功能：

1. **读取 123.json 文件**：从 Bundle 中读取语音识别结果的 JSON 文件
2. **提取 Words 数组**：解析 JSON 获取需要翻译的中文单词
3. **调用混元 API**：使用混元大模型将中文单词翻译成日文
4. **返回翻译结果**：将翻译后的日文单词数组（JaJPWords）添加到原 JSON 的同级位置

## 配置步骤

### 1. 获取腾讯云密钥

1. 访问 [腾讯云 API 密钥管理](https://console.cloud.tencent.com/cam/capi)
2. 登录你的腾讯云账号
3. 复制你的 **SecretId** 和 **SecretKey**

> ⚠️ **重要**：SecretKey 只在创建时显示一次，请妥善保管！

### 2. 开通混元服务

1. 访问 [腾讯云混元控制台](https://console.cloud.tencent.com/hunyuan)
2. 开通混元大模型服务
3. 确认服务状态为"已开通"

### 3. 配置密钥

打开 `Perapera/Services/HunyuanConfig.local.swift` 文件，找到以下代码：

```swift
extension HunyuanConfig {
    static func setupLocalCredentials() {
        print("🔧 开始设置混元本地凭证...")
        // TODO: 请在这里填入你的腾讯云 SecretId 和 SecretKey
        // 获取方式：https://console.cloud.tencent.com/cam/capi
        _localSecretId = "YOUR_SECRET_ID_HERE"
        _localSecretKey = "YOUR_SECRET_KEY_HERE"
        print("✅ 混元本地凭证设置完成")
        print("   SecretId: \(_localSecretId.prefix(10))...")
        print("   SecretKey: \(_localSecretKey.prefix(10))...")
    }
}
```

将 `YOUR_SECRET_ID_HERE` 和 `YOUR_SECRET_KEY_HERE` 替换为你的实际密钥。

### 3. 使用方法

1. 运行应用
2. 在 HomeView 页面，点击底部的"翻译"按钮
3. 应用会：
   - 读取 123.json 文件
   - 提取 Words 数组中的所有单词
   - 调用混元 API 进行翻译
   - 显示翻译结果（包含 JaJPWords 字段）

## 文件结构

```
Perapera/Services/
├── HunyuanConfig.swift        # 混元配置文件
├── HunyuanConfig.local.swift  # 混元本地配置（包含 API Key）
├── HunyuanManager.swift       # 混元管理器（核心逻辑）
├── COSConfig.swift            # COS 配置文件
└── COSConfig.local.swift      # COS 本地配置
```

## API 调用流程

1. **读取 JSON**
   ```
   123.json → 解析 → 提取 Words 数组
   ```

2. **调用混元 API**
   ```
   Words 数组 → 构建提示词 → POST /v1/chat/completions → 获取翻译结果
   ```

3. **处理响应**
   ```
   API 响应 → 提取 JaJPWords → 添加到原 JSON → 返回完整结果
   ```

## 示例

### 输入（123.json 中的 Words）
```json
{
  "Words": [
    {"Word": "在我"},
    {"Word": "身后"},
    {"Word": "的"}
  ]
}
```

### 输出（添加 JaJPWords）
```json
{
  "Words": [
    {"Word": "在我"},
    {"Word": "身后"},
    {"Word": "的"}
  ],
  "JaJPWords": ["私の", "後ろ", "の"]
}
```

## 注意事项

1. **API Key 安全**：不要将 `HunyuanConfig.local.swift` 提交到 Git（已添加到 .gitignore）
2. **网络请求**：确保设备有网络连接
3. **错误处理**：应用会显示详细的错误信息
4. **调试信息**：查看 Xcode 控制台可以看到详细的请求和响应日志

## 认证方式

混元 API 使用**腾讯云 API v3 签名认证**（与 COS、ASR 相同）：

- **认证方式**：TC3-HMAC-SHA256 签名算法
- **必需参数**：SecretId、SecretKey
- **签名位置**：HTTP Authorization 头部
- **时间戳**：X-TC-Timestamp 头部

## 混元 API 参数

- **模型**：hunyuan-turbo（默认）
- **温度**：0.3（较低温度以获得稳定翻译）
- **API 域名**：hunyuan.tencentcloudapi.com
- **API 版本**：2023-09-01
- **接口名称**：ChatCompletions

## 故障排查

### 问题：无法读取 123.json
- 确保文件已添加到 Xcode 项目的 Resources 中
- 检查文件名是否正确

### 问题：SecretId 或 SecretKey 为空
- 检查 HunyuanConfig.local.swift 中的密钥是否正确填写
- 确保没有多余的空格或引号
- 确认使用的是腾讯云 CAM 控制台的密钥

### 问题：API 调用失败
- 检查 SecretId 和 SecretKey 是否正确配置
- 确认混元服务是否已开通
- 确保网络连接正常
- 查看控制台错误信息（包含错误代码）

### 问题：签名错误或鉴权失败
- 确认 SecretId 和 SecretKey 是否匹配
- 检查系统时间是否正确（签名依赖时间戳）
- 确保密钥没有被禁用或过期

### 问题：翻译结果为空
- 检查 Words 数组是否为空
- 查看 API 响应格式是否正确
- 确认混元服务是否正常

## 参考文档

- [混元大模型 API 文档](https://cloud.tencent.com/document/product/1729/101848)
- [腾讯云 API 签名方法 v3](https://cloud.tencent.com/document/api/1729/101843)
- [混元 API 接口文档](https://cloud.tencent.com/document/product/1729/105701)
