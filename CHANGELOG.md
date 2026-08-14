# Changelog

All notable changes to this project will be documented in this file.

---

## [1.12.0] - 2026-08-14

### Added

- **阶段 1 来源 I：代码**（方案 A）
  - 支持限定**目录/文件路径**和/或 **git diff** 作为输入，可与文字需求、设计稿组合
  - 新增 `scan_code_scope.py`：强制范围、列清单与摘录、轻量线索；输出扫描稿供分析
  - 确认稿增加「代码分析」「需求与代码差异」「输入完备性·代码」行
  - 准备文档增加「代码要素」；阶段 3 须覆盖已确认代码点
  - 增量 B2 同样支持代码/diff 作为变更输入
  - 来源 I **推荐用法**（diff/小路径、A+I、确认前改稿、避开 utils、多轮补扫）

### Changed

- testcase-creator **1.12.0**
- 来源列表由 A–H 扩展为 **A–I**；禁止无范围全仓扫描；不生成自动化测试代码

### Docs

- `input-and-generation.md` / `prompt.md` / `change-workflow.md` / README / TESTCASE_GUIDE
- **README 瘦身**：文档地图 + 装机/升级入口；流程与导出细则改指向 Skill / GUIDE / export-workflow
- **TESTCASE_GUIDE**：文首明确「纯对话操作」边界，有脚本环境以 Skill 为准

## [1.11.0] - 2026-08-14

### Added

- **环境体检** `check_environment.py`：Python/依赖/版本/资产目录；pdftotext 等可选能力 WARN 降级
- **阶段门禁** `gate_stage.py`：`init|prepare|merge|draft|export`，只认产物与 `[GATE OK]`
- **阶段回执模板**：关键阶段须贴命令、退出码、产物与门禁结果
- **检查点推荐脚本** `recommend_checkpoints.py` + `templates/recommend-rules.yaml`（可解释命中原因）
- **历史两级召回** `recommend_history.py`：先目录后用例
- 阶段 1 **输入完备性表**（OK / 降级 / 失败）

### Changed

- testcase-creator **1.11.0**，testcase-export **1.9.0**
- 初始化 / 增量合并 / 导出工作流强制 gate；推荐与历史复用优先走脚本

### Docs

- README / TESTCASE_GUIDE / CHANGELOG 同步 1.11

## [1.10.0] - 2026-08-14

### Added

- **P0 版本体检与一键对齐**
  - `framework/scripts/check_framework_version.py` + `framework_versions.py`：对照期望版本检查 `FRAMEWORK_VERSION`
  - Skill 初始化强制版本体检，落后则提示 `--sync` / `--fix`，不继续生成
  - `check_project_copies.py --fix`（可选 `--build`）：对齐 `projects/*` 的 Skill/脚本/模板
  - `./sync-projects.sh`：本仓库一键 build+fix
- **P1 一键导出与冒烟子集**
  - `export_all.py`：质检 → JSON → J/E/X 编排
  - 支持 `--priority` / `--module-filter` / `--ids` 过滤；子集产出 `*-smoke.*`
- **P2 增量合并脚本**
  - `merge_cases.py`：基线 + 变更集 → 有效全表，校验撞号/错号/废弃
  - 增量工作流要求 **必须** 用脚本合并，禁止 Agent 手搓全表
- **P3 周边增强**
  - `suggest_assets_from_bugs.py`：缺陷列表 → 检查点/评审点候选（人确认后写入）
  - `md_to_csv.py --tool jira|tapd|zentao` 多工具 CSV
  - XMind：用例标题带优先级；新增「按模块」Sheet；统计含优先级/模块分布

### Changed

- testcase-creator **1.10.0**，testcase-export **1.8.0**
- export-workflow / export Skill：推荐 `export_all`；CSV 多工具说明
- init 权限列表补充新脚本

### Docs

- README / TESTCASE_GUIDE / CHANGELOG 同步 1.10 命令与能力

### Tests

- 覆盖版本检查、export_all 过滤、merge_cases、多工具 CSV、缺陷候选、--fix 契约

## [1.9.1] - 2026-08-14

### Added

