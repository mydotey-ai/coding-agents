---
description: 全面审查项目代码（支持指定目录、多项目单元自动检测），支持 Java/Rust/Go/Python/Node.js/前端/文档多语言，包含安全/架构/性能/死代码/测试/规范六维度量化评分。默认不执行任何测试套件。
argument-hint: "[维度…] [--quick] [--run-tests] [--dir 目录] [--baseline]"
allowed-tools: ["Bash", "Glob", "Grep", "Read", "Write", "Edit", "Agent"]
---

# 项目代码审查

对项目或指定目录进行多维度审查，自动检测多项目单元，生成带量化评分的报告。**只读为主**：默认不执行测试、不修改代码。

**参数：** $ARGUMENTS

---

## 参数规范

| 参数 | 说明 | 默认 |
|---|---|---|
| 维度（可多选，空格分隔） | `security` `architecture` `performance` `error-handling` `observability` `data-integrity` `scalability` `dead-code` `testing` `standards` | 全部 10 个 |
| `--quick` | 只跑静态扫描，跳过 10 个深度审计 Agent | 关 |
| `--run-tests` | **显式允许**执行测试/覆盖率命令（否则一律跳过） | 关 |
| `--dir D` | 指定审查目录，相对或绝对路径。默认为项目根目录 `PROJECT_ROOT` | `PROJECT_ROOT` |
| `--baseline` | 与上次 `docs/review/baseline.json` 对比，输出 delta | 关 |
| `--max-files N` | 大型项目限流：超过 N 个源文件时，Agent 只检查 `min(N, max_files)` 个关键文件 | 500 |
| `--weights W` | 自定义评分权重，格式：`security=0.2,architecture=0.15,...`（必须 10 个维度且总和为 1） | 默认权重 |

### 解析规则

1. 以 `--` 开头的 token 是选项；其余 token 是维度。
2. 未知 token 报错并终止，不要猜测。
3. `security performance` 表示同时审计两个维度；不传任何维度 = 全部。
4. `--dir` 参数：相对路径转换为绝对路径（`realpath` 或等效逻辑）；目录不存在则报错终止。

**目录解析流程：**
```
REVIEW_DIR = (用户指定 --dir D) ? resolve_to_absolute(D) : {CWD}
若 REVIEW_DIR 不存在或非目录 → 报错终止
```

---

## 执行流程

### 步骤 1 · 技术栈检测（禁止用 find/cat）

**必须用 Glob/Read，不要用 `find` 或 `cat`。**

**首先解析审查目录：**
- `PROJECT_ROOT = {CWD}`（始终为当前工作目录，review 制品存放位置）
- `REVIEW_DIR = (--dir D) ? resolve_to_absolute(D) : {CWD}`（审查范围）
- 若 `--dir D` 指定相对路径，转换为绝对路径（使用 Bash `realpath` 或等效逻辑）
- 若 `REVIEW_DIR` 不存在或非目录，报错终止：「❌ 指定目录不存在：{D}」
- **不传 `--dir` 时**：`REVIEW_DIR = PROJECT_ROOT`，审查整个项目（传统模式）
- **传 `--dir` 时**：`REVIEW_DIR` 为子目录，`PROJECT_ROOT` 保持为根目录，制品存 `{PROJECT_ROOT}/docs/review/`

**多项目/嵌套项目检测模式：**

审查目录可能包含多个独立项目（或项目在子目录中），需要递归检测所有"项目单元"。

**项目单元定义：** 包含以下任一构建文件的目录视为一个独立项目单元：
- `pom.xml` / `build.gradle` / `build.gradle.kts` — Java/Gradle 项目
- `Cargo.toml` — Rust 项目
- `go.mod` — Go 项目
- `package.json` — Node.js/前端项目（排除被其他项目包含的情况）
- `requirements.txt` / `pyproject.toml` / `setup.py` — Python 项目
- **无构建文件但有源代码** — 视为"代码片段/模块"项目单元

**文档项目单元定义（TECH_STACK 为 `["documentation"]` 时）：**
- 若审查目录下存在 `.md` / `.rst` / `.adoc` 等文档文件且无代码源文件
- 整个 `REVIEW_DIR` 视为一个文档项目单元
- 不进行多项目单元拆分（文档通常视为整体）

并行执行（单条消息内）：

- `Glob("{REVIEW_DIR}/pom.xml")` `Glob("{REVIEW_DIR}/build.gradle")` `Glob("{REVIEW_DIR}/build.gradle.kts")` — 检测审查目录本身是否为 Java 项目
- `Glob("{REVIEW_DIR}/Cargo.toml")` `Glob("{REVIEW_DIR}/go.mod")` — 检测 Rust/Go 项目
- `Glob("{REVIEW_DIR}/package.json")` `Glob("{REVIEW_DIR}/requirements.txt")` `Glob("{REVIEW_DIR}/pyproject.toml")` `Glob("{REVIEW_DIR}/setup.py")` — 检测 Node/Python 项目
- `Glob("{REVIEW_DIR}/**/pom.xml")` `Glob("{REVIEW_DIR}/**/build.gradle")` `Glob("{REVIEW_DIR}/**/build.gradle.kts")` — 递归检测子目录中的 Java 项目
- `Glob("{REVIEW_DIR}/**/Cargo.toml")` `Glob("{REVIEW_DIR}/**/go.mod")` — 递归检测子目录中的 Rust/Go 项目
- `Glob("{REVIEW_DIR}/**/package.json")` — 递归检测子目录中的 Node 项目
  **过滤规则**：Glob 默认尊重 `.gitignore`，会自动排除 `node_modules`/`target`/`dist`/`.git` 等。若 `.gitignore` 不存在或未配置，需要在汇总算法中手动过滤包含这些目录的路径。
