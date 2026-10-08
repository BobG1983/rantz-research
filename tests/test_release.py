import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from tools import release


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.files = {
            "info.json": json.dumps({"name": "rantz-research", "version": "1.1.0"}).encode(),
            "changelog.txt": ("-" * 99 + "\nVersion: 1.1.0\nDate: 2026-10-07\n  Features:\n    - Test\n").encode(),
            "control.lua": b"require('scripts.events')\n",
        }
        self.metadata, self.archive, self.notes = release.build(self.files, Path(self.temp.name))

    def test_package_is_repeatable_and_has_versioned_root(self):
        first = self.archive.read_bytes()
        release.build(self.files, Path(self.temp.name))
        self.assertEqual(first, self.archive.read_bytes())
        with zipfile.ZipFile(self.archive) as archive:
            self.assertEqual(sorted(archive.namelist()),
                             sorted("rantz-research_1.1.0/" + n for n in self.files))

    def test_distribution_excludes_development_files(self):
        for name in [".git/config", "tests/engine_dynamic.lua", "tools/release.py",
                     ".github/workflows/release.yml", "dist/old.zip", "README.md"]:
            self.assertFalse(release.included(name), name)
        for name in ["scripts/gui.lua", "locale/en/en.cfg", "thumbnail.png", "License.txt"]:
            self.assertTrue(release.included(name), name)

    def test_changelog_must_match_version(self):
        with self.assertRaises(ValueError):
            release.release_notes(self.files["changelog.txt"].decode(), "1.1.1")

    def test_line_endings_normalized(self):
        self.assertEqual(release.normalized("control.lua", b"a\r\nb"), b"a\nb")
        self.assertEqual(release.normalized("thumbnail.png", b"a\r\nb"), b"a\r\nb")

    def publish(self, versions, existing=None, tag=True, fail_upload=False):
        calls = []
        def command(*args):
            calls.append(args)
            if args[:2] == ("gh", "api"):
                if "--paginate" in args:
                    return json.dumps([[existing] if existing else []]).encode()
                return self.archive.read_bytes()
            return b""
        with patch.dict(release.os.environ, {"GITHUB_REF": "refs/heads/main", "GITHUB_SHA": "abc",
                                            "FACTORIO_API_KEY": "test"}), \
             patch.object(release.subprocess, "run") as run, \
             patch.object(release, "files_at", return_value=self.files), \
             patch.object(release, "request_json", return_value={"releases": [{"version": v} for v in versions]}), \
             patch.object(release, "command", side_effect=command), \
             patch.object(release, "upload_portal", side_effect=RuntimeError("upload failed") if fail_upload else None) as upload:
            run.return_value.returncode = 0 if tag else 1
            if fail_upload:
                with self.assertRaisesRegex(RuntimeError, "upload failed"):
                    release.publish(self.files, self.metadata, self.archive, self.notes)
            else:
                release.publish(self.files, self.metadata, self.archive, self.notes)
            return calls, upload.call_count

    def test_existing_portal_version_is_adopted_without_upload(self):
        calls, uploads = self.publish(["1.1.0"])
        self.assertEqual(uploads, 0)
        self.assertTrue(any(c[:3] == ("gh", "release", "create") for c in calls))

    def test_retry_after_portal_success_finishes_draft(self):
        calls, uploads = self.publish(["1.1.0"], {"tag_name": "v1.1.0", "draft": True,
                                                    "assets": [{"name": self.archive.name, "id": 7}]})
        self.assertEqual(uploads, 0)
        self.assertEqual(calls[-1][:3], ("gh", "release", "edit"))

    def test_failed_upload_leaves_github_draft_and_tag(self):
        calls, uploads = self.publish([], tag=False, fail_upload=True)
        self.assertEqual(uploads, 1)
        self.assertTrue(any(c[:2] == ("git", "push") for c in calls))
        self.assertFalse(any(c[:3] == ("gh", "release", "edit") for c in calls))

    def test_changed_files_cannot_reuse_tag(self):
        with patch.dict(release.os.environ, {"GITHUB_REF": "refs/heads/main"}), \
             patch.object(release.subprocess, "run") as run, \
             patch.object(release, "files_at", return_value={}), \
             patch.object(release, "request_json") as request:
            run.return_value.returncode = 0
            with self.assertRaisesRegex(RuntimeError, "Mod files changed"):
                release.publish(self.files, self.metadata, self.archive, self.notes)
            request.assert_not_called()

    def test_older_version_cannot_replace_newer(self):
        with self.assertRaisesRegex(RuntimeError, "newer version"):
            self.publish(["1.2.0"])

    def test_missing_baseline_requires_explicit_adoption(self):
        with self.assertRaisesRegex(RuntimeError, "baseline tag"):
            self.publish(["1.1.0"], tag=False)

    def test_non_main_cannot_publish(self):
        with patch.dict(release.os.environ, {"GITHUB_REF": "refs/heads/develop"}):
            with self.assertRaisesRegex(RuntimeError, "only permitted from main"):
                release.publish(self.files, self.metadata, self.archive, self.notes)


if __name__ == "__main__":
    unittest.main()
