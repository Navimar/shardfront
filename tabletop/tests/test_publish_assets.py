"""Publication regressions: immutable URLs, export boundaries and failed downloads."""

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import ssl
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import publish_assets as publish
from platform_builds import strings


class PublicationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="puti-publication-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / "tts"
        self.assets = self.source / "assets"
        self.assets.mkdir(parents=True)
        template = json.loads((ROOT / "source/templates/tts.json").read_text())
        names = {value.removeprefix("asset://") for value in strings(template)
                 if value.startswith("asset://")}
        for color in ("blue", "red"):
            names.update(f"cards_{color}_{index}.jpg" for index in range(1, 7))
            names.add(f"back_{color}.jpeg")
        self.generated = {"assets": {name: name for name in names}}
        self.write_generated()
        for name in names:
            (self.assets / name).write_bytes(name.encode())

    def write_generated(self):
        (self.source / "manifest.json").write_text(json.dumps(self.generated))

    def test_binary_upload_uses_a_fixed_length_verified_https_request(self):
        with (patch.object(publish, "run", return_value=subprocess.CompletedProcess([], 0, stdout="test-token\n")),
              patch.object(publish.http.client, "HTTPSConnection") as connection):
            response = connection.return_value.getresponse.return_value
            response.status = 201
            response.read.return_value = b'{"sha":"uploaded-blob"}'
            result = publish.gh_api("repos/Navimar/putiraskola-assets/git/blobs", "POST",
                                    {"content": "AP8=", "encoding": "base64"})
            self.assertEqual(result["sha"], "uploaded-blob")
            context = connection.call_args.kwargs["context"]
            self.assertTrue(context.check_hostname)
            self.assertEqual(context.verify_mode, ssl.CERT_REQUIRED)
            method, endpoint, body, headers = connection.return_value.request.call_args.args
            self.assertEqual(method, "POST")
            self.assertEqual(json.loads(body)["content"], "AP8=")
            self.assertEqual(int(headers["Content-Length"]), len(body))
            self.assertEqual(connection.call_args.args[0], "api.github.com")

    def test_updated_images_get_new_urls_and_old_saves_keep_their_files(self):
        checkout = self.root / "site"
        (self.assets / "private-not-in-manifest.jpg").write_bytes(b"private")
        first = publish.asset_records(self.source, "Navimar/putiraskola-assets")
        save = publish.prepare_site(self.source, checkout, first)
        previous_files = {path.relative_to(checkout): path.read_bytes()
                          for path in (checkout / "assets").rglob("*") if path.is_file()}
        self.assertEqual(len(previous_files), len(first["assets"]))
        old = copy.deepcopy(first["assets"]["cards_blue_1.jpg"])
        self.assertEqual(first, publish.asset_records(self.source, "Navimar/putiraskola-assets"))

        (self.assets / "cards_blue_1.jpg").write_bytes(b"updated image")
        second = publish.asset_records(self.source, "Navimar/putiraskola-assets")
        self.assertNotEqual(old["url"], second["assets"]["cards_blue_1.jpg"]["url"])
        self.assertEqual(first["assets"]["cards_red_1.jpg"], second["assets"]["cards_red_1.jpg"])
        publish.prepare_site(self.source, checkout, second)
        for path, content in previous_files.items():
            self.assertEqual((checkout / path).read_bytes(), content)
        exported = json.loads(save.read_text())
        self.assertNotIn("file://", save.read_text())
        self.assertNotIn("catbox", save.read_text())
        self.assertIn(second["assets"]["cards_blue_1.jpg"]["url"], exported["LuaScript"])
        self.assertNotIn(old["url"], exported["LuaScript"])

    def test_manifest_cannot_publish_files_outside_generated_assets(self):
        outside = self.root / "private.jpg"
        outside.write_bytes(b"private")
        self.generated["assets"]["escape"] = "../private.jpg"
        self.write_generated()
        with self.assertRaisesRegex(ValueError, "Invalid generated asset"):
            publish.asset_records(self.source, "Navimar/putiraskola-assets")
        del self.generated["assets"]["escape"]
        (self.assets / "linked.jpg").symlink_to(outside)
        self.generated["assets"]["link"] = "linked.jpg"
        self.write_generated()
        with self.assertRaisesRegex(ValueError, "Invalid generated asset"):
            publish.asset_records(self.source, "Navimar/putiraskola-assets")

    def test_bad_download_does_not_replace_working_local_url_manifest(self):
        data = b"expected image"
        checksum = hashlib.sha256(data).hexdigest()
        response = subprocess.CompletedProcess([], 0, stdout=b"<html>unavailable</html>")
        with patch.object(publish.subprocess, "run", return_value=response):
            with self.assertRaisesRegex(ValueError, "differs from the local build"):
                publish.verify_file("https://example.test/image.jpg", checksum, len(data))

        manifest_path = self.root / "public_assets.json"
        original = b'{"provider":"previous-working-host"}\n'
        manifest_path.write_bytes(original)
        args = ["publish_assets.py", "--source", str(self.source), "--checkout", str(self.root / "site"),
                "--manifest", str(manifest_path), "--confirm-public"]
        with (patch.object(sys, "argv", args),
              patch.object(publish, "ensure_checkout", return_value="main"),
              patch.object(publish, "publish_site", return_value="commit"),
              patch.object(publish, "wait_for_pages"),
              patch.object(publish, "verify_publication", side_effect=ValueError("bad download"))):
            with self.assertRaisesRegex(ValueError, "bad download"):
                publish.main()
        self.assertEqual(manifest_path.read_bytes(), original)

    def test_bad_api_upload_never_updates_the_published_branch(self):
        checkout = self.root / "site"
        manifest = publish.asset_records(self.source, "Navimar/putiraskola-assets")
        publish.prepare_site(self.source, checkout, manifest)
        publish.run("git", "init", "--initial-branch=main", str(checkout))
        publish.git(checkout, "add", ".")
        publish.git(checkout, "-c", "user.name=Test", "-c", "user.email=test@example.test",
                    "commit", "-m", "Prepared resources")

        def api(endpoint, method="GET", payload=None, **kwargs):
            if "/git/ref/heads/" in endpoint:
                return {"object": {"sha": "parent"}}
            if endpoint.endswith("/git/commits/parent"):
                return {"tree": {"sha": "previous-tree"}}
            if "/git/trees/" in endpoint:
                return {"tree": []}
            if endpoint.endswith("/git/blobs"):
                return {"sha": "incorrect-blob-hash"}
            self.fail(f"Publication advanced after a corrupt upload: {method} {endpoint}")

        with patch.object(publish, "gh_api", side_effect=api):
            with self.assertRaisesRegex(ValueError, "different file contents"):
                publish.upload_commit(checkout, "Navimar/putiraskola-assets", "main")


if __name__ == "__main__":
    unittest.main()
