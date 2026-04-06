# commit

自动分析代码改动，生成自然的 commit message 并提交。只提交不推送。

## 执行步骤

1. **切换到项目根目录**
   - 运行 `git rev-parse --show-toplevel` 获取 git 根目录路径
   - 如果当前目录不是根目录，切换到根目录
   - 目的：避免在子目录执行时遗漏其他位置的变更

2. **检查状态**
   - 运行 `git status` 检查是否有未提交的改动
   - 如果没有改动，提示用户并退出

3. **分析改动**
   - 运行 `git diff` 查看未暂存的改动
   - 运行 `git diff --staged` 查看已暂存的改动
   - 运行 `git log --oneline -5` 学习项目的 commit 风格

4. **生成 commit message**
   - 基于改动内容生成简洁的描述（1-2句话）
   - 使用自然语言（中文或英文，根据项目风格）
   - 聚焦于改动的目的和影响

5. **执行提交**
   - 运行 `git add` 添加相关文件
   - 创建 commit，包含 Co-Authored-By 标记

6. **显示结果**
   - 显示 commit SHA 和分支信息

## 错误处理

- 无改动：提示"没有需要提交的改动"
- Pre-commit hook 失败：修复问题后重新提交
- Merge conflicts：提示用户先解决冲突