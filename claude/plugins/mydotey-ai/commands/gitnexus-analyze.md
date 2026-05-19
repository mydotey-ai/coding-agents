# gitnexus-analyze

使用 GitNexus 索引当前仓库，丢弃已有 embeddings 并跳过 skills 以加快速度。

## 执行步骤

1. **切换到项目根目录**
   - 运行 `git rev-parse --show-toplevel` 获取 git 根目录路径
   - 如果当前目录不是根目录，切换到根目录

2. **执行索引**
   - 运行 `gitnexus analyze --embeddings 0 --drop-embeddings --skip-skills --index-only`
   - 等待命令完成，观察输出

3. **显示结果**
   - 显示索引完成状态
   - 如有警告或错误，一并展示

## 错误处理

- gitnexus 未安装：提示用户先安装 gitnexus
- 命令执行失败：显示详细错误信息，建议检查 gitnexus 配置
