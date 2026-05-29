---
description: 扫描项目中的临时文件、构建产物、IDE 配置等，自动更新 .gitignore。
allowed-tools: ["Bash", "Read", "Edit", "Glob", "Grep"]
---

# git-ignore

扫描项目中的临时文件、构建产物、IDE 配置等，更新 `.gitignore`。

## 执行步骤

1. **切换到项目根目录**
   - 运行 `git rev-parse --show-toplevel` 获取 git 根目录路径
   - 如果当前目录不是根目录，切换到根目录

2. **扫描未跟踪文件**
   - 运行 `git status` 查看未跟踪的文件和目录
   - 运行 `git ls-files --others --exclude-standard` 列出所有未跟踪文件

3. **识别应忽略的模式**
   - 从未跟踪文件中识别常见忽略类别：
     - **构建产物**：`build/`、`target/`、`dist/`、`out/`、`*.class`、`*.jar`、`!lib/*.jar`
     - **IDE 配置**：`.idea/`、`.vscode/`、`*.iml`、`*.swp`
     - **系统文件**：`.DS_Store`、`Thumbs.db`
     - **依赖目录**：`node_modules/`、`vendor/`（非项目自身）
     - **日志和临时文件**：`*.log`、`*.tmp`、`*.bak`、`*.cache`
     - **环境配置**：`.env`、`.env.local`
   - 对未跟踪文件按上述类别归类，提取目录模式或文件模式

4. **合并到 .gitignore**
   - 读取现有 `.gitignore`（如存在）
   - 将新识别的模式追加到文件末尾，按类别分组，每组加注释
   - 不删除已有规则，不添加重复规则

5. **验证**
   - 运行 `git status` 确认临时文件已不再显示为未跟踪
   - 如果仍有遗漏，补充规则

6. **输出结果**
   - 列出新增的 `.gitignore` 规则
   - 列出被忽略的文件/目录

## 注意事项

- 只添加通配符模式（如 `build/`），不添加具体文件名
- 不忽略已跟踪的文件，如需忽略已跟踪文件需提示用户手动 `git rm --cached`
- 已被 `.gitignore` 覆盖的文件不重复添加
