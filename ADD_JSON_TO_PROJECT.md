# 如何将 123.json 添加到 Xcode 项目

## 方法一：通过 Xcode 添加（推荐）

1. 在 Xcode 中，右键点击 `Perapera` 文件夹
2. 选择 "Add Files to Perapera..."
3. 找到并选择项目根目录下的 `123.json` 文件
4. 确保勾选 "Copy items if needed" 和 "Add to targets: Perapera"
5. 点击 "Add"

## 方法二：修改代码读取方式

当前代码已经更新，会尝试从多个路径读取文件：
- 项目根目录
- 源代码相对路径
- Bundle 资源

运行应用并点击"翻译"按钮后，查看控制台输出的调试信息，了解文件查找情况。

## 验证

添加成功后，点击"翻译"按钮应该能在控制台看到 JSON 文件的完整内容。
