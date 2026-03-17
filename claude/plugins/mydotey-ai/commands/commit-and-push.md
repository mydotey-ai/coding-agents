# commit-and-push

自动分析代码改动，生成自然的 commit message 并推送到远程仓库。完全自动化，无需交互确认。

## 执行步骤

1. **检查状态**
   - 运行 `git status` 检查是否有未提交的改动
   - 如果没有改动，提示用户并退出

2. **分析改动**
   - 运行 `git diff` 查看未暂存的改动
   - 运行 `git diff --staged` 查看已暂存的改动
   - 运行 `git log --oneline -5` 学习项目的 commit 风格

3. **生成 commit message**
   - 基于改动内容生成简洁的描述（1-2句话）
   - 使用自然语言（中文或英文，根据项目风格）
   - 聚焦于改动的目的和影响

4. **执行提交**
   - 运行 `git add` 添加相关文件
   - 创建 commit，包含 Co-Authored-By 标记

5. **推送代码**
   - 运行 `git push` 推送到远程仓库

6. **显示结果**
   - 显示 commit SHA 和分支信息
   - 显示推送成功状态

## 错误处理

- 无改动：提示"没有需要提交的改动"
- 推送失败：显示详细错误信息
- Pre-commit hook 失败：提示用户手动处理
- Merge conflicts：提示用户先解决冲突