- **Excel 观感优化（export_excel）**
  - 步骤/预期编号列表规范化（去空行、统一 `1.` 前缀，支持同行多编号拆分）
  - 行高按步骤 + 预期 + 前置 + 测试点折行估算，并设最大行高上限
  - 执行状态下拉：`未执行 / 通过 / 失败 / 阻塞 / 跳过`，默认「未执行」
  - 失败/阻塞/通过/跳过状态列条件格式浅色提示
  - 默认编写人：`meta.author` / `--author` / `project.config`「测试负责人」
  - 摘要行标签化：`项目：` / `模块：` / `共 N 条` / `日期：`
  - 统计 Sheet 增加优先级分布、所属模块分布（Top 12 + 其他）
- **旧项目升级：`--sync` / `-Sync`**
  - 升级 Skill、导出脚本、模板、TESTCASE_GUIDE、settings，**不覆盖** `project.config` / 检查点 / 评审点 / history
  - 写入 `.testcase-assets/FRAMEWORK_VERSION` 版本戳
  - Claude permissions 补充 `md_to_json.py`

### Changed

- testcase-creator **1.9.1**，testcase-export **1.7.0**
- 列宽微调（步骤略加宽、ID/模块略收）

### Docs

- README：安装参数表补充 `--sync`；导出说明补充 Excel 执行列与统计维度
- 初始化完成提示改为推荐 `--sync` 升级，而非一律 `--force`

### Tests

- 新增 Excel 规范化/下拉/统计断言，以及 init 脚本 `--sync` 契约检查

## [1.9.0] - 2026-08-13

### Added

- **增量变更模式（testcase-creator）**
  - 启动时可选「全量新建 / 增量变更」
  - 新增 `references/change-workflow.md`：选基线定稿 → 变更输入 → 影响分析确认 → 补/改/废变更集 → 合并全表
  - 新增编号续号、修改保号、废弃不进有效表、history-index 标注 `mode: 增量`
- **检查点推荐与历史复用（全量阶段 2）**
  - 2a：按域/关键词预推荐检查点，快捷「采用推荐」，须人确认
  - 2b：扫描近期 history 定稿供勾选复用；本轮重编号，映射写入 `0-用例准备.md`
- **MD→脚本导出链路**
  - 新增 `framework/scripts/testcase_common.py`：共用 MD 解析、优先级规则、排序、JSON 容错加载
  - 新增 `framework/scripts/md_to_json.py`：定稿 MD 生成 `export_data.json`
  - Excel/XMind 主路径改为 `md_to_json`，禁止 Agent 手写整份 JSON

### Changed

- 并发缺省优先级与文档对齐：场景「并发」→ **P2**，Jira 映射 **Low**（修复 `md_to_csv` 误映射为 High）
- `md_to_csv` / `testcase_quality` / `export_excel` / `export_xmind` 共用 `testcase_common`
- 评审支持无 subagent 时按维度串行降级；token 统计改为可读则记、读不到不阻断
- testcase-creator 升级至 **1.9.0**，testcase-export 升级至 **1.6.0**

### Tests

- 新增 `tests/test_export_pipeline.py`（MD→JSON/CSV、优先级、Skill 契约）
- 修正 pytest 将 `testcase` 工厂函数误识别为测试用例的问题

### Docs

- `README.md`：运行模式 A/B、增量摘要、history 文件约定、MD 导出命令与脚本表；流程图注明以正文为准
- `TESTCASE_GUIDE.md`：对齐 1.9（模式选择、增量 B1–B4、检查点推荐/历史复用、MD 主路径导出与话术）

## [1.8.0] - 2026-07-23

### Added

- 新增 `testcase_quality.py`，检查重复 ID、必填空值、非法枚举、步骤编号、步骤与预期对应、模糊措辞、术语和引号
- 导出时生成 `audit-summary.md`，汇总模块、场景、空值、异常字段及 Excel 公式错误
- 新增 `requirements.lock`，固定 PyYAML、openpyxl 和 json-repair 版本

### Changed

- 将 testcase-creator 的输入读取、评审和导出细节拆分到按阶段加载的 `references/`
- 构建和初始化脚本递归发布 Skill reference，Windows 初始化统一使用 `dist/`、`framework/` 源
- testcase-creator 升级至 1.8.0，testcase-export 升级至 1.5.0

