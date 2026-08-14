#!/bin/bash

# ============================================================
# testcase-creator 一键初始化脚本（新版：支持多项目）
# 用法：./init-testcase.sh <项目名称或目录> <目标路径> [--sync|--force]
# 示例：./init-testcase.sh crrc-esg /path/to/your-project
#       ./init-testcase.sh _template /path/to/new-project
#       ./init-testcase.sh _template /path/to/old-project --sync   # 升级 Skill/脚本，保护项目资产
#       ./init-testcase.sh ./projects/_template ./projects/new-project --force
# ============================================================

set -e

# ---------- 颜色定义 ----------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---------- 脚本自身目录 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- 参数解析 ----------
FORCE=false
SYNC=false
PROJECT_NAME=""
PROJECT_INPUT=""
TARGET_DIR=""

for arg in "$@"; do
  if [ "$arg" == "--force" ]; then
    FORCE=true
  elif [ "$arg" == "--sync" ]; then
    SYNC=true
  elif [ -z "$PROJECT_INPUT" ]; then
    PROJECT_INPUT="$arg"
  elif [ -z "$TARGET_DIR" ]; then
    TARGET_DIR="$arg"
  fi
done

if [ "$FORCE" = true ] && [ "$SYNC" = true ]; then
  echo -e "${YELLOW}[WARN] 同时指定 --force 与 --sync 时，以 --force 为准（会覆盖项目资产）${NC}"
  SYNC=false
fi

# ---------- 参数校验 ----------
if [ -z "$PROJECT_INPUT" ]; then
  echo -e "${RED}[ERROR] 缺少项目名称或目录${NC}"
  echo ""
  echo "用法: ./init-testcase.sh <项目名称或目录> <目标路径> [--sync|--force]"
  echo ""
  echo "  --sync   升级 Skill / 导出脚本 / 模板 / 指南，不覆盖 project.config 与检查点等项目资产"
  echo "  --force  覆盖全部目标文件（含项目资产，慎用）"
  echo ""
  echo "可用的项目:"
  for dir in "$SCRIPT_DIR/projects"/*/; do
    if [ -d "$dir" ]; then
      name=$(basename "$dir")
      echo "  - $name"
    fi
  done
  exit 1
fi

# 解析项目：支持 projects/ 下的名称、相对目录和绝对目录
if [ -d "$PROJECT_INPUT" ]; then
  PROJECT_DIR="$(cd "$PROJECT_INPUT" && pwd)"
elif [ -d "$SCRIPT_DIR/$PROJECT_INPUT" ]; then
  PROJECT_DIR="$(cd "$SCRIPT_DIR/$PROJECT_INPUT" && pwd)"
elif [ -d "$SCRIPT_DIR/projects/$PROJECT_INPUT" ]; then
  PROJECT_DIR="$(cd "$SCRIPT_DIR/projects/$PROJECT_INPUT" && pwd)"
else
  echo -e "${RED}[ERROR] 项目不存在: $PROJECT_INPUT${NC}"
  echo ""
  echo "可传入 projects/ 下的项目名称，或项目资产目录路径。"
  echo "可用的项目:"
  for dir in "$SCRIPT_DIR/projects"/*/; do
    if [ -d "$dir" ]; then
      name=$(basename "$dir")
      echo "  - $name"
    fi
  done
  exit 1
fi

PROJECT_NAME="$(basename "$PROJECT_DIR")"

# 处理目标路径
if [ -n "$TARGET_DIR" ]; then
  TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || {
    echo -e "${RED}[ERROR] 目标路径不存在: $TARGET_DIR${NC}"
    exit 1
  }
else
  echo -e "${YELLOW}请输入目标项目的绝对路径（直接回车则使用当前目录）：${NC}"
  read -r INPUT_PATH
  if [ -z "$INPUT_PATH" ]; then
    TARGET_DIR="$(pwd)"
  else
    TARGET_DIR="$(cd "$INPUT_PATH" && pwd)" || {
      echo -e "${RED}[ERROR] 目标路径不存在: $INPUT_PATH${NC}"
      exit 1
    }
  fi
fi