- `Glob("{REVIEW_DIR}/**/pyproject.toml")` `Glob("{REVIEW_DIR}/**/setup.py")` — 递归检测子目录中的 Python 项目
- `Glob("{REVIEW_DIR}/**/*.java")` `Glob("{REVIEW_DIR}/**/*.rs")` `Glob("{REVIEW_DIR}/**/*.go")` `Glob("{REVIEW_DIR}/**/*.{ts,tsx,js,jsx}")` `Glob("{REVIEW_DIR}/**/*.py")` — 统计源文件
- `Read("{PROJECT_ROOT}/CLAUDE.md")` — 加载项目规则（失败则忽略，发起前必须替换为绝对路径）
- `Read("{PROJECT_ROOT}/.gitignore")` — 检查忽略规则（失败则视为不存在，发起前必须替换为绝对路径）

**项目单元汇总算法：**

```
PROJECT_UNITS = []

for each found build_file:
    project_dir = parent_dir(build_file)
    
    # 排除规则
    if project_dir contains "node_modules" or "target" or "dist" or ".git":
        skip
    
    # 去重：同一个目录多个构建文件视为一个项目单元
    if project_dir already in PROJECT_UNITS:
        merge tech_stack for that unit
    else:
        PROJECT_UNITS.append({
            "path": project_dir,
            "rel_path": relative_path from REVIEW_DIR,
            "tech_stack": detect_from_build_file(build_file),
            "build_files": [build_file]
        })

# 若审查目录本身没有构建文件但有源代码，则视为"代码片段/模块"
if REVIEW_DIR not in PROJECT_UNITS and has_source_files:
    PROJECT_UNITS.append({
        "path": REVIEW_DIR,
        "rel_path": ".",
        "tech_stack": detect_from_source_files(),
        "build_files": []
    })
```

将结果写入内存变量：
- `PROJECT_UNITS` — 项目单元列表（数组）
- `TECH_STACK` — 汇总技术栈（数组，合并所有项目单元）
- `FILE_COUNTS` — 源文件统计（按语言汇总）
- `CLAUDE_RULES` — 项目规则
- `GITIGNORE_STATE` — 忽略规则状态

**补充验证：**
- 若 `.gitignore` 不存在或为空，发出警告：「⚠️ 项目无 .gitignore，Glob 可能扫描到大量无关文件，建议创建」

**文档项目自动适配：**
- 若未检测到任何源代码文件（无 .java/.rs/.go/.ts/.tsx/.js/.jsx/.py），自动将 `TECH_STACK` 设为 `["documentation"]`
- 文档模式下跳过所有语言特定的静态扫描和测试覆盖率步骤
- 文档模式下 6 个维度的检查清单自动切换为文档审查模式（见步骤 4 的文档检查清单）

输出进度提示：
```
🔍 检测到 {N} 个项目单元：
   - {rel_path_1}: {tech_stack_1}
   - {rel_path_2}: {tech_stack_2}
   ...
📊 汇总技术栈：{TECH_STACK}，源文件：{FILE_COUNTS}
```

### 步骤 2 · 建立输出工作区

**在 `PROJECT_ROOT` 下创建输出目录：**

```bash
mkdir -p "{PROJECT_ROOT}/docs/review/.tmp"
```

**目录规划（统一在 `{PROJECT_ROOT}/docs/review/`）：**

| 路径 | 用途 |
|---|---|
| `{PROJECT_ROOT}/docs/review/report.md` | 最终报告（人类可读） |
| `{PROJECT_ROOT}/docs/review/baseline.json` | 基线指标（机器可读，供下次 `--baseline` 对比） |
| `{PROJECT_ROOT}/docs/review/issues.json` | 扁平化问题列表（供 IDE 导入） |
| `{PROJECT_ROOT}/docs/review/.tmp/*.json` | 扫描中间产物 + 每个 Agent 的原始返回 |

**确保 `.gitignore` 已忽略整个目录**——见步骤 8。

输出进度提示：`📁 工作区已建立：{PROJECT_ROOT}/docs/review/`

### 步骤 3 · 自动化静态扫描（并行 Bash）

