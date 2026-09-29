#!/usr/bin/env python3
"""Publish generated TTS resources and a downloadable save to GitHub Pages.

Requires git and an authenticated GitHub CLI. Publication is explicit:
pass --confirm-public. The local URL manifest is replaced only after the
deployed files have been downloaded and their hashes checked.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import html
import http.client
import json
from pathlib import Path
import re
import shutil
import ssl
import subprocess
import tempfile
import time
from urllib.parse import quote

from card_catalog import GAME_PATH, ROOT, load_game
from platform_builds import build_native_save, write_json

BUILD_DIR = ROOT / "output" / "build" / "tts"
MANIFEST_PATH = ROOT / "output" / "public_assets.json"
CHECKOUT_PATH = ROOT / "output" / "github-pages"
DEFAULT_REPOSITORY = "Navimar/putiraskola-assets"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pages_url(repository: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Repository must be OWNER/NAME")
    owner, name = repository.split("/")
    if name in (".", ".."):
        raise ValueError("Invalid repository name")
    if name.lower() == f"{owner.lower()}.github.io":
        return f"https://{owner.lower()}.github.io/"
    return f"https://{owner.lower()}.github.io/{name}/"


def asset_records(source: Path, repository: str) -> dict:
    """Only files named in the generated asset manifest may be published."""
    base_url = pages_url(repository)
    generated = json.loads((source / "manifest.json").read_text(encoding="utf-8"))
    records = {}
    for name in sorted(set(generated["assets"].values())):
        path = source / "assets" / name
        if (Path(name).name != name or name in (".", "..")
                or path.resolve().parent != (source / "assets").resolve()
                or not path.is_file() or path.suffix.lower() not in (".jpg", ".jpeg", ".png", ".pdf")):
            raise ValueError(f"Invalid generated asset: {name}")
        checksum = sha256(path)
        records[name] = {
            "url": f"{base_url}assets/{checksum}/{quote(name)}",
            "sha256": checksum,
            "size": path.stat().st_size,
        }
    if not records:
        raise ValueError("No generated resources to publish")
    return {
        "provider": "github-pages",
        "repository": repository,
        "base_url": base_url,
        "assets": records,
    }


def prepare_site(source: Path, checkout: Path, manifest: dict,
                 game_path: Path = GAME_PATH) -> Path:
    """Keep previous hash-addressed files so older saves remain playable."""
    game = load_game(game_path)
    for name, record in manifest["assets"].items():
        target = checkout / "assets" / record["sha256"] / name
        if target.exists():
            if sha256(target) != record["sha256"]:
                raise ValueError(f"Corrupt immutable resource: {target}")
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source / "assets" / name, target)
        if sha256(target) != record["sha256"]:
            raise ValueError(f"Resource changed while preparing publication: {name}")
    save = build_native_save(
        checkout / "downloads",
        {name: record["url"] for name, record in manifest["assets"].items()},
        game_path,
    )
    # Lua is already embedded in the save; only the save is distributed.
    save.with_name("tts_bootstrap.lua").unlink()
    write_json(checkout / "manifest.json", manifest)
    (checkout / ".nojekyll").write_text("", encoding="utf-8")
    links = "\n".join(
        f'<li><a href="{html.escape(record["url"], quote=True)}">{html.escape(name)}</a></li>'
        for name, record in manifest["assets"].items()
    )
    title = html.escape(f'{game["title"]} {game["version"]}')
    (checkout / "index.html").write_text(
        '<!doctype html><html lang="ru"><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        f"<title>{title}</title><body><h1>{title}</h1>"
        f'<p><a href="downloads/{quote(save.name)}" download>Скачать сохранение для Tabletop Simulator</a></p>'
        "<p>Файл сохранения использует опубликованные ресурсы и подходит для сетевой игры.</p>"
        f"<p>Картинки и правила:</p><ul>{links}</ul></body></html>\n",
        encoding="utf-8",
    )
    return save


def run(*args: str, check: bool = True, input_text: str | None = None,
        timeout: int = 180) -> subprocess.CompletedProcess:
    result = subprocess.run(args, check=False, capture_output=True, text=True,
                            input=input_text, timeout=timeout)
    if check and result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return result


def gh_api(endpoint: str, method: str = "GET", payload: dict | None = None,
           allow_missing: bool = False) -> dict:
    if method == "POST" and endpoint.endswith("/git/blobs"):
        # A fixed-length HTTP/1.1 request avoids intermittent rejection of
        # large streamed bodies. The token stays in memory and is sent only
        # to api.github.com over a verified TLS connection.
        token = run("gh", "auth", "token").stdout.strip()
        body = json.dumps(payload).encode("utf-8")
        for attempt in range(3):
            connection = http.client.HTTPSConnection(
                "api.github.com", timeout=120, context=ssl.create_default_context())
            try:
                connection.request("POST", "/" + endpoint, body, {
                    "Authorization": f"Bearer {token}",
                    "User-Agent": "PutiRaskola-publisher",
                    "Accept": "application/vnd.github+json",
                    "Content-Type": "application/json",
                    "Content-Length": str(len(body)),
                })
                response = connection.getresponse()
                result = json.loads(response.read().decode("utf-8"))
                if response.status == 201:
                    return result
                if response.status not in (400, 408, 502, 503, 504) or attempt == 2:
                    raise RuntimeError(f'GitHub HTTP {response.status}: {result.get("message")}')
                print(f"Retrying GitHub upload (HTTP {response.status})", flush=True)
                time.sleep(5)
            finally:
                connection.close()
    args = ["gh", "api", endpoint, "--method", method]
    with tempfile.TemporaryDirectory(prefix="puti-github-request-") as directory:
        if payload is not None:
            request = Path(directory) / "request.json"
            request.write_text(json.dumps(payload), encoding="utf-8")
            args.extend(["--input", str(request)])
        result = run(*args, check=False)
    if result.returncode:
        if allow_missing and ("HTTP 404" in result.stderr
                              or "Git Repository is empty" in result.stdout):
            return {}
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return json.loads(result.stdout) if result.stdout.strip() else {}


def git(checkout: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess:
    # Reuse gh's keyring credentials without writing a token or global git config.
    return run("git", "-c", "credential.helper=",
               "-c", "credential.helper=!gh auth git-credential",
               "-C", str(checkout), *args, check=check)


def ensure_checkout(checkout: Path, repository: str) -> str:
    repository_info = gh_api(f"repos/{repository}", allow_missing=True)
    if not repository_info:
        run("gh", "repo", "create", repository, "--public", "--description",
            "Пути Раскола: опубликованные ресурсы и сохранение Tabletop Simulator")
        repository_info = gh_api(f"repos/{repository}")
    if repository_info["private"]:
        raise ValueError("GitHub Pages resources require a public repository")
    remote = f"https://github.com/{repository}.git"
    branch = repository_info["default_branch"]
    if not (checkout / ".git").is_dir():
        if checkout.exists() and any(checkout.iterdir()):
            raise ValueError(f"Checkout directory is not empty: {checkout}")
        checkout.parent.mkdir(parents=True, exist_ok=True)
        run("git", "-c", "credential.helper=",
            "-c", "credential.helper=!gh auth git-credential",
            "clone", remote, str(checkout))
        if git(checkout, "rev-parse", "--verify", "HEAD", check=False).returncode:
            git(checkout, "symbolic-ref", "HEAD", f"refs/heads/{branch}")
    else:
        if git(checkout, "remote", "get-url", "origin").stdout.strip() != remote:
            raise ValueError("Checkout belongs to another repository")
        if git(checkout, "status", "--porcelain").stdout.strip():
            raise ValueError("Checkout has uncommitted changes; refusing to overwrite them")
        current = git(checkout, "branch", "--show-current").stdout.strip()
        if current != branch:
            raise ValueError(f"Checkout must be on {branch}")
        if git(checkout, "ls-remote", "--heads", "origin", f"refs/heads/{branch}").stdout.strip():
            remote_tree = gh_api(f"repos/{repository}/git/trees/{branch}?recursive=1")
            bootstrap = (not remote_tree.get("truncated") and len(remote_tree["tree"]) == 1
                         and remote_tree["tree"][0]["path"] == ".nojekyll"
                         and remote_tree["tree"][0]["sha"] == "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
            # A failed initial API upload may leave only our bootstrap commit.
            if not bootstrap:
                git(checkout, "pull", "--ff-only", "origin", branch)
    return branch


def upload_commit(checkout: Path, repository: str, branch: str) -> str:
    """Upload individual binary blobs through the API, avoiding a large git push."""
    endpoint = f"repos/{repository}"
    reference = gh_api(f"{endpoint}/git/ref/heads/{branch}", allow_missing=True)
    if not reference:
        gh_api(f"{endpoint}/contents/.nojekyll", "PUT",
               {"message": "Initialize GitHub Pages", "content": "", "branch": branch})
        reference = gh_api(f"{endpoint}/git/ref/heads/{branch}")
    parent = reference["object"]["sha"]
    remote_commit = gh_api(f"{endpoint}/git/commits/{parent}")
    local_tree = git(checkout, "rev-parse", "HEAD^{tree}").stdout.strip()
    if local_tree == remote_commit["tree"]["sha"]:
        return parent
    remote_tree = gh_api(f'{endpoint}/git/trees/{remote_commit["tree"]["sha"]}?recursive=1')
    if remote_tree.get("truncated"):
        raise ValueError("Remote resource tree is too large to compare safely")
    known_blobs = {entry["sha"] for entry in remote_tree["tree"] if entry["type"] == "blob"}
    entries = []
    for line in git(checkout, "ls-tree", "-r", "HEAD").stdout.splitlines():
        metadata, name = line.split("\t", 1)
        mode, kind, checksum = metadata.split()
        if kind != "blob" or mode != "100644":
            raise ValueError(f"Unexpected resource entry: {name}")
        entries.append({"path": name, "mode": mode, "type": kind, "sha": checksum})
        if checksum not in known_blobs:
            result = gh_api(f"{endpoint}/git/blobs", "POST", {
                "content": base64.b64encode((checkout / name).read_bytes()).decode("ascii"),
                "encoding": "base64",
            })
            if result["sha"] != checksum:
                raise ValueError(f"GitHub received different file contents: {name}")
            known_blobs.add(checksum)
            print(f"Uploaded {name}", flush=True)
    tree = gh_api(f"{endpoint}/git/trees", "POST", {"tree": entries})
    if tree["sha"] != local_tree:
        raise ValueError("GitHub received a different resource tree")
    owner = repository.split("/")[0]
    commit = gh_api(f"{endpoint}/git/commits", "POST", {
        "message": "Publish current Puti Raskola TTS resources",
        "tree": tree["sha"], "parents": [parent],
        "author": {"name": owner, "email": f"{owner}@users.noreply.github.com"},
    })
    # A concurrent update is rejected rather than overwritten.
    gh_api(f"{endpoint}/git/refs/heads/{branch}", "PATCH",
           {"sha": commit["sha"], "force": False})
    return commit["sha"]


def publish_site(checkout: Path, repository: str, branch: str) -> str:
    git(checkout, "add", "--", "assets", "downloads", "index.html", ".nojekyll", "manifest.json")
    if git(checkout, "diff", "--cached", "--quiet", check=False).returncode:
        owner = repository.split("/")[0]
        git(checkout, "-c", f"user.name={owner}",
            "-c", f"user.email={owner}@users.noreply.github.com",
            "commit", "-m", "Publish current Puti Raskola TTS resources")
    previous_head = git(checkout, "rev-parse", "HEAD").stdout.strip()
    commit = upload_commit(checkout, repository, branch)
    git(checkout, "fetch", "origin", branch)
    # The API commit has the same tree. Align the cache without changing files.
    if git(checkout, "rev-parse", f"{commit}^{{tree}}").stdout.strip() != git(checkout, "rev-parse", "HEAD^{tree}").stdout.strip():
        raise ValueError("Published commit differs from the prepared resources")
    git(checkout, "update-ref", f"refs/heads/{branch}", commit, previous_head)
    git(checkout, "branch", f"--set-upstream-to=origin/{branch}", branch)
    pages = gh_api(f"repos/{repository}/pages", allow_missing=True)
    source = {"branch": branch, "path": "/"}
    if not pages:
        gh_api(f"repos/{repository}/pages", "POST",
               {"build_type": "legacy", "source": source})
    elif pages.get("source") != source or pages.get("build_type") == "workflow":
        gh_api(f"repos/{repository}/pages", "PUT",
               {"build_type": "legacy", "source": source})
    # Also recovers from a previous failed build without creating a new commit.
    gh_api(f"repos/{repository}/pages/builds", "POST")
    return commit


def wait_for_pages(repository: str, commit: str, timeout: int = 600) -> None:
    deadline = time.monotonic() + timeout
    previous = None
    while time.monotonic() < deadline:
        build = gh_api(f"repos/{repository}/pages/builds/latest", allow_missing=True)
        status = build.get("status", "queued")
        if status != previous:
            print(f"GitHub Pages: {status}", flush=True)
            previous = status
        if build.get("commit") == commit:
            if status == "built":
                return
            if status == "errored":
                raise RuntimeError(f'GitHub Pages build failed: {build.get("error")}')
        time.sleep(5)
    raise TimeoutError("GitHub Pages deployment did not finish")


def verify_file(url: str, expected_sha256: str, expected_size: int) -> None:
    # A real GET catches HTML responses, broken URLs and stale CDN contents.
    result = subprocess.run(
        ["curl", "-fsS", "--retry", "3", "--retry-all-errors",
         "--retry-delay", "5", "--connect-timeout", "20", "--max-time", "120", url],
        check=True, capture_output=True,
    )
    if len(result.stdout) != expected_size or hashlib.sha256(result.stdout).hexdigest() != expected_sha256:
        raise ValueError(f"Published file differs from the local build: {url}")


def verify_publication(manifest: dict, save: Path) -> None:
    for index, (name, record) in enumerate(manifest["assets"].items(), start=1):
        verify_file(record["url"], record["sha256"], record["size"])
        print(f'[{index}/{len(manifest["assets"])}] verified {name}', flush=True)
    verify_file(manifest["base_url"] + "downloads/" + quote(save.name),
                sha256(save), save.stat().st_size)


def save_manifest(path: Path, manifest: dict) -> None:
    temporary = path.with_suffix(".json.tmp")
    write_json(temporary, manifest)
    temporary.replace(path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=BUILD_DIR)
    parser.add_argument("--manifest", type=Path, default=MANIFEST_PATH)
    parser.add_argument("--repository", default=DEFAULT_REPOSITORY)
    parser.add_argument("--checkout", type=Path, default=CHECKOUT_PATH)
    parser.add_argument("--game", type=Path, default=GAME_PATH)
    parser.add_argument("--confirm-public", action="store_true",
                        help="Required acknowledgement that resources and save will be public.")
    args = parser.parse_args()
    if not args.confirm_public:
        raise SystemExit("Refusing to upload without --confirm-public")
    source, checkout = args.source.resolve(), args.checkout.resolve()
    if (checkout == ROOT or checkout.is_relative_to(ROOT / "source")
            or checkout.is_relative_to(source) or source.is_relative_to(checkout)):
        raise SystemExit("Checkout must not overwrite source or build files")
    manifest = asset_records(source, args.repository)
    print(f'Preparing {len(manifest["assets"])} resources for {args.repository}', flush=True)
    branch = ensure_checkout(checkout, args.repository)
    save = prepare_site(source, checkout, manifest, args.game.resolve())
    print("Uploading resources to GitHub", flush=True)
    commit = publish_site(checkout, args.repository, branch)
    wait_for_pages(args.repository, commit)
    verify_publication(manifest, save)
    save_manifest(args.manifest.resolve(), manifest)
    print(f"Published {len(manifest['assets'])} resources: {manifest['base_url']}", flush=True)
    print(f"Public URL manifest: {args.manifest.resolve()}", flush=True)
    print("Use build_game.py --public-assets to build the network save from these URLs.")


if __name__ == "__main__":
    main()
