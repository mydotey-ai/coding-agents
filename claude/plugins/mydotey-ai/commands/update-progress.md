# update-progress

自动分析最近的代码改动，更新项目进度文档 (docs/PROJECT_PROGRESS.md)，追踪已实现的功能和任务完成情况。

## 执行步骤

1. **分析最近的改动**
   - 运行 `git log --oneline -20` 查看最近的 commits
   - 运行 `git diff --stat HEAD~10..HEAD` 查看文件变更统计
   - 识别新实现的功能、新增的文件、代码行数变化

2. **读取当前进度文档**
   - 读取 `docs/PROJECT_PROGRESS.md` 文件
   - 识别当前已完成的阶段和任务
   - 找到需要更新的部分

3. **生成更新内容**
   - 基于最近的 commits，提取以下信息：
     * 新增的功能模块
     * 新增的文件（前端/后端）
     * 代码行数统计
     * Git commit SHAs
     * 完成时间
   - 生成符合文档格式的更新内容

4. **更新文档**
   - 在相应的阶段下添加新任务
   - 更新文件列表
   - 更新功能描述
   - 更新统计信息（提交数、代码行数等）
   - 更新完成状态（🔄 → ✅）

5. **提交更新**
   - 运行 `git add docs/PROJECT_PROGRESS.md`
   - 创建 commit: `docs: update project progress - [功能名称]`
   - 包含 Co-Authored-By 标记

6. **显示结果**
   - 显示更新的内容摘要
   - 显示 commit SHA
   - 确认文档已更新

## 更新规则

### 前端实现更新
当检测到前端相关文件时，更新 Phase 11 部分：
- 新增文件类型：`src/views/`, `src/api/`, `src/types/`, `src/components/`
- 更新任务列表（项目初始化、基础架构、认证、功能模块）
- 更新核心功能列表
- 更新代码统计（文件数、代码行数、构建大小）

### 后端实现更新
当检测到后端相关文件时，更新相应 Phase：
- Phase 1-10 的功能实现
- 新增的 Controller、Service、Repository
- 数据库表变更
- API 端点新增
- 测试覆盖情况

### 文档更新
当检测到文档相关文件时：
- 更新 API 文档状态
- 记录新增的设计文档
- 更新部署文档

## 代码分析要点

### 识别功能模块
通过以下方式识别实现的功能：
- Commit message 中的关键词（feat, fix, refactor 等）
- 文件路径模式（如 `views/agent/` 表示 Agent 管理功能）
- 相关 commits 的分组（同一功能的多个 commits）

### 代码行数统计
- 使用 `git diff --shortstat` 获取变更统计
- 分别统计新增和删除的行数
- 更新总代码行数

### 文件类型识别
- Java 文件 → 后端实现
- Vue/TS/TSX 文件 → 前端实现
- Test 文件 → 测试覆盖
- Markdown 文件 → 文档更新

## 输出格式

生成的更新内容应该包含：

```markdown
### 新增任务: [功能名称]

**完成时间：YYYY-MM-DD**

**实现内容：**
- 功能点 1
- 功能点 2

**新增文件：**
- 文件路径 1
- 文件路径 2

**Commits:**
- SHA - commit message
- SHA - commit message

**代码质量：**
- ✅ 测试通过
- ✅ 代码审查通过
```

## 错误处理

- **文档不存在**: 提示创建 `docs/PROJECT_PROGRESS.md` 文件
- **无新改动**: 提示"没有需要更新的内容"
- **无法识别改动**: 询问用户具体实现了什么功能
- **提交失败**: 显示详细错误信息

## 示例场景

### 场景 1: 完成 Agent 管理界面
```
检测到 commits:
- 6f59fdc feat: add Agent type definitions
- 6228939 feat: add Agent API functions
- 6a3a749 feat: add Agent list view
- db75014 feat: add Agent detail view

检测到文件:
- frontend/src/types/agent.ts
- frontend/src/api/agent.ts
- frontend/src/views/agent/AgentListView.vue
- frontend/src/views/agent/AgentDetailView.vue

更新内容:
在 Phase 11 下添加第 5 项任务
更新前端文件列表
更新核心功能列表
更新代码统计
```

### 场景 2: 完成后端 API 开发
```
检测到 commits:
- xxx feat: implement ChatController
- xxx feat: add chat service

检测到文件:
- src/main/java/.../ChatController.java
- src/main/java/.../ChatService.java
- src/test/java/.../ChatControllerTest.java

更新内容:
在相应 Phase 下添加任务
更新 API 端点列表
更新测试覆盖统计
```

## 注意事项

- 保持文档格式一致性
- 使用中文描述（符合项目风格）
- 包含具体的 commit SHA（便于追溯）
- 更新相关统计数字
- 标记完成状态（✅）
- 保留历史记录，不删除旧内容
