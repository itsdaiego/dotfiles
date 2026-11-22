#!/usr/bin/env python3

import configparser
import os
from pathlib import Path
import subprocess
import tempfile


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "firefox-session-backup.py"


def write_session(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"mozLz40\0" + payload)


def run_backup(firefox_root: Path, backup_root: Path, timestamp: str) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env.update(
        {
            "FIREFOX_ROOT": str(firefox_root),
            "FIREFOX_SESSION_BACKUP_ROOT": str(backup_root),
            "FIREFOX_SESSION_BACKUP_KEEP": "2",
            "FIREFOX_SESSION_BACKUP_NOW": timestamp,
        }
    )
    result = subprocess.run(
        ["/usr/bin/python3", str(SCRIPT)],
        check=False,
        capture_output=True,
        text=True,
        env=env,
    )
    assert result.returncode == 0, result.stderr
    return result


def snapshots(backup_root: Path, profile_name: str) -> list[Path]:
    root = backup_root / profile_name
    return sorted(path for path in root.iterdir() if path.is_dir())


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="firefox-session-backup-test.") as temp_dir:
        root = Path(temp_dir)
        firefox_root = root / "Firefox"
        backup_root = root / "Backups"
        profile_name = "abc.default-release"
        profile = firefox_root / "Profiles" / profile_name
        source = profile / "sessionstore-backups"

        firefox_root.mkdir(parents=True)
        config = configparser.ConfigParser()
        config["General"] = {"StartWithLastProfile": "1", "Version": "2"}
        config["Profile0"] = {
            "Name": "default-release",
            "IsRelative": "1",
            "Path": f"Profiles/{profile_name}",
        }
        config["InstallABC"] = {"Default": f"Profiles/{profile_name}", "Locked": "1"}
        with (firefox_root / "profiles.ini").open("w") as profiles_file:
            config.write(profiles_file)

        write_session(source / "recovery.jsonlz4", b"first recovery")
        write_session(source / "recovery.baklz4", b"first backup")
        write_session(source / "previous.jsonlz4", b"previous session")

        first = run_backup(firefox_root, backup_root, "20261119T150000Z")
        assert "Saved Firefox session" in first.stdout
        first_snapshots = snapshots(backup_root, profile_name)
        assert [path.name for path in first_snapshots] == ["20261119T150000Z"]
        first_snapshot = first_snapshots[0]
        for filename in ("recovery.jsonlz4", "recovery.baklz4", "previous.jsonlz4"):
            assert (first_snapshot / filename).read_bytes() == (source / filename).read_bytes()
        manifest = (first_snapshot / "manifest.txt").read_text()
        assert "profile=abc.default-release\n" in manifest
        assert "source=Profiles/abc.default-release/sessionstore-backups\n" in manifest

        duplicate = run_backup(firefox_root, backup_root, "20261119T150500Z")
        assert "Session unchanged" in duplicate.stdout
        assert [path.name for path in snapshots(backup_root, profile_name)] == ["20261119T150000Z"]

        write_session(source / "recovery.jsonlz4", b"second recovery")
        run_backup(firefox_root, backup_root, "20261119T151000Z")
        write_session(source / "recovery.jsonlz4", b"third recovery")
        run_backup(firefox_root, backup_root, "20261119T151500Z")

        retained = snapshots(backup_root, profile_name)
        assert [path.name for path in retained] == ["20261119T151000Z", "20261119T151500Z"]
        assert not first_snapshot.exists()

    print("Firefox session backup checks passed.")


if __name__ == "__main__":
    main()