**规则：**
- 每个命令必须带超时包装（优先级：`timeout` > `gtimeout` > `python3` wrapper > `perl` wrapper）
- 每个命令必须 `> "{PROJECT_ROOT}/docs/review/.tmp/xxx.json" 2> "{PROJECT_ROOT}/docs/review/.tmp/xxx.err"`
- 命令缺失或失败 → 写入 `{"status":"failed_or_missing","error":"..."}` 到对应 JSON，**不中断流程**
- **允许**用 `|| echo '{"status":"..."}' > file.json` 写入结构化 fallback（这是写文件，不是污染 stdout）
- **禁止**用 `|| echo "建议安装 xxx"` 或任何人类可读文本混入 stdout
- 若维度未被选中则跳过对应扫描
- **若 TECH_STACK 为 `["documentation"]`，跳过整个步骤 3**，直接写入 `{"status":"skipped_documentation_project"}` 到所有扫描文件

**多项目单元扫描策略：**

- 通用安全工具（gitleaks、semgrep）对整个 `REVIEW_DIR` 执行一次
- 语言特定工具（mvn audit、cargo audit、npm audit 等）针对每个项目单元单独执行
- 输出文件命名：`{tool}_{project_unit_index}.json`（如 `npm_audit_0.json`, `npm_audit_1.json`）
- 项目单元索引从 0 开始，与 `PROJECT_UNITS` 数组顺序一致

并行组（单条消息多个 Bash 调用）：

```bash
# 超时包装函数（支持 macOS/Linux）
review_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$@"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "
import subprocess, sys, time, signal
proc = subprocess.Popen(sys.argv[2:])
start = time.time()
while proc.poll() is None:
    if time.time() - start > int(sys.argv[1]):
        proc.send_signal(signal.SIGKILL)
        sys.exit(124)
    time.sleep(0.5)
sys.exit(proc.returncode)
" "$@"
  else
    perl -e 'alarm shift; exec @ARGV' "$@"
  fi
}

# 通用安全（对整个审查目录执行一次）
review_timeout 60 gitleaks detect --source "{REVIEW_DIR}" --no-git --report-format json --report-path "{PROJECT_ROOT}/docs/review/.tmp/gitleaks.json" 2> "{PROJECT_ROOT}/docs/review/.tmp/gitleaks.err" \
  || echo '{"status":"failed_or_missing"}' > "{PROJECT_ROOT}/docs/review/.tmp/gitleaks.json"

review_timeout 120 semgrep --config auto --json --quiet "{REVIEW_DIR}" > "{PROJECT_ROOT}/docs/review/.tmp/semgrep.json" 2> "{PROJECT_ROOT}/docs/review/.tmp/semgrep.err" \
  || echo '{"status":"failed_or_missing"}' > "{PROJECT_ROOT}/docs/review/.tmp/semgrep.json"

# 按项目单元执行语言特定扫描（示例：项目单元 0，实际执行时需替换为具体路径）
# 注意：以下示例中的占位符需要在执行前替换为实际值
review_timeout 60 cd "{PROJECT_UNITS[0].path}" && npm audit --json > "{PROJECT_ROOT}/docs/review/.tmp/npm_audit_0.json" 2> "{PROJECT_ROOT}/docs/review/.tmp/npm_audit_0.err" \
  || echo '{"status":"failed_or_missing","project_unit":0}' > "{PROJECT_ROOT}/docs/review/.tmp/npm_audit_0.json"

review_timeout 60 cd "{PROJECT_UNITS[0].path}" && npx --yes knip --reporter json > "{PROJECT_ROOT}/docs/review/.tmp/knip_0.json" 2> "{PROJECT_ROOT}/docs/review/.tmp/knip_0.err" \
  || echo '{"status":"failed_or_missing","project_unit":0}' > "{PROJECT_ROOT}/docs/review/.tmp/knip_0.json"
```

按检测到的项目单元技术栈补充（每条都带 `review_timeout N` + JSON 落盘）：

**单个项目单元扫描命令模板：**

| 技术栈 | 安全扫描 | 死代码/质量扫描 |
|---|---|---|
| Java | `cd "{UNIT_PATH}" && mvn -q org.owasp:dependency-check-maven:check -DskipTests` | （依赖 IDE/Sonar，跳过） |
| Rust | `cd "{UNIT_PATH}" && cargo audit --json` | `cd "{UNIT_PATH}" && cargo +nightly udeps --output json` |
| Go | `cd "{UNIT_PATH}" && govulncheck -json ./...` | `cd "{UNIT_PATH}" && staticcheck -f json ./...` |
| Node | `cd "{UNIT_PATH}" && npm audit --json` | `cd "{UNIT_PATH}" && npx --yes knip --reporter json` |
| Python | `cd "{UNIT_PATH}" && pip-audit -f json` | `cd "{UNIT_PATH}" && vulture .` |

**执行策略：**
- 遍历 `PROJECT_UNITS` 数组
- 对每个项目单元，根据其 `tech_stack` 选择对应的扫描命令
- 输出文件名格式：`{tool_name}_{unit_index}.json`
- 所有扫描在单条消息中并行发起（若项目单元过多，分批执行）

**测试覆盖率命令**（`mvn test jacoco:report`、`go test -cover`、`cargo tarpaulin`、`npm test`、`coverage run`）**仅在 `--run-tests` 时执行**，否则从 `target/site/jacoco/jacoco.xml`、`coverage/coverage-summary.json`、`.coverage` 等已有产物读取；都不存在则标记 `coverage: unknown`。

