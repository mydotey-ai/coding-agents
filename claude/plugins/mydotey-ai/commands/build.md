---
description: 构建项目并组织成标准应用安装包（tar.gz），内含 bin/app.sh 用于运行维护。支持 Java/Maven/Gradle/Node.js 项目。
argument-hint: "[module]"
allowed-tools: ["Bash", "Read", "Write", "Edit", "Glob", "Grep"]
---

# build

构建项目并组织成标准应用安装包（tar.gz），内含 bin/app.sh 用于运行维护。

## 执行步骤

### 1. 检测项目结构

首先读取 `CLAUDE.md` 或 `AGENTS.md` 了解项目构建约定（如有）。若已有足够构建说明，则仅验证其准确性；若不足或缺失，则自动检测补充：

- **Java (Maven)**：查找 `pom.xml`，识别模块列表（`<modules>`），版本号用 `mvn help:evaluate -Dexpression=project.version -q -DforceStdout` 获取
- **Java (Gradle)**：查找 `build.gradle` 或 `build.gradle.kts`，识别子项目列表（`settings.gradle` 中的 `include`），版本号用 `gradle properties | grep "^version:" | cut -d' ' -f2` 获取（优先 `gradle`，无则 `./gradlew`）
- **Node.js/前端**：查找 `package.json`，版本号从 `.version` 提取

**多模块项目识别可执行模块：**

Maven 多模块项目，构建全部模块，但只有可执行模块才组织打包。通过以下方式识别：

- 检查各模块 `pom.xml` 中是否含 `spring-boot-maven-plugin`、`maven-shade-plugin`、`maven-assembly-plugin`
- 或检查 `pom.xml` 的 `<packaging>` 是否为 `jar` 且含 `Main-Class` 清单

Gradle 多模块项目，构建全部子项目，只有可执行子项目才组织打包：

- 检查各子项目 `build.gradle` 中是否含 `application` 插件、`spring-boot` 插件、或 `shadow` 插件
- 或检查是否设置了 `mainClassName`

### 2. 构建源码

先检查所需工具是否存在，缺失则提示安装后退出。Gradle 项目优先使用系统 `gradle` 命令，若不存在则使用 `./gradlew`。

清除 `build/` 目录（打包输出目录），然后根据项目类型执行构建：

#### Java (Maven)

```bash
mvn clean package -DskipTests -q
```

多模块项目：父 pom 执行上述命令，构建全部模块。若用户指定了 `{module}`，则追加 `-pl {module} -am`。

#### Java (Gradle)

```bash
gradle clean build -x test -q
```

若系统无 `gradle`，改用 `./gradlew clean build -x test -q`。
多模块项目：根项目执行上述命令，构建全部子项目。若用户指定了 `{module}`，则用 `:{module}:build` 只构建该子项目及其依赖。

#### Node.js/前端

```bash
npm ci --silent && npm run build
```

若项目无 `package-lock.json`，改用 `npm install --silent && npm run build`。

### 3. 组织应用目录

创建标准目录结构，确保 `logs/` 和 `data/` 已通过 `mkdir -p` 创建。

**后端 (Java)：**

```text
build/{module}/
├── bin/
│   └── app.sh          # 运行维护脚本
├── config/
│   ├── application.yml # 从 src/main/resources/ 复制
│   ├── env.sh          # 环境变量（JAVA_OPTS 等）
│   └── ...             # 其他配置文件
├── lib/
│   ├── {module}.jar    # 可执行 jar
│   └── version         # 版本信息文件
├── logs/               # 空目录，运行时写日志
├── data/               # 空目录，运行时数据
└── {module}.service    # systemd 单元文件
```

**前端 (Node.js)：**

```text
build/{module}/
├── bin/
│   └── app.sh          # 运行维护脚本
├── config/
│   └── env.sh          # 环境变量（PORT 等）
├── lib/
│   ├── dist/               # 前端构建产物 + express 生产运行时
│   │   ├── node_modules/   # express 依赖
│   │   └── server.js       # express 静态文件服务器
│   └── version             # 版本信息文件
├── logs/                   # 空目录，运行时写日志
└── {module}.service        # systemd 单元文件
```

各类型产物放置：

#### Maven 产物放置

- `target/{module}-{version}.jar` → `lib/{module}.jar`
- `src/main/resources/` 下的 `.yml`、`.properties`、`.xml` 等配置文件递归复制 → `config/`（含子目录中的文件）
- 依赖 jar：若项目配置了 `maven-dependency-plugin:copy-dependencies`，则从 `target/lib/` 复制 → `lib/`；否则 Spring Boot fat jar 已包含依赖，跳过此步

#### Gradle 产物放置

- `build/libs/{module}-{version}.jar` → `lib/{module}.jar`
- `src/main/resources/` 下的配置文件递归复制 → `config/`
- 依赖 jar：若使用 `application` 插件，从 `build/install/{module}/lib/` 复制 → `lib/`；若 Spring Boot fat jar，跳过

#### Node.js 产物放置

- 项目根目录下的 `dist/` → `lib/dist/`
- 在 `lib/dist/` 下安装 express 生产运行时：`cd lib/dist && npm install --omit=dev express`

### 4. 生成运维脚本

生成 `bin/app.sh`，提供标准生命周期命令：

```text
run        前台运行（适合 systemd / 容器）
start      后台启动
stop       优雅停止
restart    重启
status     查看进程状态
logs       查看日志 (tail -f)
version    查看版本信息
install    安装 systemd 服务
uninstall  卸载 systemd 服务
help       帮助
```

脚本根据项目类型自动适配启动命令。app.sh 需在启动前 `cd` 到 `$APP_HOME`（`bin/` 的上级目录），确保相对路径正确：

- **Java**: `java $JAVA_OPTS -jar lib/{module}.jar`
- **Node.js**: `node lib/dist/server.js`

生成 `{module}.service` systemd 单元文件，放在 `build/{module}/{module}.service`。

生成 `config/env.sh`，存放可编辑的环境变量（`JAVA_OPTS`、`PORT` 等）。

**Node.js 项目额外生成 `lib/dist/server.js`**：一个 express 静态文件服务器，读取 `config/env.sh` 中的 `PORT` 和 `API_BASE_URL`，通过 `/config.js` 端点注入前端配置，其余请求 serve 静态文件，fallback 返回 `index.html`。

### 5. 生成版本文件

生成 `lib/version`：

```text
VERSION={version}
BUILD_TIME={ISO8601}
```

所有项目类型（Java、Node.js）都要生成。

### 6. 打包

```bash
cd build && tar czf {module}-{version}.tar.gz {module}/ && md5sum {module}-{version}.tar.gz
```

输出产物路径、大小和 MD5。

### 7. gitignore

确保 `.gitignore` 包含以下条目：

```gitignore
build/
target/
```

`build/` 为打包暂存目录，`target/` 为 Maven 编译输出，每次构建重新生成，不应提交。

## 参数

- `{module}`：指定构建的模块名（多模块项目）。不指定则构建全部可执行模块。

## 注意事项

- 多模块 Java 项目：构建全部模块，打包时自动识别可执行模块，每个可执行模块独立打包
- 前端项目：自动注入 express 静态文件服务器（server.js）用于生产部署
- 构建前清除 build 目录，确保干净打包
- 生成的运维脚本（app.sh、env.sh、service、server.js）是模板，可放入项目源码目录（如 `deploy/templates/`）纳入 git 管理，后续按需修改。每次构建时从模板目录复制到 `build/{module}/` 下
