# squash-to-main

压缩当前分支的所有提交，合并到本地 main（或 master）分支。用于整理 worktree 开发后的提交历史。

## 执行步骤

1. **切换到项目根目录**
   - 运行 `git rev-parse --show-toplevel` 获取 git 根目录路径
   - 如果当前目录不是根目录，切换到根目录

2. **检测当前状态**
   - 运行 `git branch --show-current` 获取当前分支名
   - 如果当前是 main 或 master，提示用户此命令仅用于非主分支
   - 运行 `git status` 检查是否有未提交的改动，如有则先提交

3. **检测是否为 worktree**
   - 运行 `git worktree list` 查看所有 worktree
   - 如果当前路径在 worktree 列表中且不是主仓库，标记为 worktree 模式
   - 记录主仓库路径（worktree list 的第一个路径）

4. **确定目标分支**
   - 在主仓库运行 `git branch | grep -E 'main|master'` 检查存在哪个主分支
   - 优先选择 main，如果没有则选择 master
   - 记录目标分支名称

5. **获取待压缩的提交**
   - 运行 `git log <main-branch>..HEAD --oneline` 获取当前分支相对于主分支的所有提交
   - 如果没有提交需要压缩，提示用户并退出

6. **分析提交内容生成合并消息**
   - 运行 `git log <main-branch>..HEAD --format="%s%n%b"` 查看所有提交的详细信息
   - 分析这些提交的整体目的，生成一个综合性的 commit message
   - 消息应简洁（1-2句话），描述整个分支的改动目的

7. **执行压缩合并**

   **如果是 worktree：**
   - 记录当前分支名
   - 切换到主仓库目录：`cd <主仓库路径>`
   - 切换到主分支：`git checkout <main-branch>`
   - 执行 squash 合并：`git merge --squash <current-branch>`
   - 提交压缩后的改动，使用生成的 commit message

   **如果是普通分支：**
   - 切换到主分支：`git checkout <main-branch>`
   - 执行 squash 合并：`git merge --squash <current-branch>`
   - 提交压缩后的改动，使用生成的 commit message

8. **显示结果**
   - 显示新的 commit SHA
   - 显示主分支状态

## 错误处理

- 当前已是主分支：提示用户切换到开发分支后再执行
- 有未提交改动：先执行提交再继续
- 合并冲突：提示用户手动解决冲突后重新执行
- 主分支不存在：提示用户检查分支名称

## 注意事项

- 此命令只在本地操作，不自动推送
- 原分支的提交历史会被压缩成一个提交
- 适合清理开发过程中的多次小提交
- worktree 必须回到主仓库执行 merge，无法在 worktree 内切换到其他分支