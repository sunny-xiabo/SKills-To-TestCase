import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "check_project_copies", ROOT / "check_project_copies.py"
)
CHECKER = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = CHECKER
SPEC.loader.exec_module(CHECKER)


class ProjectCopyCheckTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp_dir.name)
        self.agent_source = (
            self.repo / "dist/.agents/skills/source-command-testcase-creator/SKILL.md"
        )
        self.script_source = self.repo / "framework/scripts/export_excel.py"
        self.project_agent = (
            self.repo
            / "projects/demo/.agents/skills/source-command-testcase-creator/SKILL.md"
        )
        self.project_script = (
            self.repo / "projects/demo/.testcase-assets/scripts/export_excel.py"
        )
        for path in (
            self.agent_source,
            self.script_source,
            self.project_agent,
            self.project_script,
        ):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("same\n", encoding="utf-8")

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_matching_copies_have_no_drift(self):
        self.assertEqual([], CHECKER.scan_project_copies(self.repo))

    def test_detects_modified_missing_and_extra_files(self):
        self.project_agent.write_text("changed\n", encoding="utf-8")
        self.project_script.unlink()
        extra = self.project_script.parent / "local_only.py"
        extra.write_text("local\n", encoding="utf-8")

        drifts = CHECKER.scan_project_copies(self.repo)

        self.assertEqual(["extra", "missing", "modified"], sorted(d.kind for d in drifts))
        self.assertTrue(any(d.project_path == self.project_agent for d in drifts))
        self.assertTrue(any(d.project_path == extra for d in drifts))

    def test_existing_empty_copy_directory_reports_missing_files(self):
        empty_agents = self.repo / "projects/empty/.agents"
        empty_agents.mkdir(parents=True)

        drifts = CHECKER.scan_project_copies(self.repo)

        self.assertTrue(
            any(
                d.kind == "missing" and d.project_path.is_relative_to(empty_agents)
                for d in drifts
            )
        )

    def test_template_directory_is_not_treated_as_installed_copy(self):
        template_agents = self.repo / "projects/_template/.agents"
        template_agents.mkdir(parents=True)

        drifts = CHECKER.scan_project_copies(self.repo)

        self.assertFalse(
            any(template_agents in d.project_path.parents for d in drifts)
        )

    def test_strict_mode_fails_on_drift(self):
        self.project_agent.write_text("changed\n", encoding="utf-8")

        result = subprocess.run(
            [
                sys.executable,
                str(ROOT / "check_project_copies.py"),
                "--root",
                str(self.repo),
                "--strict",
            ],
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(1, result.returncode)
        self.assertIn("不要直接修改 projects/*", result.stdout)
        self.assertIn("skills/*/prompt.md", result.stdout)
        self.assertIn("framework/scripts/", result.stdout)

    def test_default_mode_warns_without_failing(self):
        self.project_agent.write_text("changed\n", encoding="utf-8")

        result = subprocess.run(
            [
                sys.executable,
                str(ROOT / "check_project_copies.py"),
                "--root",
                str(self.repo),
            ],
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(0, result.returncode)
        self.assertIn("[WARN]", result.stdout)

    def test_fix_aligns_scripts_and_agents(self):
        # 源有新内容，项目副本旧/缺失
        self.agent_source.write_text("new-agent\n", encoding="utf-8")
        self.script_source.write_text("new-script\n", encoding="utf-8")
        extra_script = self.repo / "framework/scripts/framework_versions.py"
        extra_script.write_text(
            'EXPECTED = {"testcase-creator": "1.12.0", "testcase-export": "1.9.0"}\n'
            "from pathlib import Path\n"
            "from datetime import datetime\n"
            "def write_version_file(target_assets, *, synced_at=None):\n"
            "    target_assets.mkdir(parents=True, exist_ok=True)\n"
            "    path = target_assets / 'FRAMEWORK_VERSION'\n"
            "    path.write_text('testcase-creator=1.12.0\\ntestcase-export=1.9.0\\n', encoding='utf-8')\n"
            "    return path\n",
            encoding="utf-8",
        )
        self.project_agent.write_text("old-agent\n", encoding="utf-8")
        self.project_script.write_text("old-script\n", encoding="utf-8")

        messages = CHECKER.fix_project_copies(self.repo)
        self.assertTrue(any("[FIX]" in m for m in messages))
        self.assertEqual("new-agent\n", self.project_agent.read_text(encoding="utf-8"))
        self.assertEqual("new-script\n", self.project_script.read_text(encoding="utf-8"))
        version_file = (
            self.repo / "projects/demo/.testcase-assets/FRAMEWORK_VERSION"
        )
        self.assertTrue(version_file.is_file())
        drifts = CHECKER.scan_project_copies(self.repo)
        # framework_versions 会同步到项目 scripts，源侧也有 → 应无 modified/missing
        remaining = [d for d in drifts if d.kind in ("modified", "missing")]
        self.assertEqual([], remaining)


if __name__ == "__main__":
    unittest.main()
