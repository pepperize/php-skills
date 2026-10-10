"""Exercise example copying and protect existing project files."""

import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SKILL = Path(__file__).resolve().parents[1]
EXAMPLES = {"sqlite": "sqlite-example", "mariadb": "mariadb-example"}


class CopyPipelineTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)

    def copy_pipeline(self, database, target, *arguments, skill=SKILL):
        return subprocess.run(
            [sys.executable, str(skill / "scripts/copy-pipeline.py"), "--database", database, "--target", str(target), *arguments],
            capture_output=True, text=True,
        )

    def test_each_database_copies_exact_pipeline_bytes_and_modes(self):
        for database, example in EXAMPLES.items():
            with self.subTest(database=database):
                target = self.directory / database
                actual = self.copy_pipeline(database, target)
                self.assertEqual(0, actual.returncode, actual.stderr)
                source = SKILL / "assets" / example
                snapshot = json.loads((source / "manifest.json").read_text())
                copied = {str(path.relative_to(target)) for path in target.rglob("*") if path.is_file()}
                self.assertEqual(set(snapshot["copy_files"]), copied)
                for relative in copied:
                    self.assertEqual(snapshot["files"][relative], hashlib.sha256((target / relative).read_bytes()).hexdigest())
                    self.assertEqual((source / relative).stat().st_mode & 0o777, (target / relative).stat().st_mode & 0o777)

    def test_existing_file_stops_all_writes(self):
        target = self.directory / "project"
        existing = target / ".github/workflows/build.yml"
        existing.parent.mkdir(parents=True)
        existing.write_text("existing workflow\n")
        actual = self.copy_pipeline("mariadb", target)
        self.assertNotEqual(0, actual.returncode)
        self.assertIn("Refusing to overwrite", actual.stderr)
        self.assertEqual("existing workflow\n", existing.read_text())
        self.assertEqual([existing], [path for path in target.rglob("*") if path.is_file()])

    def test_symlink_parent_cannot_write_outside_project(self):
        target = self.directory / "project"
        outside = self.directory / "outside"
        target.mkdir()
        outside.mkdir()
        (target / "deployment").symlink_to(outside, target_is_directory=True)
        actual = self.copy_pipeline("sqlite", target)
        self.assertNotEqual(0, actual.returncode)
        self.assertIn("Destination parent is a symlink", actual.stderr)
        self.assertEqual([], list(outside.iterdir()))
        self.assertFalse((target / ".github").exists())

    def test_dry_run_does_not_create_target(self):
        target = self.directory / "project"
        actual = self.copy_pipeline("sqlite", target, "--dry-run")
        self.assertEqual(0, actual.returncode, actual.stderr)
        self.assertIn(".github/workflows/build.yml", actual.stdout)
        self.assertFalse(target.exists())

    def test_changed_template_stops_before_creating_target(self):
        skill = self.directory / "skill"
        shutil.copytree(SKILL, skill)
        source = skill / "assets/mariadb-example/deployment/deploy-release.sh"
        source.write_text(source.read_text() + "\n# changed snapshot\n")
        target = self.directory / "project"
        actual = self.copy_pipeline("mariadb", target, skill=skill)
        self.assertNotEqual(0, actual.returncode)
        self.assertIn("Template hash mismatch", actual.stderr)
        self.assertFalse(target.exists())

    def test_site_reaches_paths_workflows_and_apache_rules_for_both_profiles(self):
        for database in EXAMPLES:
            with self.subTest(database=database):
                target = self.directory / database
                actual = self.copy_pipeline(database, target, "--site", "demo.example.org")
                self.assertEqual(0, actual.returncode, actual.stderr)
                for file in target.rglob("*"):
                    if file.is_file():
                        self.assertNotIn(b"example.com", file.read_bytes())
                        self.assertNotIn(b"example\\.com", file.read_bytes())
                self.assertIn("html/demo.example.org/staging", (target / "deployment/deploy-release.sh").read_text())
                self.assertIn("demo\\.example\\.org", (target / "deployment/apache/production.htaccess").read_text())
                self.assertIn("files/demo.example.org/production", (target / ".github/workflows/deploy-production.yml").read_text())

    def test_invalid_site_cannot_create_target(self):
        for site in ("../outside", "https://example.com", "example.com;touch", "-example.com", "a..com"):
            with self.subTest(site=site):
                target = self.directory / "invalid"
                actual = self.copy_pipeline("sqlite", target, "--site", site)
                self.assertNotEqual(0, actual.returncode)
                self.assertFalse(target.exists())


if __name__ == "__main__":
    unittest.main()
