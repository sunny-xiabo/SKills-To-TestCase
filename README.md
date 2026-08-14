# testcase-creator · 项目级测试用例生成方案

> 先确认输入，不自动导入，不生成自动化测试代码。检查点和评审点可随项目经验持续沉淀。

---

## 最快体验

```bash
./init-testcase.sh _template .                # 构建最新 Skill 并初始化到当前目录
```

然后在 Claude Code 或 Cursor 中输入 `/testcase-creator`，先选运行模式（全量新建或增量变更），再按提示完成流程。

> 初始化脚本每次都会重新构建 `dist/`，确保部署的是最新 Skill。仅需生成各平台产物、不执行初始化时，可单独运行 `./build.sh`。

---

## 环境依赖

| 工具 | 用途 | macOS | Windows |
|------|------|-------|---------|
| Python 3.x | 运行导出脚本 | 系统自带 | [python.org](https://python.org) |
| Python 包 | 构建、Excel、JSON 修复 | `python3 -m pip install -r requirements.lock` | `py -m pip install -r requirements.lock` |
| pdftotext | 读取 PDF（需求来源 D） | `brew install poppler` | WSL: `apt install poppler-utils` |
| XMind 8+ | 打开 .xmind | [xmind.app](https://xmind.app) | [xmind.app](https://xmind.app) |

> PyYAML、openpyxl 和 json-repair 的版本统一锁定在 `requirements.lock`。导出脚本发现依赖缺失或版本不一致时，也只安装锁定版本。

---

## 目录结构

```
.
├── skills/                        # 统一源文件，只在这里改 prompt/reference
│   ├── testcase-creator/          #   meta.yaml + prompt.md + references/
│   └── testcase-export/           #   meta.yaml + prompt.md
├── framework/                     # 通用框架（与业务无关）
│   ├── templates/                 #   用例表模板、列配置、CSV Schema
│   └── scripts/                   #   导出/质检脚本（MD→JSON/CSV/Excel/XMind）
├── projects/                      # 项目资产（按项目隔离）
│   ├── _template/                 #   新项目模板
│   └── <your-project>/            #   你的项目（project.config + checkpoints + reviews）
├── dist/                          # 构建产物（自动生成，gitignore）
├── build.sh / build.py            # 构建脚本
├── requirements.lock              # 锁定 Python 依赖版本
├── check_project_copies.py        # 检查/修复 projects/* 副本漂移（--fix）
├── sync-projects.sh               # 本仓库 projects/* 一键 build+对齐
├── init-testcase.sh / .ps1        # 一键初始化 / --sync 升级
├── TESTCASE_GUIDE.md              # 纯对话工具（ChatGPT 等）使用指南
└── CHANGELOG.md
```

### 统一源保护

`skills/` 和 `framework/` 是唯一修改源。构建后会自动扫描 `projects/*/.agents` 和
`projects/*/.testcase-assets/scripts`；发现项目副本被直接修改、缺少文件或多出文件时给出警告。

```bash
python3 check_project_copies.py           # 本地检查，仅警告
python3 check_project_copies.py --strict       # CI：漂移则失败
python3 check_project_copies.py --fix --build # 本仓库 projects/* 一键对齐
./sync-projects.sh                             # 同上
```

发现漂移时，请修改 `skills/*/prompt.md`、`skills/*/meta.yaml` 或 `framework/scripts/`，
再运行构建和初始化命令同步项目副本，不要直接修改 `projects/*` 中的生成文件。

---

## 可用命令

| 命令 | 平台 | 用途 |
|------|------|------|
| `/testcase-creator` | Claude Code / Cursor | 全量五阶段生成，或基于定稿的增量变更（补/改/废） |
| `/testcase-export` | Claude Code / Cursor | 从已有定稿导出（MD→质检/JSON→Jira CSV / Excel / XMind） |
| `source-command-testcase-creator` | Codex | 同上（Agent 技能） |
| `source-command-testcase-export` | Codex | 同上（Agent 技能） |

---

## 运行模式与流程

![用例生成 Skill 流程图](assets/testcase-skills-flow.png)

触发 `/testcase-creator` 并通过初始化检查后，先选择运行模式：

| 模式 | 说明 |
|------|------|
| **A. 全量新建** | 完整五阶段：输入 → 结构化 → 生成 → 评审 → 定稿导出 |
| **B. 增量变更** | 基于历史 `2-用例定稿.md`：变更输入 → 影响分析 → 补/改/废 → 合并全表 → 评审或定稿 |

也可自然语言直达，例如「增量改一下组织树」→ 模式 B。

### 增量变更（模式 B）摘要

1. 从 `history/` 选择基线定稿  
2. 只输入**本次变更**（可组合 A–I 来源：文字/设计/代码路径或 git diff 等）  
3. 输出影响分析，确认后再生成变更集  
4. **新增**续号、**修改**保号、**废弃**不进有效表（摘要中保留清单）  
5. 合并为完整有效表后，可进入评审或直接定稿导出；`history-index` 标注 `mode: 增量`

### 全量：1. 需求与设计 / 代码输入

支持 **九种**来源（A–I）：文字粘贴 / 乐享 / 接口文档 / 本地文件 / 图片 / 飞书 / Excel / Jira·Tapd·禅道 / **代码（路径或 git diff）**。

设计稿请导出为 PDF 或图片；代码须用 `scan_code_scope.py` 限定范围（禁止无范围全仓）。阶段一提取测试对象、业务规则、设计与**代码分析**，并标记需求/设计/代码差异。确认后创建运行子目录。不生成自动化测试代码。

### 全量：2. 输入结构化

- **检查点**：展示索引，并按需求/设计做推荐预勾；可「采用推荐 / 全选 / 自选 / 跳过」（须人确认）。
- **历史复用（可选）**：扫描近期 history 定稿，勾选后复用内容；本轮重新编号，映射写入 `0-用例准备.md`。
- 结果写入 `0-用例准备.md`。

### 全量：3. 用例生成

基于需求要素 + 设计稿要素（如有）+ **已确认代码分析（如有）** + 检查点（+ 可选历史复用），生成覆盖正向/异常/边界/并发四类的用例表，包含优先级列（P0-P3）。

> P0=异常场景（阻断） / P1=正向主流程/边界 / P2=并发 / P3=体验类

### 4. 评审优化

按 UX/DATA/COMP/EXEC/BUG/SEC/PERF 等维度评审（优先并行 subagent，不支持时串行），支持多轮增量迭代，每轮生成独立评审报告。

### 5. 定稿导出

写入 `2-用例定稿.md`（增量模式文首含变更摘要），支持三种导出格式：

| 选项 | 格式 | 特点 |
|------|------|------|
| J | Jira CSV | UTF-8 BOM 编码，可直接导入 Jira |
| E | Excel (.xlsx) | 场景颜色、冻结表头、优先级着色、统计 Sheet |
| X | XMind (.xmind) | 四级结构：检查点 → 场景类型 → 用例 → 步骤 |

导出链路以 **Markdown 定稿为主输入**：

```text
2-用例定稿.md
  → testcase_quality.py     → audit-summary.md
  → md_to_json.py           → export_data.json  → Excel / XMind
  → md_to_csv.py            → jira_export.csv
```

不要手写整份 `export_data.json`。质检覆盖重复 ID、核心空值、非法枚举、步骤编号、模糊措辞、术语和引号。

---

## 详细上手

### 安装到你的项目

```bash
# macOS / Linux
./init-testcase.sh <项目名称或目录> <目标路径>

# 示例：用模板初始化新项目
./init-testcase.sh _template /path/to/your-project

# 也可以直接传入项目资产目录
./init-testcase.sh ./projects/_template /path/to/your-project

# 旧项目升级到最新 Skill / 脚本（推荐；不覆盖项目资产）
./init-testcase.sh _template /path/to/your-project --sync

# 强制覆盖全部文件（含 project.config / 检查点，慎用）
./init-testcase.sh _template /path/to/your-project --force
```

| 参数 | 说明 |
|------|------|
| `<项目名称或目录>` | `projects/` 下的子目录名（如 `_template`），或项目资产目录路径 |
| `<目标路径>` | 你要安装到的实际项目目录（绝对路径） |
| `--sync` | **升级模式**：覆盖 Skill、导出脚本、模板、指南与权限配置；**保护** `project.config` / 检查点 / 评审点 / history |
| `--force` | 覆盖全部目标文件（含项目资产） |

脚本会自动完成：复制 skill 文件、框架模板、导出脚本、项目资产，生成 `.claude/settings.local.json`，写入 `.testcase-assets/FRAMEWORK_VERSION`，初始化 history 目录，追加 `.gitignore` 规则。

> 从 1.8 升到 1.9+ 时，请用 **`--sync`**，不必 `--force`。只有需要重置模板项目资产时才用 `--force`。

### 安装到当前目录（在本仓库内使用）

```bash
./init-testcase.sh _template .
```

### 各工具触发方式

| 工具 | 操作 |
|------|------|
| **Cursor** | 输入 `/testcase-creator` |
| **Claude Code** | 输入 `/testcase-creator`（确保 `.claude/settings.local.json` 路径正确） |
| **Codex** | 直接说明「运行 testcase-creator」|
| **ChatGPT 等** | 复制 `TESTCASE_GUIDE.md` + 三个资产文件到对话开头 |

---

## 常见操作

### 添加新项目

```
源仓库 (skills-to-testcase/)          目标项目 (your-project/)
├── projects/                          ├── .testcase-assets/
│   └── my-project/                    │   ├── checkpoints-index.md  ← 从这里复制
│       ├── project.config.md          │   ├── project.config.md
│       ├── checkpoints-index.md       │   ├── history/              ← 运行时生成
│       └── review-expectations-index.md│  └── ...
└── ...                                └── ...
```

```bash
cp -r projects/_template projects/my-project    # 复制模板
vim projects/my-project/project.config.md        # 填写项目信息
vim projects/my-project/checkpoints-index.md     # 补充检查点
./build.sh                                        # 构建
./init-testcase.sh my-project /path/to/target     # 安装
```

### 修改 skill 流程

```bash
vim skills/testcase-creator/prompt.md     # 编辑流程入口和强制约束
vim skills/testcase-creator/references/*.md  # 编辑阶段细节
./build.sh                                # 重新构建
./init-testcase.sh <项目名> <目标路径> --sync  # 升级 Skill/脚本（保护项目资产）
```

### 更新项目资产

```bash
vim projects/<项目名>/checkpoints-index.md      # 添加检查点
./init-testcase.sh <项目名> <目标路径>            # 重新安装（不会覆盖已有文件）
```

---

## 历史记录

每次运行创建独立子目录：

```
.testcase-assets/history/
├── history-index.md                      # 自动追加索引（增量含 mode / 基线）
├── 20260601_174203_碳盘查清单/           # 全量：日期_时间_模块名
│   ├── 0-用例准备.md                     # 需求/设计/检查点/复用映射
│   ├── 1-评审记要.md
│   ├── 1-评审报告-第N轮.md
│   ├── 2-用例定稿.md
│   ├── export_data.json                  # 由 md_to_json.py 生成
│   ├── audit-summary.md
│   └── jira_export.csv / testcases.xlsx / testcases.xmind
├── 20260813_100000_组织树迭代/           # 增量示例
│   ├── 0-变更分析.md
│   ├── 1-变更集.md                       # 新增 / 修改 / 废弃
│   ├── 1-评审记要.md                     # 合并后的完整有效表
│   └── 2-用例定稿.md                     # 文首含变更摘要
└── ...
```

---

## 资产管理规范

| 操作 | 规范 |
|------|------|
| 新增检查点 | 追加到分类末尾，编号递增，不修改已有编号 |
| 废弃检查点 | 描述后标注 `[已废弃]`，不删除 |
| Git 提交 | `chore: 沉淀检查点 XX-XX` |
| history/ 目录 | 已加入 `.gitignore`，可按需调整 |

---

## 导出格式详情

**主输入始终是 `2-用例定稿.md`。** 推荐一键导出：

```bash
# 环境 + 版本体检 / 阶段门禁（Skill 启动与关键阶段会跑）
python3 .testcase-assets/scripts/check_environment.py --strict
python3 .testcase-assets/scripts/gate_stage.py --stage init
# 导出后：gate_stage.py --stage export --run-dir <运行目录> --formats j,e,x

# 一键：质检 → JSON → CSV + Excel + XMind
python3 .testcase-assets/scripts/export_all.py \
  <运行目录>/2-用例定稿.md --out-dir <运行目录> \
  --formats j,e,x --project "<项目名>" --module "<模块名>"

# 冒烟子集（仅 P0+P1）
python3 .testcase-assets/scripts/export_all.py \
  <运行目录>/2-用例定稿.md --out-dir <运行目录> \
  --formats e --priority P0,P1 --project "<项目名>" --module "<模块名>"

# 分步仍可用：质检 / md_to_csv / md_to_json / export_excel / export_xmind
# CSV 多工具：md_to_csv.py ... --tool jira|tapd|zentao
# 增量合并：merge_cases.py --baseline 旧定稿.md --changeset 1-变更集.md --output 1-评审记要.md
```

| 脚本 | 作用 |
|------|------|
| `check_framework_version.py` | 检查 FRAMEWORK_VERSION 是否落后 |
| `check_environment.py` | 环境能力体检（依赖/版本/可选工具） |
| `gate_stage.py` | 阶段产物门禁（init/prepare/merge/draft/export） |
| `recommend_checkpoints.py` | 检查点规则推荐（可解释） |
| `recommend_history.py` | 历史复用两级召回 |
| `scan_code_scope.py` | 来源 I：限定范围扫描代码（路径/diff） |
| `export_all.py` | 一键质检+导出；支持冒烟子集 |
| `merge_cases.py` | 增量变更集合并与校验 |
| `suggest_assets_from_bugs.py` | 缺陷 → 检查点/评审点候选 |
| `testcase_common.py` | 共用解析与优先级规则 |
| `testcase_quality.py` | 内容质量检查与 `audit-summary.md` |
| `md_to_json.py` | 定稿 MD → `export_data.json` |
| `md_to_csv.py` | 定稿 MD → Jira / Tapd / 禅道 CSV |
| `export_excel.py` / `export_xmind.py` | JSON → Excel / XMind |

### CSV（Jira / Tapd / 禅道）

- 编码 UTF-8 with BOM；默认 Jira 列，可用 `--tool tapd|zentao`
- Jira 优先级：P0→High, P1→Medium, P2/P3→Low；缺省并发→Low（P2）

### Excel

- 步骤/预期规范化与自适应行高、执行状态下拉、编写人默认
- 场景类型切换彩色上边框分隔；优先级着色；统计 Sheet（场景/优先级/模块）

### XMind

- Sheet1：检查点 → 场景类型 → 用例（标题含优先级）→ 步骤
- Sheet2：按模块 → 优先级 → 用例
- Sheet3：统计总览（场景 / 优先级 / 模块）
- 优先级显示为用例节点标签，Sheet 2 为统计总览

---

## Jira CSV 导入

1. 运行流程至阶段 5，选择 J 生成 CSV（或用 `/testcase-export` 独立导出）
2. Jira Cloud：项目设置 → Issue Types → Import Issues from CSV
3. Jira Server：项目 → 导入与导出 → 从 CSV 导入
4. 上传 CSV，按向导完成字段映射

| CSV 列 | Jira 字段 |
|--------|-----------|
| 序号 | Issue Key |
| 标题 | Summary |
| 描述 | Description |
| 优先级 | Priority |
| 步骤ID / 步骤 / 测试数据 / 期望结果 | Test Steps（需 Xray / Zephyr 插件） |
| 需求 | Labels / 自定义字段 |
| 测试用例集 | Component / 自定义字段 |

> 中文乱码：选择 UTF-8 编码导入。多步骤用例需 Xray 或 Zephyr Scale 插件支持。

---

*由 testcase-creator skill 维护 · 最后更新：2026-08-13*