**测试失败降级处理：**
- 测试命令失败 → 写入 `{"status":"test_failed", "coverage":"unknown", "error":"命令输出摘要", "project_unit": N}`
- 超时（300s）→ `{"status":"timeout", "coverage":"unknown", "project_unit": N}`
- 部分 module 失败 → 标记该 module 为 `failed`，其他成功 module 的覆盖率正常统计

输出进度提示：`🔎 静态扫描完成（{N} 个项目单元）`

### 步骤 4 · 分批调度审计 Agent（跳过条件：`--quick`）

**核心原则：每个 Agent 完成后立即输出结果，避免上下文膨胀。**

**执行流程（每批）：**

1. **单条消息并行发起本批所有 Agent**
2. **收到 Agent 返回后，立即处理并输出**（不要等其他 Agent）：
   - 提取 JSON（若包含代码块则提取，纯 JSON 直接使用）
   - 用 `Write` 保存到 `{PROJECT_ROOT}/docs/review/.tmp/{dimension}.json`
   - 输出进度提示：`✅ {dimension} 完成（score: XX, findings: X）`
   - **不要在内存中累积 Agent 返回内容**，立即释放上下文

**分批策略：**

| 批次 | 维度 | 数量 | 发起时机 |
|:----:|------|:----:|----------|
| 第一批 | security + architecture + performance + error-handling | 4 | 先发起 |
| 第二批 | observability + data-integrity + scalability | 3 | 第一批全部完成后发起 |
| 第三批 | dead-code + testing + standards | 3 | 第二批全部完成后发起 |

**关键约束：**

1. `subagent_type` 固定为 `Explore`（只读、专为代码库分析优化）
2. 每个 Agent 的 `prompt` 必须**自包含**：显式列出项目路径、技术栈、输出 JSON schema、深度要求
3. **禁止在内存中保留 Agent 返回内容**，收到后立即处理、输出、释放
4. 每批完成后，用 `Read` 抽样校验本批结果（详见步骤 5）

#### 共享 JSON schema（所有 Agent 共用）

所有 Agent 输出必须遵循此 schema：

```json
{
  "dimension": "security|architecture|performance|error-handling|observability|data-integrity|scalability|dead-code|testing|standards",
  "score": 0-100,
  "findings": [
    {
      "id": "security-001",
      "severity": "critical|high|medium|low",
      "title": "...",
      "file": "path/to/file.ext",
      "line": 42,
      "evidence": "可引用的代码片段或配置",
      "recommendation": "具体修复建议",
      "effort_hours": 0.5,
      "project_unit": "可选，关联的项目单元相对路径（多项目模式下使用）"
    }
  ],
  "summary": "3-5 句话总结",
  "coverage": {
    "files_examined": N,
    "project_units_examined": ["./module-a", "./module-b"],
    "skipped_reason": "…"
  }
}
```

**注意：**
- `id` 格式为 `{维度}-{序号}`，确保跨维度唯一性
- `project_unit` 字段可选，多项目模式下用于关联具体项目单元
- `coverage.project_units_examined` 记录实际检查的项目单元列表

**输出格式：** Agent 可以输出纯 JSON，也可以用 ` ```json ``` ` Markdown 代码块包裹。父级会自动提取。

#### Agent prompt 模板（每个维度具体化）

每个 Agent 的 prompt 至少包含以下段落（填入实际值）：

```
你是 {维度} 审计员。

【项目】
- 审查目录：{REVIEW_DIR}（用户指定或项目根目录）
- 项目根目录：{PROJECT_ROOT}（review 制品存放位置）
- 项目单元数量：{PROJECT_UNITS_COUNT}
- 项目单元列表：
  {PROJECT_UNITS_SUMMARY}
- 汇总技术栈：{TECH_STACK}
- 源文件统计：{FILE_COUNTS}
- 项目规则：见 CLAUDE.md（已存在则精读）
- 项目模式：{代码项目 | 文档项目 | 多项目混合}

{若为多项目模式，附加以下内容}
本次审查覆盖多个独立项目单元，请按以下策略处理：
- 每个项目单元可能有不同的技术栈，需针对性检查
- finding 的 file 路径应相对于 {REVIEW_DIR}
- 若某个项目单元有特定问题，在 summary 中注明「{项目单元路径}：...」
- 检查跨项目单元的共享问题（如共享配置、依赖版本不一致等）

{若为文档项目，附加以下内容}
这是一个纯文档/设计文档项目，请按文档审查模式检查：
- 重点审查文档的完整性、一致性、准确性
- 检查清单按文档审查模式调整（见下方）
- finding 的 file:line 指向文档中的具体位置

【已有扫描结果】请先 Read 以下文件（相对于 {PROJECT_ROOT}），作为线索起点：
- {PROJECT_ROOT}/docs/review/.tmp/gitleaks.json（通用安全扫描）
- {PROJECT_ROOT}/docs/review/.tmp/semgrep.json（通用安全扫描）
- {PROJECT_ROOT}/docs/review/.tmp/{tool}_{unit_index}.json（各项目单元的语言特定扫描）

【{维度}检查清单】
（见下方"维度特定检查清单"章节，将对应维度的清单完整嵌入此处）

【深度要求】
- 项目总文件数 M，Agent 至少检查 N = min(50, max(10, M/20)) 个关键文件
- 若用户指定 `--max-files K`，则 N = min(N, K)
- 多项目模式：每个项目单元至少检查 min(10, N/{PROJECT_UNITS_COUNT}) 个关键文件
- 优先检查：入口文件、配置文件、扫描结果中已标记的文件、高频修改文件（git log 热点）
- 每条 finding 必须给出 file:line 和可验证的 evidence
- 不要输出通用套话

【输出】
严格按 JSON schema 输出。纯 JSON 或用 ```json``` 代码块包裹均可。
不要输出 schema 之外的任何非 JSON 文本。
```

