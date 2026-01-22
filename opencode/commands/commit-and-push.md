---
description: 自动分析代码改动，生成自然的 commit message 并推送到远程仓库
---

## 第一步：检查当前git状态

### 检查是否有未提交的改动
先运行git status来查看当前工作区状态：

```bash
!`git status`
```

如果没有改动，则输出"没有需要提交的改动"并结束执行。

## 第二步：分析代码改动和项目风格

### 1. 查看未暂存的改动
```bash
!`git diff`
```

### 2. 查看已暂存的改动（如果有）
```bash
!`git diff --staged`
```

### 3. 学习项目的commit风格
查看最近5个commit了解项目风格：

```bash
!`git log --oneline -5`
```

## 第三步：生成commit message

基于上述分析，生成一个简洁的commit message（1-2句话）：
- 使用中文自然语言描述
- 聚焦于改动的目的和影响
- 保持简洁明了
- 可以参考项目的commit风格

Commit message应该能够清晰表达这次改动的核心内容。

## 第四步：执行git操作

### 1. 添加改动文件
```bash
!`git add .`
```

### 2. 创建commit
根据生成的commit message创建commit，并包含Co-Authored-By标记来记录AI协助：

```bash
!`git commit -m "生成的commit message" --author="AI Assistant <ai@opencode.ai>" || echo "commit失败，可能pre-commit hook失败或冲突需要手动处理"`
```

如果commit失败，显示错误信息并结束执行。

### 3. 显示commit信息
```bash
!`git log --oneline -1`
```

## 第五步：推送到远程仓库

### 1. 推送当前分支
```bash
!`git push || echo "推送失败，请检查远程配置或权限"`
```

### 2. 显示推送结果
```bash
!`git status -uno`
```

## 第六步：显示最终结果

总结操作结果：
- 提交的commit SHA
- 分支信息
- 推送状态
- 任何需要注意的事项

如果所有步骤都成功，显示"代码已成功提交并推送到远程仓库"。如果有任何问题，显示详细的错误信息和下一步建议。