## [1.7.1] - 2026-07-23

### Added

- 新增项目副本漂移检查，比较 `projects/*/.agents` 与 Skill 构建产物、项目导出脚本与 `framework/scripts/`
- 构建完成后自动给出漂移警告，并提供 `--strict` 模式供 CI 阻断直接修改项目副本

## [1.7.0] - 2026-07-23

### Added

- **阶段 1 新增设计稿导出文件分析**
  - 设计稿 PDF 使用来源 D，PNG/JPG 等导出图片使用来源 E，可与其他需求来源组合输入
  - 提取页面流程、组件字段、交互状态、校验反馈等设计要素
  - 交叉检查需求与设计的缺失、冲突及补充项，并将结果带入阶段 2
  - PDF 设计稿同时执行文字提取与页面渲染检查，不仅依赖文本层判断布局和交互
- 新增备注策略回归测试，验证生成用例备注留空且独立导出保留已有备注

### Changed

- 初始化前强制重新构建 `dist/`，避免部署过期 Skill
- 初始化项目参数同时支持名称、相对目录和绝对目录
- `framework/` 成为导出脚本和模板的唯一来源，移除 `_template` 中的重复副本
- 统一用例表和导出 JSON 的 `module`、`remark` 字段，并让 Jira CSV 按表头解析列
- `testcase-creator` 生成的用例备注强制留空；替换或合并已有 Excel 时，仅保留非目标模块原有备注
- 公共导出脚本继续按输入导出已有备注，确保独立 `testcase-export` 行为不受影响

## [1.6.1] - 2026-07-08

### Changed

- **`export_excel.py` / `export_xmind.py` 自动按用例ID全局排序**
  - 读取 JSON 后自动按 TC-XXX 编号升序排列（TC-001 < TC-001a < TC-002）
  - Excel 行顺序改为全局排序，不再按场景类型分组打乱编号顺序
  - 保留场景类型颜色区分和类型切换时的视觉分隔线

---

## [1.6.0] - 2026-07-07

### Added

- **Excel 导出新增「所属模块」列（`export_excel.py`）**
  - 列定义从 12 列扩展到 13 列，在「用例ID」后插入「所属模块」
  - 自动读取 JSON 中 `module` 字段
  - 便于测试人员按模块筛选、分配执行任务

- **Excel「备注」列支持预填（`export_excel.py`）**
  - 备注列从固定空白改为读取 JSON 中 `remark` 字段
  - 支持在生成 JSON 时预填执行指引（如"需Chrome DevTools限速""需两个独立浏览器会话"）
  - 无预填内容则留空，不影响常规用例

### Changed

- **`_template` 目录补全**
  - 新增 `scripts/`，包含 `export_excel.py`、`export_xmind.py`、`md_to_csv.py`
  - 新增 `templates/`，包含 `csv-schema.json`、`jira-csv-template.csv`、`testcase-table-config.json`、`testcase-table.md`
  - 新项目初始化时自动从模板拷贝，保证脚本版本一致

---

## [1.5.0] - 2026-06-11

### Added

- **JSON 格式自检机制**
  - Skill Prompt 新增步骤 A2「强制自检 JSON 格式」，LLM 写入 `export_data.json` 后自动运行 `json.load()` 校验
  - 校验失败时 LLM 读取错误信息，自行定位并修正格式问题，循环直到通过
  - 涵盖 8 类常见错误：单引号、尾逗号、未转义双引号、Python 字面量、BOM、真实换行/Tab、未转义反斜杠、数字前导零