#### Agent prompt 变量替换清单

| 变量 | 来源 | 示例 |
|---|---|---|
| `{维度}` | 当前维度名 | `security` |
| `{REVIEW_DIR}` | 步骤 1 解析的审查目录（用户指定 `--dir` 或 `{CWD}`） | `/Users/foo/project/src` |
| `{PROJECT_ROOT}` | 项目根目录 `{CWD}` | `/Users/foo/project` |
| `{PROJECT_UNITS_COUNT}` | 项目单元数量 | `3` |
| `{PROJECT_UNITS_SUMMARY}` | 项目单元汇总文本（每行一个） | `- ./module-a: [java, spring-boot]\n  - ./module-b: [node, react]` |
| `{TECH_STACK}` | 步骤 1 检测结果（汇总） | `["java", "spring-boot", "node", "react"]` |
| `{FILE_COUNTS}` | 步骤 1 统计结果 | `{"java": 120, "ts": 45}` |
| `{N}` | 深度要求计算值 | `min(50, max(10, M/20))` |

**务必在发起 Agent 前完成所有替换，不得保留占位符。**

#### 维度特定检查清单

**代码项目检查清单：**

- **security**：OWASP Top 10 + `硬编码密钥/不安全随机数/敏感日志/输入验证缺失` + 语言特定（Java SQL注入/Spring Security、Rust unsafe/unwrap/FFI、Go fmt.Sprintf SQL/goroutine 竞态、Node innerHTML/原型污染、Python f-string SQL/os.system）
- **architecture**：SOLID/循环依赖/分层违规 + 语言特定（Spring Controller→Service→Repo、Rust mod/trait/生命周期、Go cmd/internal/pkg、前端组件分层/状态管理、Python View/Model/Service）
- **performance**：N+1/缺索引/SELECT * + 语言特定（Hibernate N+1/HikariCP、Rust clone/Arc、Go goroutine 泄漏/channel 阻塞、前端重渲染/包体积/Web Vitals、Node 事件循环阻塞、Python select_related）
- **error-handling**：异常处理完整性（空 catch/吞异常）、错误边界、失败回退策略、错误消息可读性（含上下文）、重试机制合理性、超时处理、语言特定（Java checked/unchecked、Rust Result/Option、Go panic/recover、Node Promise rejection、Python try/except 最佳实践）
- **observability**：日志完整性（请求入口/出口/异常、结构化日志）、监控指标覆盖（关键业务指标/性能指标）、告警阈值合理性、trace 链路完整性、debug 信息可追溯性、语言特定（Java SLF4J/Logback、Rust tracing crate、Go logrus/zap、Node winston/pino、Python structlog）
- **data-integrity**：输入验证完整性（API 入口/数据库写入）、数据校验规则、事务边界明确性、幂等性设计、并发安全（锁/原子操作/乐观锁）、语言特定（Java Bean Validation、Rust 类型安全、Go context/errgroup、前端表单验证、Python Pydantic）
- **scalability**：分片策略合理性、限流机制（令牌桶/漏桶）、熔断器配置、降级策略明确性、无状态设计、热点数据处理、语言特定（Java Resilience4j、Rust async 并发模型、Go channel 并发控制、Node cluster/pm2、Python Celery 并发）
- **dead-code**：未用函数/导出/导入/依赖、死分支、注释代码、废弃文件。**必须先 Read `{PROJECT_ROOT}/docs/review/.tmp/{knip,udeps,vulture,staticcheck}_{unit_index}.json`。**
- **testing**：覆盖率缺口/关键路径/边界/测试异味/不稳定测试。优先从已有覆盖率产物推断，无产物时标 `coverage: unknown` 不推测。
- **standards**：CLAUDE.md 合规 + 语言特定 lint（Checkstyle/clippy/staticcheck/ESLint/Ruff）+ 命名 + 文档

**文档项目检查清单（TECH_STACK 为 `["documentation"]` 时使用）：**

