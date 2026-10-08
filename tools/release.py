"""Build locally without credentials; --publish releases from GitHub Actions main."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PORTAL = "https://mods.factorio.com"


def command(*args):
    return subprocess.check_output(args, cwd=ROOT)


def included(name):
    return (name in {"info.json", "changelog.txt", "thumbnail.png", "License.txt"}
            or ("/" not in name and name.endswith(".lua"))
            or name.startswith(("scripts/", "locale/", "migrations/")))


def normalized(name, data):
    return data if name.endswith(".png") else data.replace(b"\r\n", b"\n")


def files_at(ref=None):
    if ref:
        names = command("git", "ls-tree", "-r", "--name-only", ref).decode().splitlines()
        return {n: normalized(n, command("git", "show", f"{ref}:{n}"))
                for n in names if included(n)}
    return {p.relative_to(ROOT).as_posix(): normalized(p.name, p.read_bytes())
            for p in ROOT.rglob("*") if p.is_file() and included(p.relative_to(ROOT).as_posix())}


def version_tuple(version):
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version):
        raise ValueError("Version must be three numbers, e.g. 1.1.1")
    result = tuple(map(int, version.split(".")))
    if max(result) > 65535:
        raise ValueError("Version components must be at most 65535")
    return result


def release_notes(changelog, version):
    sections = re.split(r"(?m)^-{99}\s*\n", changelog)
    entries = [s for s in sections if s.startswith("Version: ")]
    if not entries or entries[0].splitlines()[0] != f"Version: {version}":
        raise ValueError("Latest changelog entry must match info.json")
    return entries[0].strip() + "\n"


def build(files, output):
    metadata = json.loads(files["info.json"])
    name, version = metadata["name"], metadata["version"]
    version_tuple(version)
    if not re.fullmatch(r"[A-Za-z0-9_-]+", name):
        raise ValueError("Invalid mod name")
    notes = release_notes(files["changelog.txt"].decode(), version)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"{name}_{version}.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for path, data in sorted(files.items()):
            entry = zipfile.ZipInfo(f"{name}_{version}/{path}", (2020, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            z.writestr(entry, data)
    notes_path = output / "release-notes.txt"
    notes_path.write_text(notes, encoding="utf-8")
    return metadata, archive, notes_path


def request_json(url, data=None, headers=None):
    request = urllib.request.Request(url, data=data, headers=headers or {})
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            result = json.load(response)
    except urllib.error.HTTPError as error:
        # Do not log signed upload URLs, request headers, or server response bodies.
        raise RuntimeError(f"API request failed with HTTP {error.code}") from None
    except urllib.error.URLError:
        raise RuntimeError("API connection failed; rerun the workflow to retry") from None
    if result.get("error"):
        raise RuntimeError("Factorio API rejected the request")
    return result


def upload_portal(name, archive):
    token = os.environ.get("FACTORIO_API_KEY")
    if not token:
        raise RuntimeError("Missing FACTORIO_API_KEY repository secret")
    result = request_json(PORTAL + "/api/v2/mods/releases/init_upload",
                          urllib.parse.urlencode({"mod": name}).encode(),
                          {"Authorization": "Bearer " + token})
    url = result["upload_url"]
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or not (parsed.hostname == "factorio.com"
            or (parsed.hostname or "").endswith(".factorio.com")):
        raise RuntimeError("Unexpected Factorio upload host")
    boundary = uuid.uuid4().hex
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; '
            f'filename="{archive.name}"\r\nContent-Type: application/zip\r\n\r\n').encode()
    body += archive.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
    result = request_json(url, body, {"Content-Type": "multipart/form-data; boundary=" + boundary})
    if result.get("success") is not True:
        raise RuntimeError("Factorio did not confirm upload success")


def publish(files, metadata, archive, notes):
    if os.environ.get("GITHUB_REF") != "refs/heads/main":
        raise RuntimeError("Publishing is only permitted from main")
    name, version = metadata["name"], metadata["version"]
    tag = "v" + version
    tag_exists = subprocess.run(["git", "rev-parse", "--verify", "--quiet", "refs/tags/" + tag],
                                cwd=ROOT, stdout=subprocess.DEVNULL).returncode == 0
    if tag_exists and files_at(tag) != files:
        raise RuntimeError("Mod files changed since this version was tagged. Update info.json and changelog.txt.")
    portal = request_json(PORTAL + "/api/mods/" + name)
    versions = [r["version"] for r in portal["releases"]]
    if any(version_tuple(v) > version_tuple(version) for v in versions):
        raise RuntimeError("A newer version is already on the mod portal")
    if version in versions and not tag_exists:
        raise RuntimeError("Existing portal release needs a matching baseline tag before automation can adopt it")
    if version not in versions and not os.environ.get("FACTORIO_API_KEY"):
        raise RuntimeError("Missing FACTORIO_API_KEY repository secret")
    # Query releases without interpreting authentication/network failures as absence.
    releases = json.loads(command("gh", "api", "--paginate", "--slurp",
                                  "repos/{owner}/{repo}/releases"))
    existing = next((r for page in releases for r in page if r["tag_name"] == tag), None)
    if existing:
        assets = [a for a in existing["assets"] if a["name"] == archive.name]
        if assets:
            data = command("gh", "api", "-H", "Accept: application/octet-stream",
                           f"repos/{{owner}}/{{repo}}/releases/assets/{assets[0]['id']}")
            if data != archive.read_bytes():
                raise RuntimeError("Existing GitHub asset differs; published versions cannot be overwritten")
        else:
            if not existing["draft"]:
                raise RuntimeError("Published GitHub release is missing its ZIP; inspect it before retrying")
            command("gh", "release", "upload", tag, str(archive))
    else:
        command("gh", "release", "create", tag, str(archive), "--draft", "--target",
                os.environ["GITHUB_SHA"], "--title", f"Rantz Research {version}",
                "--notes-file", str(notes))
    # Preserve a remote tag even if upload fails, so retries cannot substitute code.
    if not tag_exists:
        command("git", "tag", tag, os.environ["GITHUB_SHA"])
        command("git", "push", "origin", "refs/tags/" + tag)
    if version not in versions:
        upload_portal(name, archive)
    if not existing or existing["draft"]:
        command("gh", "release", "edit", tag, "--draft=false", "--latest")
    print(f"Released {name} {version} (existing uploads retained).")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--publish", action="store_true")
    args = parser.parse_args()
    os.chdir(ROOT)
    files = files_at()
    metadata, archive, notes = build(files, ROOT / "dist")
    print(f"Packaged {archive.name}")
    if args.publish:
        publish(files, metadata, archive, notes)


if __name__ == "__main__":
    main()