- **导出脚本容错加载（`load_json_robust` + `json_repair`）**
  - `export_excel.py` 和 `export_xmind.py` 使用 [json_repair](https://pypi.org/project/json-repair/) 库替换手写容错逻辑
  - 覆盖 12 类格式错误：单引号、尾逗号、`None`/`True`/`False`、BOM、注释、未转义双引号、未转义反斜杠、真实换行/Tab、数字前导零
  - 快速路径：标准 JSON 直接通过，无额外开销；非法 JSON 自动修复
  - 加载成功后自动写回规范 JSON，确保磁盘文件始终符合严格格式
  - 依赖（`json-repair`、`openpyxl`）首次运行时自动安装，无需手动执行 pip install

### Changed

- **JSON 格式校验由外部脚本改为 LLM 自检**
  - 移除手写 `load_json_robust`（`re`/`ast`），改用 `json_repair` 库
  - 移除 `fix_json.py`（功能已内置到导出脚本的 `load_json_robust` 和 Prompt 的自检循环中）
  - JSON 格式问题由 LLM 自行诊断修复，不再依赖独立工具

---

## [1.4.0] - 2026-06-09

### Added

- **统一源格式**
  - 新增 `skills/` 目录，包含 `meta.yaml`（元数据+平台配置）和 `prompt.md`（唯一的内容源）
  - 修改 prompt 只需改一个文件，构建自动生成三种平台格式
  - 消除三套文件（Claude/Cursor/Agents）的重复维护

- **多项目资产分离**
  - 新增 `framework/` 目录，存放通用框架（templates / scripts / 维度定义）
  - 新增 `projects/` 目录，按项目隔离资产（checkpoints / reviews / config）
  - 支持 `_template` 模板，新项目只需复制模板并填写内容
  - 已有项目：`crrc-esg`（中车ESG）、`carbon-audit`（碳盘查）

- **构建脚本**
  - 新增 `build.py`（Python 构建脚本），从统一源生成三种平台格式
  - 新增 `build.sh`（Shell 包装脚本），调用 build.py
  - 支持 `--clean` 参数清理 dist 目录

- **安装脚本升级**
  - `init-testcase.sh` 改版，支持指定项目名称：`./init-testcase.sh <项目名> <目标路径>`
  - 自动从 `dist/` 复制 skill 文件
  - 自动从 `framework/` 复制通用框架文件
  - 自动从 `projects/<项目名>/` 复制项目资产
  - 支持 `--force` 参数强制覆盖已有文件

### Changed

- **目录结构重构**
  - 原 `.testcase-assets/` 拆分为 `framework/` + `projects/`
  - 原 `.agents/`、`.cursor/`、`.claude/` 改为从 `dist/` 生成
  - `dist/` 目录加入 `.gitignore`

- **文档更新**
  - `README.md` 更新目录结构和快速上手指南
  - 新增多项目使用说明

---

## [1.3.0] - 2026-06-08

### Added

- **阶段 1 需求来源扩展**
  - 新增 E：图片/截图（.png/.jpg/.jpeg/.gif/.webp），支持 UI 设计稿、原型图、流程图识别
  - 新增 F：飞书文档链接（feishu.cn / larksuite.com）
  - 新增 G：Excel 需求列表（.xlsx/.xls），通过 openpyxl 解析
  - 新增 H：需求管理工具链接（Jira / Tapd / 禅道）
  - 所有 3 个 skill 文件（agents / claude / cursor）同步更新

- **Cursor 版 testcase-export skill**
  - 新增 `.cursor/skills/testcase-export/skill.md`，Cursor 用户可使用 `/testcase-export` 独立导出
  - init 脚本（sh / ps1）同步更新，自动复制到目标项目

- **TESTCASE_GUIDE.md 快速触发话术扩展**
  - 新增 6 种触发场景：完整流程、仅评审、仅导出、追问补充、资产沉淀、快速生成
  - 纯对话工具用户可直接复制对应话术启动不同场景

- **阶段 4 评审升级为双人 subagent 并行评审**
  - 同时启动 2 个隔离上下文的 subagent 独立评审，模拟「两个人分别审」
  - 共识问题直接采纳，分歧问题标记「待确认」供用户判断
  - 合并报告包含：评审员 A 报告 + 评审员 B 报告 + 合并结论
  - 三个 skill 文件（agents / claude / cursor）同步更新

- **TESTCASE_GUIDE 阶段 4 角色扮演双人评审**
  - 纯对话工具无法启动 subagent，改用「评审员 A（严格派）+ 评审员 B（实用派）」角色扮演模式
  - 两轮评审后合并结论，共识项直接采纳，分歧项标记待确认

- **占位符校验强制阻断**
  - 检测到 `[填写` 开头的占位符时直接中止流程，不再提供「是否继续」选项
  - 必须填写完整后才能进入阶段 1，避免生成无效用例

- **用例表模板配置化**
  - 新增 `testcase-table-config.json` 列配置文件，定义 8 个必填列 + 6 个可选列
  - 用户可通过编辑配置文件自定义列结构、顺序和格式
  - 可选列：关联评审点 / 执行人 / 执行状态 / 备注 / 自动化标记 / 所属模块
  - 三个 skill 文件同步更新，阶段 3 自动读取配置生成用例表

- **Token 消耗提示**
  - 全部 5 个 skill 文件（testcase-creator / testcase-export / cursor / agents）流程结束时增加 `[TOKEN]` 提示，提醒用户查看终端底部 token 统计

### Fixed

- **跨平台一致性全面修复**
  - agents/claude export 文件补充多步骤用例处理规则和 P3→Low 优先级映射
  - agents/claude creator 阶段1补充 Windows PDF 替代命令（pdfplumber）
  - agents/claude creator 阶段0补充「常用导出路径」上下文字段
  - cursor creator 阶段4步骤编号重复修复（两个"4."改为"4./5."）
  - 三个 creator 文件评审后选项统一为 5 个（A-E），新增「仅接受共识项」选项
  - README.md 优先级映射补充 P3→Low

- **Cursor 版 testcase-creator 一致性修复**
  - 移除不存在的 `/checkpoint-init` 命令引用
  - 补充 Jira CSV 多步骤用例处理规则和优先级映射说明
  - 占位符校验补充 `[填写姓名]` 和 `[填写团队共享路径]` 检查

- **P3 优先级映射补充**
  - `csv-schema.json` 新增 P3→Low 映射，避免导出时优先级丢失
  - 所有 skill 文件的优先级映射说明同步更新

- **阶段 4 评审优化：评审报告独立存储 + 增量评审 + 并行分维度评审**
  - 评审报告独立存储：每轮生成独立的 `1-评审报告-第N轮.md`（N=1,2,3...），`1-评审记要.md` 仅保留最终用例表
  - 增量评审：第 2 轮起自动切换增量模式，已有用例仅展示 ID+测试点摘要，新增/修改用例展示完整信息，token 消耗预估减少 70%-80%
  - 并行分维度评审：从 2 个通用 subagent 改为按维度（UX/DATA/COMP/EXEC/BUG/SEC/PERF）启动并行 subagent，每个 subagent 仅关注单维度评审点，审查深度更高
  - 阶段 4 重构为 6 个子步骤（4.1 评审维度选择 / 4.2 评审范围确定 / 4.3 并行分维度评审 / 4.4 合并评审结果 / 4.5 文件输出 / 4.6 用户决策）
  - 三个 skill 文件（agents / claude / cursor）同步更新，cursor 文件目录结构参考表同步更新

- **全阶段 Token 消耗统计**
  - 每个阶段（0~5）结束时记录终端累计 token 值作为阶段基线
  - 阶段 4.5 每轮评审报告末尾追加 Token 统计区块（轮次/模式/维度数/用例数/消耗/累计）
  - 阶段 5 最终汇总输出全阶段 Token 消耗对比表（各阶段增量 + 累计 + 占比）
  - 支持评审轮次间 token 消耗对比，验证增量评审实际效果
  - 三个 skill 文件同步更新

### Changed

- **本地知识保留机制**
  - `checkpoints-index.md` 和 `review-expectations-index.md` 标记为 `--skip-worktree`
  - Git 远端保持初始模板版本，本地保留实际沉淀的检查点/评审点
  - 避免后续推送时覆盖个人积累的知识资产

---

## [1.1.1] - 2026-06-02

### Fixed

- **Critical 修复**
  - `init-testcase.sh` 补充 v1.1.0 缺失文件：`testcase-export.md`、`md_to_csv.py`、`csv-schema.json`、`jira-csv-template.csv`、`history-index.md`
  - `init-testcase.ps1` 同步补充 v1.1.0 缺失文件（与 sh 版本保持一致）
  - `.gitkeep.md` 重命名为 `.gitkeep`，修复与 `.gitignore` 规则不匹配问题
  - `.cursor/skills/testcase-creator/skill.md` 同步新目录结构（子目录命名 + Jira CSV 导出）
  - `.claude/settings.local.json` 权限 glob 模式更新为 `history/*/` 匹配新目录结构
  - `init-testcase.ps1` settings.local.json 模板更新为新目录 glob 模式

- **High 修复**
  - `md_to_csv.py` 优先级读取改为显式读取 MD 表格中的优先级列，不再依赖启发式推断
  - 三个 Python 脚本（`export_excel.py`、`export_xmind.py`、`md_to_csv.py`）增加文件 I/O 错误处理（try/except）
  - 脚本增加输入文件存在性校验、JSON 格式校验、编码校验
  - 脚本增加 `testcases` 字段类型校验（必须为数组）

- **Medium 修复**
  - 初始化检查增加 `project.config.md` 占位符检测，未填写时警告用户
  - 模块名清理：移除文件系统不允许的字符（`/ \ : * ? " < > |`）
  - `md_to_csv.py` 步骤解析正则优化，减少误拆风险
  - `md_to_csv.py` 解析失败时输出格式提示，不再静默生成空 CSV
  - `TESTCASE_GUIDE.md` 文件命名更新为子目录结构
  - `TESTCASE_GUIDE.md` 阶段 5 导出流程更新为统一 J/O/E/X/N 选择
  - `README.md` 完善目录结构、可用命令、导出格式、历史记录管理等章节

---

## [1.1.0] - 2026-06-01

### Added

- **Jira CSV 导出支持**
  - 新增 `.testcase-assets/templates/jira-csv-template.csv` 示例文件
  - 新增 `.testcase-assets/templates/csv-schema.json` 字段映射规则
  - 新增 `.testcase-assets/scripts/md_to_csv.py` MD 转 CSV 转换脚本
  - CSV 格式：UTF-8 with BOM 编码，支持 Jira 直接导入
  - 多步骤用例自动展开为多行，首行填写用例基础信息，后续行仅填写步骤详情
  - 优先级映射：P0→High, P1→Medium, P2→Low

- **独立导出命令 `/testcase-export`**
  - 新增 `.claude/commands/testcase-export.md`
  - 支持从已有定稿文件独立导出，无需重走 5 阶段用例生成流程
  - 自动扫描历史子目录或读取 `history-index.md` 列出可选文件
  - 支持多平台导出：Jira CSV / Excel / XMind

- **历史记录管理**
  - 每次运行归入独立子目录：`.testcase-assets/history/<YYYYMMDD>_<HHMMSS>_<模块名>/`
  - 新增 `history-index.md` 索引文件，自动追加每次运行记录
  - 子目录内文件统一命名（无时间戳后缀），便于管理

### Changed

- **阶段 5 导出流程重构**（`testcase-creator.md`）
  - 原流程：Excel/XMind 单独询问，导出入口分散
  - 新流程：统一展示所有导出平台（J/E/X/N），一次选择，可多选
  - 新增 Jira CSV 作为首选导出选项

- **文件目录结构重构**
  - 原结构：`history/0-用例准备_<timestamp>.md`、`1-评审记要_<timestamp>.md` 平铺
  - 新结构：`history/<运行目录>/0-用例准备.md`、`1-评审记要.md` 归入子目录
  - 已有文件迁移至 `20260601_174203_碳盘查清单/` 子目录

---

## [1.0.0] - 2026-05-01

### Added

- **用例生成 Skill `/testcase-creator`**
  - 5 阶段流程：需求输入 → 输入结构化 → 用例生成 → 评审优化 → 定稿导入
  - 支持多种需求来源：文字描述、乐享链接、接口文档、本地文件（.md/.docx/.pdf）
  - 检查点索引（checkpoints-index.md）：按业务域分类管理检查点
  - 评审点索引（review-expectations-index.md）：多维度评审覆盖检查
  - 资产沉淀：支持新增检查点和评审点，自动编号去重

- **Excel / XMind 导出**
  - 支持导出 Excel（.xlsx）带颜色分类、冻结表头
  - 支持导出 XMind（.xmind）思维导图
  - 脚本：`.testcase-assets/scripts/export_excel.py`、`export_xmind.py`

- **初始化脚本**
  - `init-testcase.sh`（macOS/Linux）
  - `init-testcase.ps1`（Windows）