- **security**：敏感数据暴露（文档中是否包含示例密码/API密钥/真实业务数据）、PII 脱敏、认证/授权设计完整性、数据加密/传输安全设计、多租户隔离方案、API 安全设计、密钥管理、容灾与备份策略
- **architecture**：DDD 建模质量（聚合根/值对象/领域边界）、领域一致性（跨文档领域划分是否矛盾）、服务拆分合理性、事件驱动设计完整性、跨域事务设计（Saga）、技术选型合理性、架构图一致性
- **performance**：缓存策略设计、数据库优化策略、异步处理设计、消息队列使用合理性、扩展性设计、大数据量报表生成策略、监控指标完整性
- **error-handling**：异常处理策略覆盖（各场景错误处理方案）、错误码设计完整性、错误恢复机制说明、用户友好错误提示设计、故障排查指南
- **observability**：监控方案完整性、日志策略说明、告警规则设计、trace 方案说明、调试信息获取方式、运维手册完整性
- **data-integrity**：数据校验规则说明、事务设计文档、幂等性设计说明、并发控制方案、数据一致性保障方案
- **scalability**：扩容方案设计、限流熔断降级策略、分片方案、热点数据处理方案、性能瓶颈预案
- **dead-code**：过时/矛盾的描述、重复内容、废弃章节、与其他文档冲突的信息、未更新的占位符
- **testing**：测试策略是否在设计文档中覆盖、测试指标是否明确、测试场景完整性、可测试性设计
- **standards**：文档命名规范、术语一致性、格式统一性、目录结构清晰度、跨文档引用完整性

### 步骤 5 · 批次校验（在每批 Agent 完成后立即执行）

**校验时机：** 每批 Agent 全部返回后，立即校验本批结果（不等其他批次）。

**校验流程：**

1. **从文件读取结果**（不要从内存读取，释放上下文）：
   - 用 `Read("{PROJECT_ROOT}/docs/review/.tmp/{dimension}.json")` 读取本批各维度结果
   
2. **校验 JSON schema**（抽样验证策略）：
   - `score` 必须在 0-100 范围
   - `severity` 必须是 `critical|high|medium|low` 之一
   - **抽样验证 `file:line` 存在性**：
     - 若 findings 数量 ≤ 3，验证所有 findings
     - 若 findings 数量 > 3，验证前 3 条 findings（便于调试定位）
     - 对每条抽样 finding：用 `Read("{REVIEW_DIR}/{finding.file}")` 验证文件存在
     - 文件不存在 → 剔除该 finding，记录警告，用 `Write` 更新 JSON
   - **file 路径处理**：finding 的 `file` 是相对于 `REVIEW_DIR` 的相对路径
   
3. **校验失败处理**：
   - 不要尝试继续或重启 Agent
   - 直接标注 `validation_error`，剔除未通过校验的 findings
   - 用 `Write` 更新校验后的 JSON
   
4. **输出校验结果**：
   - 输出进度提示：`🔍 {dimension} 校验完成（有效 findings: X）`

### 步骤 6 · 评分计算（确定性算法）

**数据来源：从文件读取，不从内存读取。**

用 `Read("{PROJECT_ROOT}/docs/review/.tmp/{dimension}.json")` 读取各维度校验后的结果，计算评分。

**每个维度 `score` 由 Agent 给出，父级二次校验：**

```text
# 代码项目 penalty
code_severity_penalty = { critical: 25, high: 10, medium: 5, low: 2 }

# 文档项目 penalty（文档 finding 的严重度标准更宽松）
docs_severity_penalty = { critical: 15, high: 8, medium: 4, low: 1 }

severity_penalty = (TECH_STACK == ["documentation"]) ? docs_severity_penalty : code_severity_penalty

recomputed_score = max(0, 100 - Σ severity_penalty[f.severity])
final_score = min(agent_score, recomputed_score)   # 取更严苛者
```

**加权综合：**

```
# 默认权重（10 维度，按重要性分层）
# - 核心维度（安全/架构）：27%
# - 运维维度（错误处理/可观测性/数据完整性/性能）：40%
# - 质量维度（测试/规范/可扩展性）：28%
# - 清理维度（死代码）：5%
default_weights = {
  security: 0.15,
  architecture: 0.12,
  performance: 0.10,
  error-handling: 0.10,
  observability: 0.10,
  data-integrity: 0.10,
  scalability: 0.08,
  dead-code: 0.05,
  testing: 0.10,
  standards: 0.10
}

# 若用户指定 --weights，则使用自定义权重（需校验总和为 1.0）
weights = user_weights || default_weights

total = Σ dimension_score × weights[dimension]
```

未审计维度（只跑了 `--quick` 或只选部分维度）不参与加权，权重按剩余维度**等比例缩放**使总和仍为 1.0。

**技术债务：** `Σ finding.effort_hours`（Agent 已估算，父级不再二次加权）

### 步骤 7 · 生成三个输出文件（用 Write，不要用 echo）

输出进度提示：`📝 正在生成报告…`

**统一输出目录：`{PROJECT_ROOT}/docs/review/`（最终产物 + `.tmp/` 中间态）。**

| 文件 | 路径 | 生成者 | 时机 |
|---|---|---|---|
| 完整报告 | `{PROJECT_ROOT}/docs/review/report.md` | Write 工具 | 步骤 7 |
| 基线指标 | `{PROJECT_ROOT}/docs/review/baseline.json` | Write 工具 | 步骤 7 |
| 扁平问题列表 | `{PROJECT_ROOT}/docs/review/issues.json` | Write 工具 | 步骤 7 |

