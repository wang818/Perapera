# 安全问题修复步骤

## 问题
GitHub 检测到提交中包含腾讯云 SecretId 和 SecretKey，阻止了 push。

## 已完成的修复

1. ✅ 从代码中移除硬编码的凭证
2. ✅ 创建本地配置文件 `COSConfig.local.swift`（包含真实凭证）
3. ✅ 将本地配置文件添加到 `.gitignore`
4. ✅ 更新 `COSConfig.swift` 使用环境变量和本地配置

## 需要执行的步骤

### 1. 重置 Git 提交历史（移除敏感信息）

由于敏感信息已经在 Git 历史中，需要重写历史记录：

```bash
# 方法 1: 如果只是最近的提交包含敏感信息
git reset --soft HEAD~1  # 撤销最后一次提交，保留更改
git add .
git commit -m "Add COS upload functionality with secure credential management"
git push -f origin dev

# 方法 2: 如果有多个提交包含敏感信息
# 使用 git filter-repo 工具（推荐）
# 首先安装: pip install git-filter-repo
git filter-repo --path COS_SETUP_README.md --path Perapera/Services/COSConfig.swift --invert-paths --force
# 然后重新添加修复后的文件
git add .
git commit -m "Add COS upload functionality with secure credential management"
git push -f origin dev
```

### 2. 撤销已泄露的密钥

⚠️ **重要**: 由于 SecretId 和 SecretKey 已经暴露，建议立即：

1. 登录腾讯云控制台
2. 进入 **访问管理** > **API密钥管理**
3. **禁用或删除** 已泄露的密钥
4. 创建新的 API 密钥
5. 更新本地 `COSConfig.local.swift` 文件中的新密钥

### 3. 提交修复后的代码

```bash
# 确保本地配置文件不会被提交
git status  # 确认 COSConfig.local.swift 不在待提交列表中

# 提交修复
git add .
git commit -m "Fix: Remove hardcoded credentials and use environment variables"
git push origin dev
```

## 新的凭证管理方式

### 开发环境
在 `Perapera/Services/COSConfig.local.swift` 中配置（该文件已被 gitignore）：

```swift
extension COSConfig {
    static let localSecretId = "YOUR_NEW_SECRET_ID"
    static let localSecretKey = "YOUR_NEW_SECRET_KEY"
}
```

### 生产环境
使用环境变量：
- `COS_SECRET_ID`
- `COS_SECRET_KEY`

## 验证

1. 确认 `.gitignore` 包含 `Perapera/Services/COSConfig.local.swift`
2. 确认 `git status` 不显示本地配置文件
3. 确认代码中没有硬编码的凭证
4. 重新生成新的 API 密钥并更新本地配置

## 最佳实践

1. ✅ 永远不要在代码中硬编码敏感信息
2. ✅ 使用环境变量或本地配置文件
3. ✅ 将包含敏感信息的文件添加到 `.gitignore`
4. ✅ 定期轮换 API 密钥
5. ✅ 使用最小权限原则配置 API 密钥
