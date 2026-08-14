# testcase-creator · 项目级测试用例生成方案

> 先确认输入，不自动导入，不生成自动化测试代码。检查点和评审点可随项目经验持续沉淀。

---

## 文档地图

| 你想… | 看这里 |
|--------|--------|
| 安装 / 升级 / 仓库怎么维护 | **本文 README** |
| 纯对话工具（ChatGPT 等）怎么跑流程 | [`TESTCASE_GUIDE.md`](TESTCASE_GUIDE.md) |
| Cursor / Claude 实际执行细则（阶段、门禁、来源 I 等） | `skills/testcase-creator/`（`prompt.md` + `references/`） |
| 导出命令细则 | `skills/testcase-creator/references/export-workflow.md` |
| 版本变更 | [`CHANGELOG.md`](CHANGELOG.md) |

**约定：** 改流程与约束 → 只改 Skill；改对话体验 → 改 GUIDE；改装机与仓库说明 → 改 README。

---

## 最快体验

```bash
./init-testcase.sh _template .                # 构建最新 Skill 并初始化到当前目录
```

1. 编辑 `.testcase-assets/project.config.md`，去掉所有 `[填写…]` 占位符  
2. 在 Cursor / Claude Code 中输入 `/testcase-creator`  
3. 选 **A 全量** 或 **B 增量**，按提示确认各阶段  

> 初始化会重新构建 `dist/`。仅构建不安装时：`./build.sh`。

---

## 环境依赖

| 工具 | 用途 | macOS | Windows |
|------|------|-------|---------|
| Python 3.x | 导出与质检脚本 | 系统自带 | [python.org](https://python.org) |
| Python 包 | 构建、Excel、JSON 修复 | `python3 -m pip install -r requirements.lock` | `py -m pip install -r requirements.lock` |
| pdftotext | 读取 PDF（可选） | `brew install poppler` | WSL: `apt install poppler-utils` |
| XMind 8+ | 打开 .xmind（可选） | [xmind.app](https://xmind.app) | 同上 |

依赖版本锁定在 `requirements.lock`；导出脚本缺失时会按 lock 安装。

---

## 目录结构

```
.
├── skills/                 # Skill 统一源（只在这里改流程）
├── framework/              # 模板 + 导出/质检脚本
├── projects/               # 项目资产模板（_template / 各业务）
├── dist/                   # 构建产物（gitignore）
├── build.sh / build.py
├── init-testcase.sh / .ps1 # 安装到业务项目；--sync 升级
├── check_project_copies.py # projects/* 漂移检查 / --fix
├── sync-projects.sh
├── TESTCASE_GUIDE.md
└── CHANGELOG.md
```

### 统一源保护

`skills/` 与 `framework/` 是唯一修改源。不要直接改 `projects/*` 里的生成副本。

```bash
python3 check_project_copies.py              # 检查
python3 check_project_copies.py --fix --build  # 本仓库 projects/* 对齐
./sync-projects.sh
```

---

## 可用命令

| 命令 | 平台 | 用途 |
|------|------|------|
| `/testcase-creator` | Claude Code / Cursor | 全量生成或增量变更 |
| `/testcase-export` | 同上 | 已有定稿独立导出 |
| `source-command-testcase-*` | Codex | 同上 |

| 工具 | 怎么触发 |
|------|----------|
| Cursor / Claude Code | `/testcase-creator` |
| Codex | 说明运行 testcase-creator |
| ChatGPT 等 | 复制 `TESTCASE_GUIDE.md` + 项目三个资产文件 |

---

## 运行模式（摘要）

![用例生成 Skill 流程图](assets/testcase-skills-flow.png)

| 模式 | 路径 |
|------|------|
| **A 全量** | 输入(A–I) → 检查点/历史 → 生成 → 评审 → 定稿导出 |
| **B 增量** | 基线定稿 → 本次变更 → 影响分析 → 补/改/废 → 合并 → 评审或定稿 |

| 阶段 | 一句话 |
|------|--------|
| 1 输入 | 需求/设计/**代码(I)** 等，确认后建 `history/` 运行目录 |
| 2 结构化 | 检查点推荐 + 可选历史复用 → `0-用例准备.md` |
| 3 生成 | 正向/异常/边界/并发用例表 |
| 4 评审 | 分维度，可多轮；可跳过 |
| 5 导出 | 定稿 MD → 质检 → CSV / Excel / XMind |

- **来源 I（代码）**：须 path 或 git diff；推荐用法见 Skill `input-and-generation.md`。  
- **细则与话术**：对话工具看 [TESTCASE_GUIDE.md](TESTCASE_GUIDE.md)；Agent 执行看 `skills/testcase-creator/`。

优先级默认：P0=异常 / P1=正向·边界 / P2=并发 / P3=体验。

---

## 安装与升级

```bash
# 新装到业务项目
./init-testcase.sh _template /path/to/your-project

# 升级 Skill/脚本（保护 project.config、检查点、history）
./init-testcase.sh _template /path/to/your-project --sync

# 强制覆盖全部（含项目资产，慎用）
./init-testcase.sh _template /path/to/your-project --force
```

| 参数 | 说明 |
|------|------|
| 项目名或目录 | `projects/` 下名称，或资产目录路径 |
| 目标路径 | 业务工程根目录 |
| `--sync` | 升级托管文件，不覆盖业务资产 |
| `--force` | 全量覆盖 |

Windows：`.\init-testcase.ps1 -ProjectName _template -TargetDir <路径> [-Sync]`

### 常见维护

```bash
# 改 Skill 流程
vim skills/testcase-creator/prompt.md
vim skills/testcase-creator/references/*.md
./build.sh
./init-testcase.sh <项目> <目标> --sync

# 本仓库内新增业务资产目录
cp -r projects/_template projects/my-project
# 编辑 project.config / checkpoints 后 init 到目标工程
```

---

## 导出（常用）

主输入：`2-用例定稿.md`。推荐一键：

```bash
python3 .testcase-assets/scripts/export_all.py \
  <运行目录>/2-用例定稿.md --out-dir <运行目录> \
  --formats j,e,x --project "<项目名>" --module "<模块名>"

# 冒烟：仅 P0+P1 Excel
python3 .testcase-assets/scripts/export_all.py \
  <运行目录>/2-用例定稿.md --out-dir <运行目录> \
  --formats e --priority P0,P1 --project "<项目名>" --module "<模块名>"
```

完整命令、门禁、分步脚本、CSV 工具选项见  
[`export-workflow.md`](skills/testcase-creator/references/export-workflow.md)。  
脚本清单在业务项目 `.testcase-assets/scripts/`（init/sync 时从 `framework/scripts` 拷入）。

Jira 导入：阶段 5 选 J 或 `/testcase-export` 出 CSV → 项目内「从 CSV 导入」；编码选 UTF-8。

---

## 历史与资产

运行目录：`.testcase-assets/history/<YYYYMMDD_HHMMSS_模块>/`  
全量常见：`0-用例准备`、`1-评审记要`、`2-用例定稿`、导出物。  
增量另有：`0-变更分析`、`1-变更集`；定稿文首含变更摘要。

| 操作 | 规范 |
|------|------|
| 新增检查点 | 分类末尾追加，编号递增 |
| 废弃检查点 | 描述标注 `[已废弃]`，不删号 |
| history/ | 默认 gitignore，可按需追踪 |

---

*维护：改流程以 `skills/` 为准 · 见 CHANGELOG*