# ---------- 确认信息 ----------
echo ""
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}   testcase-creator 初始化脚本${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""
echo -e "[DIR] 模板来源：${SCRIPT_DIR}"
echo -e "[PROJECT] 项目名称：${PROJECT_NAME}"
echo -e "[TARGET] 目标项目：${TARGET_DIR}"
if [ "$FORCE" = true ]; then
  echo -e "[MODE] ${YELLOW}强制覆盖（含项目资产）${NC}"
elif [ "$SYNC" = true ]; then
  echo -e "[MODE] ${GREEN}升级同步（保护项目资产）${NC}"
else
  echo -e "[MODE] 首次安装（已存在则跳过）"
fi
echo ""

echo -e "${YELLOW}确认将模板文件复制到上述目标路径？(y/N)${NC}"
read -r CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo -e "${RED}已取消。${NC}"
  exit 0
fi

echo ""

# ---------- 复制函数 ----------
# kind=managed: --sync/--force 时覆盖；kind=project: 仅 --force 覆盖已存在文件
copy_item() {
  local SRC="$1"
  local DEST="$2"
  local LABEL="$3"
  local KIND="${4:-managed}"

  if [ ! -e "$SRC" ]; then
    echo -e "  ${RED}[FAIL] 源文件不存在：${LABEL}${NC}"
    return 1
  fi

  if [ -e "$DEST" ]; then
    if [ "$SRC" -ef "$DEST" ]; then
      echo -e "  ${GREEN}[OK] 目标与源相同，无需复制：${LABEL}${NC}"
      return 0
    fi

    local allow_overwrite=false
    if [ "$FORCE" = true ]; then
      allow_overwrite=true
    elif [ "$SYNC" = true ] && [ "$KIND" = "managed" ]; then
      allow_overwrite=true
    fi

    if [ "$allow_overwrite" != true ]; then
      if [ "$SYNC" = true ] && [ "$KIND" = "project" ]; then
        echo -e "  ${YELLOW}[SKIP] 项目资产已保护，未覆盖：${LABEL}${NC}"
      else
        echo -e "  ${YELLOW}[WARN] 已存在，跳过（升级用 --sync，全量覆盖用 --force）：${LABEL}${NC}"
      fi
      return 0
    fi

    mkdir -p "$(dirname "$DEST")"
    cp -r "$SRC" "$DEST"
    if [ "$FORCE" = true ]; then
      echo -e "  ${GREEN}[OK] 强制覆盖：${LABEL}${NC}"
    else
      echo -e "  ${GREEN}[OK] 已同步：${LABEL}${NC}"
    fi
  else
    mkdir -p "$(dirname "$DEST")"
    cp -r "$SRC" "$DEST"
    echo -e "  ${GREEN}[OK] 已复制：${LABEL}${NC}"
  fi
}

copy_tree_files() {
  local SRC_ROOT="$1"
  local DEST_ROOT="$2"
  local LABEL_ROOT="$3"
  local KIND="${4:-managed}"

  while IFS= read -r src; do
    local relative="${src#"$SRC_ROOT"/}"
    # settings.local.json 始终由本脚本生成，不从 dist 覆盖
    if [ "$relative" = "settings.local.json" ] || [[ "$relative" == */settings.local.json ]]; then
      continue
    fi
    copy_item "$src" "$DEST_ROOT/$relative" "$LABEL_ROOT/$relative" "$KIND"
  done < <(find "$SRC_ROOT" -type f | sort)
}

# ---------- 构建最新 Skill ----------
echo -e "${BLUE}-> 正在构建最新 Skill...${NC}"
"$SCRIPT_DIR/build.sh" --clean
echo ""

# ---------- 开始复制 ----------
echo -e "${BLUE}-> 正在复制 Skill 文件（从 dist/）...${NC}"

copy_tree_files "$SCRIPT_DIR/dist/.claude" "$TARGET_DIR/.claude" ".claude" managed
copy_tree_files "$SCRIPT_DIR/dist/.cursor" "$TARGET_DIR/.cursor" ".cursor" managed
copy_tree_files "$SCRIPT_DIR/dist/.agents" "$TARGET_DIR/.agents" ".agents" managed

echo ""
echo -e "${BLUE}-> 正在复制通用框架文件...${NC}"

for f in "$SCRIPT_DIR"/framework/templates/*; do
  [ -f "$f" ] && copy_item "$f" "$TARGET_DIR/.testcase-assets/templates/$(basename "$f")" ".testcase-assets/templates/$(basename "$f")" managed
done

# 推荐规则：仅当目标不存在时放入 .testcase-assets（项目可改，sync 不覆盖）
if [ -f "$SCRIPT_DIR/framework/templates/recommend-rules.yaml" ]; then
  copy_item "$SCRIPT_DIR/framework/templates/recommend-rules.yaml" \
    "$TARGET_DIR/.testcase-assets/recommend-rules.yaml" \
    ".testcase-assets/recommend-rules.yaml" project
fi

for f in "$SCRIPT_DIR"/framework/scripts/*; do
  [ -f "$f" ] || continue
  # 跳过缓存与非脚本噪音
  case "$(basename "$f")" in
    __pycache__|*.pyc) continue ;;
  esac
  [ -f "$f" ] && copy_item "$f" "$TARGET_DIR/.testcase-assets/scripts/$(basename "$f")" ".testcase-assets/scripts/$(basename "$f")" managed
done

echo ""
echo -e "${BLUE}-> 正在复制项目资产（${PROJECT_NAME}）...${NC}"

for f in "$PROJECT_DIR"/*; do
  [ -f "$f" ] || continue
  filename=$(basename "$f")
  # 项目业务资产：同步模式下不覆盖
  case "$filename" in
    project.config.md|checkpoints-index.md|review-expectations-index.md)
      copy_item "$f" "$TARGET_DIR/.testcase-assets/$filename" ".testcase-assets/$filename" project
      ;;
    *)
      # 其它随项目模板带出的文件按项目资产保护
      copy_item "$f" "$TARGET_DIR/.testcase-assets/$filename" ".testcase-assets/$filename" project
      ;;
  esac
done

echo ""
echo -e "${BLUE}-> 正在初始化目录结构...${NC}"

mkdir -p "$TARGET_DIR/.testcase-assets/history"
echo -e "  ${GREEN}[OK] 已创建：.testcase-assets/history/ 目录${NC}"

if [ ! -f "$TARGET_DIR/.testcase-assets/history/history-index.md" ]; then
  cat > "$TARGET_DIR/.testcase-assets/history/history-index.md" << 'INDEX_EOF'
# 用例生成历史索引

> 每次运行 `/testcase-creator` 自动追加记录。文件按时间倒序排列（最新在前）。

---

| 时间 | 模块 | 用例数 | 运行目录 | 导出文件 |
|------|------|--------|----------|----------|
INDEX_EOF
  echo -e "  ${GREEN}[OK] 已初始化：.testcase-assets/history/history-index.md${NC}"
else
  echo -e "  ${GREEN}[OK] 保留已有 history-index.md${NC}"
fi

touch "$TARGET_DIR/.testcase-assets/history/.gitkeep"

# 写入框架版本戳（便于判断是否需要 --sync）
CREATOR_VER="$(grep -E '^version:' "$SCRIPT_DIR/skills/testcase-creator/meta.yaml" | head -1 | sed 's/.*"\(.*\)".*/\1/')"
EXPORT_VER="$(grep -E '^version:' "$SCRIPT_DIR/skills/testcase-export/meta.yaml" | head -1 | sed 's/.*"\(.*\)".*/\1/')"
VERSION_FILE="$TARGET_DIR/.testcase-assets/FRAMEWORK_VERSION"
cat > "$VERSION_FILE" << VERSION_EOF
# 由 init-testcase 写入；请勿手改业务内容。升级请：./init-testcase.sh <项目> <目标> --sync
testcase-creator=$CREATOR_VER
testcase-export=$EXPORT_VER
synced_at=$(date +%Y-%m-%dT%H:%M:%S)
VERSION_EOF
echo -e "  ${GREEN}[OK] 已写入：.testcase-assets/FRAMEWORK_VERSION（creator ${CREATOR_VER} / export ${EXPORT_VER}）${NC}"

echo ""
echo -e "${BLUE}-> 正在复制 Codex/纯对话工具指南...${NC}"
copy_item "$SCRIPT_DIR/TESTCASE_GUIDE.md" "$TARGET_DIR/TESTCASE_GUIDE.md" "TESTCASE_GUIDE.md" managed

# ---------- .gitignore 追加 ----------
echo ""
echo -e "${BLUE}-> 检查 .gitignore...${NC}"
GITIGNORE="$TARGET_DIR/.gitignore"
HISTORY_PATTERN=".testcase-assets/history/"

if [ -f "$GITIGNORE" ]; then
  if grep -qF "$HISTORY_PATTERN" "$GITIGNORE"; then
    echo -e "  ${YELLOW}[WARN] .gitignore 已包含 history 目录规则，跳过${NC}"
  else
    echo "" >> "$GITIGNORE"
    echo "# testcase-creator 生成的历史记录（可按需改为 Git 追踪）" >> "$GITIGNORE"
    echo "$HISTORY_PATTERN" >> "$GITIGNORE"
    echo -e "  ${GREEN}[OK] 已追加 .testcase-assets/history/ 到 .gitignore${NC}"
  fi
else
  echo -e "  ${YELLOW}[WARN] 未找到 .gitignore，已跳过（可手动添加 .testcase-assets/history/）${NC}"
fi

# ---------- 自动生成 .claude/settings.local.json ----------
echo ""
echo -e "${BLUE}-> 正在生成 .claude/settings.local.json（根据当前用户动态写入路径）...${NC}"

SETTINGS_FILE="$TARGET_DIR/.claude/settings.local.json"
mkdir -p "$TARGET_DIR/.claude"

cat > "$SETTINGS_FILE" << SETTINGS_EOF
{
  "permissions": {
    "allow": [
      "Bash(pdftotext ${HOME}/Downloads/*.pdf -)",
      "Bash(pdftotext ${HOME}/Desktop/*.pdf -)",
      "Bash(textutil -convert txt -stdout ${HOME}/Downloads/*.docx)",
      "Bash(textutil -convert txt -stdout ${HOME}/Desktop/*.docx)",
      "Bash(python3 .testcase-assets/scripts/check_framework_version.py *)",
      "Bash(python3 .testcase-assets/scripts/check_environment.py *)",
      "Bash(python3 .testcase-assets/scripts/gate_stage.py *)",
      "Bash(python3 .testcase-assets/scripts/recommend_checkpoints.py *)",
      "Bash(python3 .testcase-assets/scripts/recommend_history.py *)",
      "Bash(python3 .testcase-assets/scripts/scan_code_scope.py *)",
      "Bash(python3 .testcase-assets/scripts/md_to_json.py .testcase-assets/history/*/2-用例定稿.md .testcase-assets/history/*/export_data.json *)",
      "Bash(python3 .testcase-assets/scripts/export_all.py *)",
      "Bash(python3 .testcase-assets/scripts/merge_cases.py *)",
      "Bash(python3 .testcase-assets/scripts/suggest_assets_from_bugs.py *)",
      "Bash(python3 .testcase-assets/scripts/export_excel.py .testcase-assets/history/*/export_data.json .testcase-assets/history/*/testcases.xlsx)",
      "Bash(python3 .testcase-assets/scripts/export_xmind.py .testcase-assets/history/*/export_data.json .testcase-assets/history/*/testcases.xmind)",
      "Bash(python3 .testcase-assets/scripts/md_to_csv.py .testcase-assets/history/*/2-用例定稿.md .testcase-assets/history/*/jira_export.csv *)",
      "Bash(python3 .testcase-assets/scripts/testcase_quality.py .testcase-assets/history/*/2-用例定稿.md --audit-output .testcase-assets/history/*/audit-summary.md --strict)",
      "Bash(python3 .testcase-assets/scripts/testcase_quality.py .testcase-assets/history/*/export_data.json --audit-output .testcase-assets/history/*/audit-summary.md --strict)",
      "Bash(python3 .testcase-assets/scripts/testcase_quality.py .testcase-assets/history/*/export_data.json --audit-output .testcase-assets/history/*/audit-summary.md --xlsx .testcase-assets/history/*/testcases.xlsx --strict)"
    ]
  }
}
SETTINGS_EOF

echo -e "  ${GREEN}[OK] 已生成 .claude/settings.local.json（路径已适配当前用户: ${HOME}）${NC}"

# ---------- 完成摘要 ----------
echo ""
echo -e "${BLUE}==========================================${NC}"
if [ "$SYNC" = true ]; then
  echo -e "${GREEN} 升级同步完成！${NC}"
elif [ "$FORCE" = true ]; then
  echo -e "${GREEN} 强制初始化完成！${NC}"
else
  echo -e "${GREEN} 初始化完成！${NC}"
fi
echo -e "${BLUE}==========================================${NC}"
echo ""
echo -e "[DIR] 目标项目结构："
echo -e "   ${TARGET_DIR}/"
echo -e "   ├── .agents/skills/"
echo -e "   │   ├── source-command-testcase-creator/SKILL.md + references/"
echo -e "   │   └── source-command-testcase-export/SKILL.md"
echo -e "   ├── .cursor/skills/testcase-creator/skill.md"
echo -e "   ├── .claude/commands/"
echo -e "   │   ├── testcase-creator.md"
echo -e "   │   └── testcase-export.md"
echo -e "   ├── TESTCASE_GUIDE.md                 （Codex/纯对话工具使用）"
echo -e "   └── .testcase-assets/"
echo -e "       ├── FRAMEWORK_VERSION              （Skill/脚本版本戳）"
echo -e "       ├── project.config.md               （项目配置，首次使用前请填写）"
echo -e "       ├── checkpoints-index.md"
echo -e "       ├── review-expectations-index.md"
echo -e "       ├── templates/"
echo -e "       │   ├── testcase-table.md"
echo -e "       │   ├── testcase-table-config.json"
echo -e "       │   ├── csv-schema.json"
echo -e "       │   └── jira-csv-template.csv"
echo -e "       ├── scripts/"
echo -e "       │   ├── check_framework_version.py （版本体检）"
echo -e "       │   ├── export_all.py           （一键导出/冒烟子集）"
echo -e "       │   ├── merge_cases.py          （增量合并）"
echo -e "       │   ├── testcase_common.py      （公共解析）"
echo -e "       │   ├── md_to_json.py           （MD→JSON）"
echo -e "       │   ├── export_excel.py         （Excel 导出）"
echo -e "       │   ├── export_xmind.py         （XMind 导出）"
echo -e "       │   ├── md_to_csv.py            （Jira/Tapd/禅道 CSV）"
echo -e "       │   ├── suggest_assets_from_bugs.py （缺陷沉淀候选）"
echo -e "       │   └── testcase_quality.py     （质量检查与审计）"
echo -e "       └── history/"
echo -e "           ├── history-index.md"
echo -e "           └── .gitkeep"
echo ""
echo -e ">> 下一步："
echo -e "   1. 【必填】编辑 ${GREEN}.testcase-assets/project.config.md${NC}，填写项目名称、业务域、测试负责人"
echo -e "   2. 【必填】根据实际业务补充 ${GREEN}.testcase-assets/checkpoints-index.md${NC}"
echo -e "   3. 【环境】锁定依赖自动安装：${YELLOW}openpyxl==3.1.5 json-repair==0.61.2${NC}"
echo -e "   4. 【环境】如需读取 PDF 文件：${YELLOW}brew install poppler${NC}  (可选)"
echo -e "   5. Cursor 用户：在项目中输入 ${GREEN}/testcase-creator${NC} 触发"
echo -e "   6. Claude Code 用户：输入 ${GREEN}/testcase-creator${NC} 触发"
echo -e "   7. Codex 用户：确认 ${GREEN}.agents/skills/${NC} 已复制，可直接说明运行 testcase-creator"
echo -e "   8. ChatGPT/纯对话工具用户：复制 ${GREEN}TESTCASE_GUIDE.md${NC} 内容到对话开头"
echo ""
echo -e "[TIP] 旧项目升级到最新 Skill/脚本：${YELLOW}./init-testcase.sh <项目名> <目标路径> --sync${NC}"
echo -e "      （不覆盖 project.config / 检查点 / 历史；仅 --force 才会覆盖项目资产）"
echo -e "      本仓库 projects/* 一键对齐：${YELLOW}./sync-projects.sh${NC} 或 ${YELLOW}python3 check_project_copies.py --fix --build${NC}"
echo ""
