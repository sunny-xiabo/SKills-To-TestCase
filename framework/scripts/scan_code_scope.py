#!/usr/bin/env python3
"""扫描代码范围，输出阶段 1「来源 I」用的清单与摘录（不生成用例）。

用法:
    # 指定目录/文件（可多路径）
    python3 scan_code_scope.py --path src/user --path src/api/login.py

    # 相对某 git 仓库的 diff（工作区或相对 base）
    python3 scan_code_scope.py --git-root . --diff
    python3 scan_code_scope.py --git-root . --diff --base origin/main

    # 限制与输出
    python3 scan_code_scope.py --path app/ --max-files 40 --max-bytes 200000 \\
      --output /tmp/code-scope.md

约束:
    - 必须提供 --path 和/或 --diff，禁止无范围全仓扫描
    - 仅列出文本源码类文件；二进制跳过
    - 摘录截断，供 Agent 阅读，不替代人工确认
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

# 常见源码扩展
SOURCE_SUFFIXES = {
    ".py",
    ".js",
    ".jsx",
    ".ts",
    ".tsx",
    ".vue",
    ".java",
    ".kt",
    ".go",
    ".rs",
    ".rb",
    ".php",
    ".cs",
    ".swift",
    ".m",
    ".mm",
    ".scala",
    ".groovy",
    ".c",
    ".cc",
    ".cpp",
    ".h",
    ".hpp",
    ".sql",
    ".xml",
    ".yml",
    ".yaml",
    ".json",
    ".md",
    ".html",
    ".css",
    ".scss",
    ".less",
}

SKIP_DIR_NAMES = {
    ".git",
    "node_modules",
    "dist",
    "build",
    "target",
    "vendor",
    "__pycache__",
    ".venv",
    "venv",
    ".idea",
    ".vscode",
    "coverage",
    ".next",
    ".nuxt",
}


def is_source_file(path: Path) -> bool:
    if path.suffix.lower() in SOURCE_SUFFIXES:
        return True
    # 无后缀的常见入口
    return path.name in {"Dockerfile", "Makefile", "Jenkinsfile"}


def should_skip_dir(name: str) -> bool:
    return name in SKIP_DIR_NAMES or name.startswith(".")


def collect_from_paths(paths: list[Path], max_files: int) -> list[Path]:
    files: list[Path] = []
    for raw in paths:
        path = raw.resolve()
        if not path.exists():
            continue
        if path.is_file():
            if is_source_file(path):
                files.append(path)
            continue
        for p in sorted(path.rglob("*")):
            if not p.is_file():
                continue
            if any(should_skip_dir(part) for part in p.parts):
                continue
            if is_source_file(p):
                files.append(p)
            if len(files) >= max_files:
                return files
    # 去重保序
    seen = set()
    unique = []
    for f in files:
        key = str(f)
        if key not in seen:
            seen.add(key)
            unique.append(f)
    return unique[:max_files]


def collect_from_git_diff(
    git_root: Path,
    *,
    base: str,
    max_files: int,
) -> tuple[list[Path], str, list[str]]:
    """返回 (文件列表, diff 摘要文本, 警告)。"""
    warnings: list[str] = []
    root = git_root.resolve()
    if not (root / ".git").exists() and not (root / ".git").is_file():
        # worktree 时 .git 可能是文件
        result = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "--is-inside-work-tree"],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0 or result.stdout.strip() != "true":
            return [], "", [f"不是 git 仓库: {root}"]

    if base:
        cmd_name = ["git", "-C", str(root), "diff", "--name-only", f"{base}...HEAD"]
        cmd_stat = ["git", "-C", str(root), "diff", "--stat", f"{base}...HEAD"]
        # 也包含未提交变更
        cmd_name_work = ["git", "-C", str(root), "diff", "--name-only"]
    else:
        cmd_name = ["git", "-C", str(root), "diff", "--name-only", "HEAD"]
        cmd_stat = ["git", "-C", str(root), "diff", "--stat", "HEAD"]
        # 含未跟踪：用 status
        cmd_name_work = None

    names: list[str] = []
    r = subprocess.run(cmd_name, capture_output=True, text=True, check=False)
    if r.returncode != 0:
        warnings.append(r.stderr.strip() or "git diff 失败")
    else:
        names.extend([ln.strip() for ln in r.stdout.splitlines() if ln.strip()])

    if not base:
        # 工作区相对 HEAD + 暂存
        for extra in (
            ["git", "-C", str(root), "diff", "--name-only", "--cached"],
            ["git", "-C", str(root), "ls-files", "--others", "--exclude-standard"],
        ):
            r2 = subprocess.run(extra, capture_output=True, text=True, check=False)
            if r2.returncode == 0:
                names.extend([ln.strip() for ln in r2.stdout.splitlines() if ln.strip()])
    elif cmd_name_work:
        r3 = subprocess.run(cmd_name_work, capture_output=True, text=True, check=False)
        if r3.returncode == 0:
            names.extend([ln.strip() for ln in r3.stdout.splitlines() if ln.strip()])

    # 去重
    ordered = []
    seen = set()
    for n in names:
        if n not in seen:
            seen.add(n)
            ordered.append(n)

    files = []
    for n in ordered:
        p = (root / n).resolve()
        if p.is_file() and is_source_file(p):
            files.append(p)
        if len(files) >= max_files:
            break

    stat = subprocess.run(cmd_stat, capture_output=True, text=True, check=False)
    diff_summary = stat.stdout.strip() if stat.returncode == 0 else ""
    if not files:
        warnings.append("diff 未得到可扫描的源码文件（或变更为空）")
    return files[:max_files], diff_summary, warnings


def read_excerpt(path: Path, max_bytes: int) -> str:
    try:
        data = path.read_bytes()
    except OSError as error:
        return f"（无法读取: {error}）"
    if b"\x00" in data[:8000]:
        return "（疑似二进制，已跳过摘录）"
    text = data[:max_bytes].decode("utf-8", errors="replace")
    if len(data) > max_bytes:
        text += f"\n\n… [截断，原文件约 {len(data)} 字节] …"
    return text


def guess_hints(text: str) -> list[str]:
    """极轻量线索，供 Agent 参考，不作为最终结论。"""
    hints = []
    patterns = [
        (r"\b(router|Route|@RequestMapping|@GetMapping|@PostMapping|app\.(get|post))\b", "路由/接口"),
        (r"\b(validat|required|maxLength|minLength|schema|zod|yup)\b", "校验"),
        (r"\b(permission|auth|role|token|403|401|unauthorized)\b", "权限/鉴权"),
        (r"\b(try|catch|throw|Error|Exception)\b", "异常处理"),
        (r"\b(upload|multipart|FormData)\b", "上传"),
        (r"\b(page|pageSize|offset|limit|pagination)\b", "分页"),
        (r"\b(useState|ref\(|reactive\(|computed\()\b", "前端状态"),
    ]
    for pat, label in patterns:
        if re.search(pat, text, re.I):
            hints.append(label)
    return hints


def build_report(
    files: list[Path],
    *,
    root: Path | None,
    diff_summary: str,
    max_excerpt_bytes: int,
    warnings: list[str],
) -> str:
    lines = [
        "# 代码范围扫描（来源 I · 请确认）",
        "",
        "> 本文件由 `scan_code_scope.py` 生成，**不是用例**。Agent 须据此写「代码分析」并等人确认后再生成用例。",
        "> 禁止在未确认时直接输出定稿用例；禁止生成自动化测试代码。",
        "",
        f"- 文件数：{len(files)}",
    ]
    if root:
        lines.append(f"- 根路径：`{root}`")
    if warnings:
        lines.append("- 警告：")
        for w in warnings:
            lines.append(f"  - {w}")
    lines.append("")

    if diff_summary:
        lines.extend(["## Diff 统计", "", "```", diff_summary, "```", ""])

    lines.extend(["## 文件清单", ""])
    for i, f in enumerate(files, start=1):
        try:
            rel = f.relative_to(root) if root else f
        except ValueError:
            rel = f
        size = f.stat().st_size if f.is_file() else 0
        lines.append(f"{i}. `{rel}` （{size} bytes）")
    lines.append("")

    lines.extend(["## 文件摘录与线索", ""])
    per_file_budget = max(2000, max_excerpt_bytes // max(len(files), 1))
    for f in files:
        try:
            rel = f.relative_to(root) if root else f
        except ValueError:
            rel = f
        excerpt = read_excerpt(f, per_file_budget)
        hints = guess_hints(excerpt)
        lines.append(f"### `{rel}`")
        if hints:
            lines.append(f"- 自动线索：{', '.join(hints)}")
        lines.append("")
        lines.append("```")
        lines.append(excerpt.rstrip())
        lines.append("```")
        lines.append("")

    lines.extend(
        [
            "## 建议 Agent 输出的代码分析结构",
            "",
            "- 分析范围（路径 / diff base）",
            "- 入口与路由 / 接口",
            "- 关键字段与校验",
            "- 分支与状态",
            "- 权限与角色",
            "- 异常与错误码",
            "- 风险点与建议测试场景类型（正向/异常/边界/并发）",
            "",
            "有文字需求时：填写「需求与代码差异」表，不得用代码覆盖未确认的需求。",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--path",
        action="append",
        default=[],
        type=Path,
        help="源码目录或文件，可重复",
    )
    parser.add_argument(
        "--git-root",
        type=Path,
        default=None,
        help="git 仓库根；与 --diff 合用",
    )
    parser.add_argument(
        "--diff",
        action="store_true",
        help="扫描 git 变更文件（需 --git-root，默认当前目录）",
    )
    parser.add_argument(
        "--base",
        default="",
        help="diff 基线，如 origin/main；空则工作区相对 HEAD + 未跟踪",
    )
    parser.add_argument("--max-files", type=int, default=40)
    parser.add_argument(
        "--max-bytes",
        type=int,
        default=200_000,
        help="所有摘录合计近似上限（按文件均分）",
    )
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    if not args.path and not args.diff:
        print("[FAIL] 必须指定 --path 和/或 --diff（禁止无范围全仓扫描）")
        return 2

    warnings: list[str] = []
    files: list[Path] = []
    diff_summary = ""
    root: Path | None = None

    if args.path:
        files.extend(collect_from_paths(args.path, args.max_files))
        if args.path:
            # 公共父
            try:
                root = Path(args.path[0]).resolve()
                if root.is_file():
                    root = root.parent
            except OSError:
                root = None
        missing = [str(p) for p in args.path if not Path(p).exists()]
        if missing:
            warnings.append("路径不存在: " + ", ".join(missing))

    if args.diff:
        git_root = (args.git_root or Path(".")).resolve()
        root = git_root
        d_files, diff_summary, d_warn = collect_from_git_diff(
            git_root, base=args.base, max_files=args.max_files
        )
        warnings.extend(d_warn)
        # 合并
        seen = {str(f) for f in files}
        for f in d_files:
            if str(f) not in seen:
                files.append(f)
                seen.add(str(f))
        files = files[: args.max_files]

    if not files:
        print("[FAIL] 未收集到任何源码文件。请检查路径或 diff 是否有变更。")
        for w in warnings:
            print(f"  - {w}")
        return 1

    report = build_report(
        files,
        root=root,
        diff_summary=diff_summary,
        max_excerpt_bytes=args.max_bytes,
        warnings=warnings,
    )
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report, encoding="utf-8")
        print(f"[OK] 代码范围扫描已写入: {args.output}（{len(files)} 个文件）")
    else:
        print(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
