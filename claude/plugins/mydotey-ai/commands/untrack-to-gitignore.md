# untrack-to-gitignore

检查 git 已跟踪的文件，将临时文件从跟踪中移除并加入 `.gitignore`。

## 执行步骤

1. **切换到项目根目录**
   - 运行 `git rev-parse --show-toplevel` 获取 git 根目录路径
   - 如果当前目录不是根目录，切换到根目录

2. **列出所有已跟踪文件**
   - 运行 `git ls-files` 列出所有被 git 跟踪的文件

3. **识别临时文件**
   - 从已跟踪文件中识别应忽略的类别：
     - **构建产物**：`build/`、`target/`、`dist/`、`out/` 下的文件，`*.class`、`*.jar`、`*.pyc`、`*.o`、`*.so`
     - **IDE 配置**：`.idea/`、`.vscode/`、`*.iml`、`*.swp`
     - **系统文件**：`.DS_Store`、`Thumbs.db`
     - **日志和临时文件**：`*.log`、`*.tmp`、`*.bak`、`*.cache`
     - **环境配置**：`.env`、`.env.local`
   - 列出匹配的文件，按类别分组展示给用户

4. **确认**
   - 展示识别结果，请用户确认后再执行
   - 如果没有识别到临时文件，提示并退出

5. **移除跟踪并加入 .gitignore**
   - 对每个匹配的文件运行 `git rm --cached <file>`（保留本地文件，仅取消跟踪）
   - 根据文件路径提取模式（如 `build/output.txt` → `build/`），将模式写入 `.gitignore`
   - 如果 `.gitignore` 不存在则创建
   - 已存在的规则不重复添加

6. **输出结果**
   - 列出已取消跟踪的文件
   - 列出新增的 `.gitignore` 规则

## 注意事项

- 使用 `git rm --cached` 保留本地文件，不删除工作区文件
- 优先使用目录模式（如 `build/`）而非具体文件路径，确保同类文件都被忽略
- 不处理用户明确表示保留的文件
