# 快速开始 - 混元翻译功能

## 🚀 5 分钟快速配置

### 步骤 1: 获取腾讯云密钥

1. 访问 https://console.cloud.tencent.com/cam/capi
2. 登录你的腾讯云账号
3. 复制你的 **SecretId** 和 **SecretKey**

> ⚠️ **重要提示**：SecretKey 只在创建时显示一次，请妥善保管！

### 步骤 2: 开通混元服务

1. 访问 https://console.cloud.tencent.com/hunyuan
2. 开通混元大模型服务
3. 确认服务状态为"已开通"

### 步骤 3: 配置密钥

打开文件：`Perapera/Services/HunyuanConfig.local.swift`

找到这段代码：
```swift
extension HunyuanConfig {
    static func setupLocalCredentials() {
        print("🔧 开始设置混元本地凭证...")
        // TODO: 请在这里填入你的腾讯云 SecretId 和 SecretKey
        // 获取方式：https://console.cloud.tencent.com/cam/capi
        _localSecretId = "YOUR_SECRET_ID_HERE"      // ← 修改这里
        _localSecretKey = "YOUR_SECRET_KEY_HERE"    // ← 修改这里
        print("✅ 混元本地凭证设置完成")
        print("   SecretId: \(_localSecretId.prefix(10))...")
        print("   SecretKey: \(_localSecretKey.prefix(10))...")
    }
}
```

将 `YOUR_SECRET_ID_HERE` 和 `YOUR_SECRET_KEY_HERE` 替换为你的实际密钥。

### 步骤 4: 运行应用

1. 在 Xcode 中打开项目
2. 选择模拟器或真机
3. 点击运行按钮（⌘R）

### 步骤 5: 测试翻译

1. 应用启动后，进入 HomeView 页面
2. 点击底部的蓝色"翻译"按钮
3. 等待几秒钟（会显示"正在翻译..."）
4. 查看翻译结果弹窗

## ✅ 验证成功

如果看到以下内容，说明配置成功：

### Xcode 控制台输出
```
🔧 开始设置混元本地凭证...
✅ 混元本地凭证设置完成
   SecretId: AKIDxxxxxx...
   SecretKey: xxxxxxxxxx...

=== 开始翻译 123.json ===
📝 准备翻译 150 个单词到日文...
🚀 发送翻译请求到混元 API...
📥 API 响应: {...}
✅ 翻译成功，共 150 个日文单词

================================================================================
📋 翻译结果对照表
================================================================================
序号  中文                           日文                          
--------------------------------------------------------------------------------
1     在我                           私の                          
2     身后                           後ろ                          
...
================================================================================
✅ 总计: 150 个单词已翻译

=== 翻译后的 JSON ===
{
  "Response": {
    "Data": {
      "ResultDetail": [
        {
          "Words": [...],
          "JaJPWords": ["私の", "後ろ", ...]
        }
      ]
    }
  }
}
=== 结束 ===
```

### 应用界面
- 显示"正在翻译..."加载指示器
- 翻译完成后显示结果弹窗
- 可以复制翻译结果

## 🔍 查看翻译结果

翻译结果会以 JSON 格式显示，包含：
- 原始的 Words 数组（中文单词）
- 新增的 JaJPWords 数组（日文翻译）

示例：
```json
{
  "Words": [
    {"Word": "在我"},
    {"Word": "身后"}
  ],
  "JaJPWords": ["私の", "後ろ"]
}
```

## ❌ 常见问题

### 问题 1: 显示"无法读取 123.json 文件"
**解决方案**：
- 确保 123.json 已添加到 Xcode 项目
- 检查文件是否在 Perapera 文件夹中
- 重新构建项目（⌘⇧K 清理，然后 ⌘B 构建）

### 问题 2: 显示"SecretId 为空"或"SecretKey 为空"
**解决方案**：
- 检查 HunyuanConfig.local.swift 中的密钥是否正确填写
- 确保没有多余的空格或引号
- 确认使用的是腾讯云 CAM 控制台的密钥
- 重新运行应用

### 问题 3: 显示"API 错误"
**解决方案**：
- 检查网络连接
- 确认 SecretId 和 SecretKey 是否有效
- 确认混元服务是否已开通
- 查看控制台的详细错误信息（包含错误代码）
- 检查账号是否有足够的余额

### 问题 4: 显示"签名错误"或"鉴权失败"
**解决方案**：
- 确认 SecretId 和 SecretKey 是否匹配
- 检查系统时间是否正确（签名依赖时间戳）
- 确保密钥没有被禁用或过期

### 问题 5: 翻译结果为空
**解决方案**：
- 检查 123.json 中是否有 Words 数组
- 查看控制台的 API 响应
- 确认 API 返回格式是否正确

## 🔐 安全提示

1. **不要提交密钥到 Git**：HunyuanConfig.local.swift 已添加到 .gitignore
2. **定期更换密钥**：建议定期在腾讯云控制台更换密钥
3. **使用子账号**：建议创建子账号并授予最小权限
4. **监控使用情况**：定期检查 API 调用量和费用

## 📚 更多信息

- 详细配置说明：查看 `HUNYUAN_SETUP_README.md`
- 功能实现总结：查看 `TRANSLATION_FEATURE_SUMMARY.md`
- 配置文件说明：查看 `CONFIG_FILES_GUIDE.md`
- 混元 API 文档：https://cloud.tencent.com/document/product/1729/101848
- 腾讯云 API 签名文档：https://cloud.tencent.com/document/api/1729/101843

## 💡 提示

1. **首次使用**：建议先在控制台查看完整的日志输出
2. **调试模式**：所有请求和响应都会打印到控制台
3. **网络要求**：需要稳定的网络连接
4. **API 限制**：注意不要频繁调用，避免触发限流
5. **认证方式**：使用腾讯云 API v3 签名认证（与 COS、ASR 相同）

## 🎉 开始使用

现在你已经完成配置，可以开始使用混元翻译功能了！

点击"翻译"按钮，体验 AI 驱动的中日文翻译。
