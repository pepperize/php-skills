"""Verify confirmed deployment profiles and preservation of project instructions."""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


INSTALLER = Path(__file__).with_name("install-agent-instructions.py")


class InstallAgentInstructionsTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.agents = self.root / "AGENTS.md"

    def install(self, *arguments):
        return subprocess.run(
            [sys.executable, str(INSTALLER), *arguments],
            cwd=self.root, capture_output=True, text=True,
        )

    def test_unconfirmed_project_gets_self_review_without_activation_markers(self):
        actual = self.install()
        self.assertEqual(0, actual.returncode, actual.stderr)
        content = self.agents.read_text()
        self.assertIn("## PHP Skill Self Review", content)
        self.assertNotIn("<!-- php-skills:hosting:shared -->", content)
        self.assertNotIn("<!-- php-skills:database:", content)

    def test_each_confirmed_database_is_idempotent_and_preserves_project_instructions(self):
        for database in ("sqlite", "mariadb"):
            with self.subTest(database=database):
                self.agents.write_text("# Project\n\nKeep this existing rule.\n")
                actual = self.install("--hosting", "shared", "--database", database)
                self.assertEqual(0, actual.returncode, actual.stderr)
                content = self.agents.read_text()
                self.assertIn("Keep this existing rule.", content)
                self.assertEqual(1, content.count("<!-- php-skills:hosting:shared -->"))
                self.assertEqual(1, content.count(f"<!-- php-skills:database:{database} -->"))
                self.assertEqual(0, self.install("--hosting", "shared", "--database", database).returncode)
                self.assertEqual(content, self.agents.read_text())
                self.assertEqual(0, self.install().returncode)
                self.assertEqual(content, self.agents.read_text())

    def test_changing_database_replaces_old_profile(self):
        self.assertEqual(0, self.install("--hosting", "shared", "--database", "sqlite").returncode)
        self.assertEqual(0, self.install("--hosting", "shared", "--database", "mariadb").returncode)
        content = self.agents.read_text()
        self.assertIn("<!-- php-skills:database:mariadb -->", content)
        self.assertNotIn("<!-- php-skills:database:sqlite -->", content)

    def test_other_hosting_removes_profile_and_keeps_unrelated_instructions(self):
        self.agents.write_text("# Project\n\nExisting rule.\n")
        self.assertEqual(0, self.install("--hosting", "shared", "--database", "sqlite").returncode)
        self.assertEqual(0, self.install("--hosting", "other").returncode)
        content = self.agents.read_text()
        self.assertIn("Existing rule.", content)
        self.assertIn("## PHP Skill Self Review", content)
        self.assertNotIn("<!-- php-skills:hosting:shared -->", content)
        self.assertNotIn("<!-- php-skills:database:", content)

    def test_claude_target_still_records_profile_in_root_agents(self):
        claude = self.root / "CLAUDE.md"
        claude.write_text("# Claude instructions\n")
        actual = self.install("--hosting", "shared", "--database", "mariadb")
        self.assertEqual(0, actual.returncode, actual.stderr)
        self.assertIn("## PHP Skill Self Review", claude.read_text())
        self.assertNotIn("<!-- php-skills:hosting:shared -->", claude.read_text())
        self.assertIn("<!-- php-skills:database:mariadb -->", self.agents.read_text())

    def test_invalid_answers_do_not_write_files(self):
        for arguments in (("--hosting", "shared"), ("--database", "sqlite"), ("--hosting", "other", "--database", "mariadb")):
            with self.subTest(arguments=arguments):
                actual = self.install(*arguments)
                self.assertNotEqual(0, actual.returncode)
                self.assertFalse(self.agents.exists())

    def test_malformed_profile_cannot_partially_update_claude(self):
        claude = self.root / "CLAUDE.md"
        original = "# Keep Claude instructions\n"
        claude.write_text(original)
        broken = "<!-- php-skills:deployment-profile:start -->\n"
        self.agents.write_text(broken)
        actual = self.install("--file", "CLAUDE.md", "--hosting", "shared", "--database", "sqlite")
        self.assertNotEqual(0, actual.returncode)
        self.assertEqual(original, claude.read_text())
        self.assertEqual(broken, self.agents.read_text())


if __name__ == "__main__":
    unittest.main()