#### `{PROJECT_ROOT}/docs/review/baseline.json` schema

```json
{
  "generated_at": "ISO8601",
  "review_dir": "...",
  "project_root": "...",
  "project_units": [
    {
      "path": "...",
      "rel_path": "...",
      "tech_stack": [...]
    }
  ],
  "tech_stack": [...],
  "dimensions": {
    "security": { "agent_score": N, "recomputed_score": N, "findings_count": { "critical":N, "high":N, "medium":N, "low":N } },
    "...": {}
  },
  "tech_debt_hours": N
}
```

**注意：**
- `review_dir` 为实际审查的目录路径
- `project_root` 为项目根目录（制品存放位置）
- `project_units` 为检测到的项目单元列表

#### `{PROJECT_ROOT}/docs/review/issues.json` schema

扁平数组，每项 = 一条 finding + `dimension` 字段，便于 IDE 导入。

```json
[
  {
    "id": "security-001",
    "dimension": "security",
    "severity": "critical",
    "title": "...",
    "file": "path/to/file.ext",
    "line": 42,
    "evidence": "...",
    "recommendation": "...",
    "effort_hours": 0.5,
    "project_unit": "./module-a"
  },
  ...
]
```

**注意：** `file` 路径相对于 `REVIEW_DIR`，IDE 导入时需转换为绝对路径。

#### `{PROJECT_ROOT}/docs/review/report.md` 模板

```markdown
# 项目审查报告

| 属性 | 值 |
|------|-----|
| **生成时间** | {ISO8601} |
| **审查目录** | {REVIEW_DIR} |
| **项目根目录** | {PROJECT_ROOT}（仅当与审查目录不同时显示） |
| **项目单元** | {PROJECT_UNITS_COUNT} 个（见下方详情） |
| **汇总技术栈** | {TECH_STACK} |
| **审查模式** | 完整 / --quick / 部分维度: {…} |
| **测试执行** | 是 / 否（默认不执行） |

## 项目单元概览

{若 PROJECT_UNITS_COUNT > 1，显示此表格}

| 序号 | 相对路径 | 技术栈 | 构建文件 |
|:----:|----------|--------|----------|
| 1 | ./module-a | java, spring-boot | pom.xml |
| 2 | ./module-b | node, react | package.json |
| ... |

{若为单项目模式或代码片段，跳过此表格}

## 评分说明

**Agent 评分：** 各维度 Agent 基于代码质量综合判断给出的主观评分（0-100），反映代码整体健康度。

**校验评分：** 使用确定性算法 `max(0, 100 - Σ severity_penalty)` 重新计算（Critical=25, High=10, Medium=5, Low=2），取 `min(agent_score, recomputed_score)`。校验评分更严苛，反映问题的实际严重程度。

## 执行摘要

| 维度 | Agent评分 | 校验评分 | Critical | High | Medium | Low |
|------|:---------:|:-------:|:--------:|:----:|:------:|:---:|
| 安全性 | XX | XX | X | X | X | X |
| 架构 | XX | XX | X | X | X | X |
| 性能 | XX | XX | X | X | X | X |
| 错误处理 | XX | XX | X | X | X | X |
| 可观测性 | XX | XX | X | X | X | X |
| 数据完整性 | XX | XX | X | X | X | X |
| 可扩展性 | XX | XX | X | X | X | X |
| 死代码 | XX | XX | X | X | X | X |
| 测试 | XX | XX | X | X | X | X |
| 规范 | XX | XX | X | X | X | X |

**技术债务：** ~X 小时  **审查耗时：** X 分钟

---

## 维度详情

### 安全性

| 评分类型 | 分数 |
|---------|:---:|
| Agent评分 | XX |
| 校验评分 | XX |

**Agent 摘要：** {Agent summary}

**Critical 问题（X 个）**
1. **[SEC-001]** {title} — `file:line` — {effort}h {若有多项目，显示 `[{project_unit}]`}
   - Evidence: {evidence}
   - Recommendation: {recommendation}

**High 问题（X 个）**
…

**Medium 问题（X 个）**
…

**Low 问题（X 个）**
…

…其他维度…

---

## 优先级行动计划

### P0 · 立即处理（Critical）
1. **[SEC-001]** {title} — `file:line` — {effort}h {若有多项目，显示 `[{project_unit}]`}

### P1 · 短期（High）
…

### P2 · 中期（Medium）
…

### P3 · 长期（Low）
…

**总预估工作量：** X 小时

---

## 基线对比（仅 --baseline 模式）

**对比算法：**

1. 尝试加载上次 `{PROJECT_ROOT}/docs/review/baseline.json`
2. **若 baseline.json 不存在**：输出「📌 首次运行，本次结果已保存为基线。下次使用 `/project-review --baseline` 即可对比。」，跳过对比表格
3. **若 `baseline.review_dir` 与本次 `REVIEW_DIR` 不同**：输出「⚠️ 审查目录已变更（上次：{baseline.review_dir}，本次：{REVIEW_DIR}），对比结果可能不准确。」，继续对比但标注差异
4. **若项目单元变更**：对比 `baseline.project_units` 与本次 `PROJECT_UNITS`，输出差异说明（新增/删除/变更的项目单元）
5. 对每个维度计算 delta：`delta = current_score - baseline_score`
6. 若维度缺失（上次未审计或本次未审计），标记 `N/A`
7. 综合分数 delta = `current_total - baseline_total`

| 维度 | 上次Agent | 本次Agent | Δ Agent | 上次校验 | 本次校验 | Δ 校验 | 备注 |
|------|:--------:|:--------:|:------:|:-------:|:-------:|:----:|------|
| 安全性 | 78 | 82 | +4 ↑ | 50 | 55 | +5 ↑ | |
| 架构 | N/A | 75 | N/A | N/A | 40 | N/A | 上次未审计 |
| … |

{若项目单元变更，附加以下表格}

**项目单元变更详情：**

| 变更类型 | 项目单元 | 技术栈变更 |
|---------|----------|-----------|
| 新增 | ./module-c | node, vue |
| 删除 | ./module-old | - |
| 变更 | ./module-a | java → java, kotlin |
```

