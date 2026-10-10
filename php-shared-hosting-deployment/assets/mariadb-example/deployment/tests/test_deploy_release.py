"""Exercise the copied runner and remote activation in an isolated hosting tree."""

import os
import shutil
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
COMMIT = "a" * 40
RELEASE = COMMIT + "-42-1"


class DeployReleaseTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.home = self.directory / "host"
        self.private = self.home / "files/example.com/staging"
        self.private.mkdir(parents=True)
        self.configuration = self.private / ".env"
        self.configuration.write_text("DB_NAME=synthetic_staging\n")
        self.deploy = self.home / "html/example.com/staging"
        self.deploy.mkdir(parents=True)
        self.bin = self.directory / "bin"
        self.bin.mkdir()
        self.environment = {
            **os.environ,
            "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
            "HOME": str(self.home),
            "RUNNER_TEMP": str(self.directory / "runner"),
            "DEPLOYMENT_NAME": "staging",
            "DEPLOY_PATH": "html/example.com/staging",
            "PRIVATE_PATH": "files/example.com/staging",
            "EXPECTED_COMMIT": COMMIT,
            "RELEASE_ID": RELEASE,
            "SSH_HOST": "ssh.example.com",
            "SSH_HOST_KEY": "ssh.example.com ssh-ed25519 fixture",
            "SSH_USERNAME": "fixture",
            "SSH_PASSWORD": "fixture-secret",
            "SSH_PORT": "22",
        }
        self.write_executable("sshpass", """#!/usr/bin/python3
import os, pathlib, shutil, subprocess, sys
args = sys.argv[2:]
if args[0] == 'ssh':
    sys.exit(subprocess.run(['bash', '-c', args[-1]]).returncode)
if args[0] == 'scp':
    target = pathlib.Path(os.environ['HOME']) / args[-1].split(':', 1)[1]
    shutil.copyfile(args[-2], target)
    if os.environ.get('CORRUPT_UPLOAD'):
        with target.open('ab') as stream: stream.write(b'corrupt')
    sys.exit(0)
sys.exit(2)
""")
        self.write_executable("php", """#!/usr/bin/env bash
if [[ "${FAIL_MIGRATION:-}" == 1 && "${2:-}" == migrate ]]; then exit 9; fi
""")
        payload = self.directory / "payload"
        payload.mkdir()
        for name in ("backend/public/index.php", "vendor/autoload.php", "vendor/composer/platform_check.php"):
            file = payload / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text("<?php\n")
        (payload / "source-commit").write_text(COMMIT + "\n")
        shutil.copytree(ROOT / "deployment/apache", payload / "deployment/apache")
        shutil.copyfile(ROOT / "deployment/release-retention.sh", payload / "deployment/release-retention.sh")
        shutil.copyfile(ROOT / "deployment/prepare.sh", payload / "deployment/prepare.sh")
        archive = self.directory / "application.tar.gz"
        with tarfile.open(archive, "w:gz") as stream:
            for file in sorted(payload.rglob("*")):
                if file.is_file(): stream.add(file, arcname=str(file.relative_to(payload)))
        self.environment["DEPLOYMENT_ARCHIVE"] = str(archive)

    def write_executable(self, name, content):
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)

    def deploy_release(self, **changes):
        return subprocess.run(
            ["bash", "deployment/deploy-release.sh"], cwd=ROOT,
            env={**self.environment, **changes}, capture_output=True, text=True,
        )

    def test_first_release_activates_without_changing_private_configuration(self):
        actual = self.deploy_release()
        self.assertEqual(0, actual.returncode, actual.stdout + actual.stderr)
        self.assertEqual(self.deploy / "releases" / RELEASE, (self.deploy / "current").resolve())
        self.assertEqual("DB_NAME=synthetic_staging\n", self.configuration.read_text())
        self.assertIn("# Managed by application staging deployment", (self.deploy / ".htaccess").read_text())
        self.assertTrue((self.deploy / ".pending-release").exists())

    def test_unmanaged_dispatcher_is_preserved(self):
        (self.deploy / ".htaccess").write_text("unmanaged site\n")
        actual = self.deploy_release()
        self.assertNotEqual(0, actual.returncode)
        self.assertFalse((self.deploy / "current").exists())
        self.assertEqual("unmanaged site\n", (self.deploy / ".htaccess").read_text())

    def test_missing_private_configuration_cannot_activate(self):
        self.configuration.unlink()
        actual = self.deploy_release()
        self.assertNotEqual(0, actual.returncode)
        self.assertIn("validating the private environment", actual.stderr)
        self.assertFalse((self.deploy / "current").exists())

    def test_corrupt_upload_cannot_activate(self):
        actual = self.deploy_release(CORRUPT_UPLOAD="1")
        self.assertNotEqual(0, actual.returncode)
        self.assertIn("archive digest differs", actual.stderr)
        self.assertFalse((self.deploy / "current").exists())

    def test_migration_failure_cannot_activate(self):
        actual = self.deploy_release(FAIL_MIGRATION="1")
        self.assertNotEqual(0, actual.returncode)
        self.assertIn("preparing the application", actual.stderr)
        self.assertFalse((self.deploy / "current").exists())
        self.assertEqual("DB_NAME=synthetic_staging\n", self.configuration.read_text())

    def test_archive_from_another_commit_is_rejected_before_upload(self):
        actual = self.deploy_release(EXPECTED_COMMIT="b" * 40)
        self.assertNotEqual(0, actual.returncode)
        self.assertFalse((self.deploy / "releases").exists())

    def test_unsafe_release_identity_is_rejected_before_upload(self):
        for identity in ("..", ".", "../outside"):
            with self.subTest(identity=identity):
                actual = self.deploy_release(RELEASE_ID=identity)
                self.assertNotEqual(0, actual.returncode)
                self.assertFalse((self.deploy / "releases").exists())
