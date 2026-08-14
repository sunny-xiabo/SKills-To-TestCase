#!/usr/bin/env python3
"""框架期望版本（与 skills/*/meta.yaml 保持同步）。"""

from __future__ import annotations

from datetime import datetime
from pathlib import Path

# 发布时与 skills/testcase-creator|export 的 meta.yaml version 对齐
EXPECTED = {
    "testcase-creator": "1.12.0",
    "testcase-export": "1.9.0",
}


def parse_version_file(path: Path) -> dict[str, str]:
    """解析 FRAMEWORK_VERSION，返回 key→value。"""
    if not path.is_file():
        return {}
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        result[key.strip()] = value.strip()
    return result


def find_version_file(start: Path | None = None) -> Path | None:
    """从 start 向上查找 .testcase-assets/FRAMEWORK_VERSION。"""
    cur = (start or Path.cwd()).resolve()
    if cur.is_file():
        cur = cur.parent
    for parent in [cur, *cur.parents]:
        candidate = parent / ".testcase-assets" / "FRAMEWORK_VERSION"
        if candidate.is_file():
            return candidate
        if parent.name == ".testcase-assets":
            direct = parent / "FRAMEWORK_VERSION"
            if direct.is_file():
                return direct
    return None


def check_versions(version_file: Path | None = None) -> tuple[bool, list[str]]:
    """
    检查本地版本是否与期望一致。
    返回 (ok, messages)。ok=False 表示落后或缺失。
    """
    path = version_file or find_version_file()
    messages: list[str] = []
    if path is None:
        messages.append(
            "[WARN] 未找到 .testcase-assets/FRAMEWORK_VERSION，可能未 init 或版本过旧。"
        )
        messages.append(
            f"  期望：creator={EXPECTED['testcase-creator']}  export={EXPECTED['testcase-export']}"
        )
        messages.append(
            "  请在 Skills 仓库执行：./init-testcase.sh <项目名> <本项目路径> --sync"
        )
        return False, messages

    parsed = parse_version_file(path)
    ok = True
    for key, expected in EXPECTED.items():
        actual = parsed.get(key, "")
        if actual != expected:
            ok = False
            messages.append(
                f"[WARN] {key} 本地={actual or '缺失'}，期望={expected}"
            )
    if ok:
        messages.append(
            f"[OK] 框架版本一致（creator={EXPECTED['testcase-creator']} / "
            f"export={EXPECTED['testcase-export']}）"
        )
        synced = parsed.get("synced_at", "")
        if synced:
            messages.append(f"  上次同步：{synced}  文件：{path}")
    else:
        messages.append(f"  版本文件：{path}")
        messages.append(
            "  升级（保护 project.config / 检查点 / history）："
        )
        messages.append(
            "  ./init-testcase.sh <项目名> <本项目路径> --sync"
        )
        messages.append(
            "  本仓库 projects/* 可用：python3 check_project_copies.py --fix"
        )
    return ok, messages


def write_version_file(target_assets: Path, *, synced_at: str | None = None) -> Path:
    """写入 FRAMEWORK_VERSION 到 .testcase-assets 目录。"""
    target_assets.mkdir(parents=True, exist_ok=True)
    path = target_assets / "FRAMEWORK_VERSION"
    stamp = synced_at or datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    path.write_text(
        "# 由 init/sync 写入；升级请：init-testcase.sh <项目> <目标> --sync\n"
        f"testcase-creator={EXPECTED['testcase-creator']}\n"
        f"testcase-export={EXPECTED['testcase-export']}\n"
        f"synced_at={stamp}\n",
        encoding="utf-8",
    )
    return path


if __name__ == "__main__":
    import sys

    start = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    ok, lines = check_versions(find_version_file(start) if start else None)
    for line in lines:
        print(line)
    raise SystemExit(0 if ok else 1)