### 步骤 8 · 自动维护 .gitignore + 收尾提示

**自动追加 `docs/review/` 到项目根目录 `.gitignore`（幂等）：**

**关键说明：**
- `.gitignore` 必须位于项目根目录 `{PROJECT_ROOT}`，而非审查目录 `{REVIEW_DIR}`
- 输出目录 `docs/review/` 始终位于 `{PROJECT_ROOT}` 下，需要根目录的 `.gitignore` 来忽略
- 若 `{REVIEW_DIR}` 与 `{PROJECT_ROOT}` 不同，审查目录下的 `.gitignore` 不适用

1. `Read("{PROJECT_ROOT}/.gitignore")`，若不存在则准备新建；若存在但格式异常，发出警告后继续；发起前必须替换 `{PROJECT_ROOT}` 为项目根目录的绝对路径
2. 用 `Grep` 检查是否已包含 `docs/review` 相关条目（匹配 `docs/review` 或 `docs/review/`）
3. 若**未包含**，用 `Edit` 在文件末尾追加一行 `docs/review/`；文件不存在则 `Write` 新建，内容仅为 `docs/review/\n`
4. 若**已包含**则跳过，避免重复

完成后输出**一次性**提示：

```
✅ 已确保 .gitignore 忽略 docs/review/
📄 报告位置（{PROJECT_ROOT} 下）：
   docs/review/report.md       （完整报告）
   docs/review/baseline.json   （基线指标）
   docs/review/issues.json     （扁平问题列表）
   docs/review/.tmp/           （扫描中间产物，可安全删除）
🔁 下次用 `/project-review --baseline` 可对比本次结果
```

---

## 使用示例

```
/project-review                             # 全部 10 维度深度审查（当前目录）
/project-review --quick                     # 只做静态扫描（分钟级）
/project-review security                    # 仅安全维度
/project-review security error-handling observability  # 多维度（核心运维）
/project-review --run-tests                 # 允许跑测试（技术栈自动检测）
/project-review --baseline                  # 与上次结果对比（首次运行自动创建基线）
/project-review --dir src/main              # 只审查 src/main 目录
/project-review --dir ./modules/auth security  # 只审查 auth 模块的安全维度
/project-review --dir docs                  # 文档项目（自动检测为文档模式）
/project-review --max-files 200             # 大型项目限流，Agent 只检查 200 个关键文件
/project-review --weights security=0.3,architecture=0.25,performance=0.15,dead-code=0.10,testing=0.10,standards=0.10  # 自定义权重
```

---

## 硬性约束（违反即视为执行失败）

1. **不得**用 `find`/`cat` 做文件探测和内容读取；用 Glob/Read。
2. **不得**在未指定 `--run-tests` 时执行 `mvn test`/`go test`/`cargo test`/`npm test`/`pytest`/`cargo tarpaulin` 等会触发业务逻辑的命令。
3. **所有外部 CLI** 必须加统一超时包装（`timeout`/`gtimeout`/`python3` wrapper/`perl` wrapper）并把 stdout/stderr 分流到 `{PROJECT_ROOT}/docs/review/.tmp/`。
4. **10 个 Agent 分 3 批调度**：第一批 4 个（security + architecture + performance + error-handling），第二批 3 个（observability + data-integrity + scalability），第三批 3 个（dead-code + testing + standards），每批在单条消息内并行发起。
5. Agent prompt 必须自包含实际值，**不得**留 `{REVIEW_DIR}` 之类未替换占位符。
6. **立即输出原则**：Agent 返回后立即用 `Write` 保存结果并输出进度提示，**不得在内存中累积 Agent 返回内容**。
7. **从文件读取原则**：后续步骤（校验/评分/报告生成）必须从 `.tmp/*.json` 文件读取数据，**不得从内存读取**。
8. 三个最终文件必须用 Write 工具生成，不得用 `echo > file` 等 shell 方式。
9. 评分公式必须按步骤 6 的确定性算法，父级二次校验后**取更严苛**的分数。
10. **每个步骤完成后必须输出一行简短的进度提示**（如 `✅ security 完成`、`🔍 校验中…`），让用户了解执行进度。
