#!/usr/bin/env python3

import configparser
from datetime import datetime, timezone
import fcntl
import hashlib
import os
from pathlib import Path
import sys
from typing import Optional


SESSION_FILES = (
    "recovery.jsonlz4",
    "recovery.baklz4",
    "previous.jsonlz4",
)
MOZLZ4_HEADER = b"mozLz40\0"


def default_firefox_root() -> Path:
    return Path.home() / "Library" / "Application Support" / "Firefox"


def default_backup_root() -> Path:
    return Path.home() / "Library" / "Application Support" / "Firefox Session Backups"


def find_profiles(firefox_root: Path) -> list[Path]:
    profiles_ini = firefox_root / "profiles.ini"
    config = configparser.ConfigParser()
    if not config.read(profiles_ini):
        raise RuntimeError(f"Firefox profiles file not found: {profiles_ini}")

    profile_paths: list[str] = []
    for section in config.sections():
        if section.startswith("Install") and config.has_option(section, "Default"):
            profile_paths.append(config.get(section, "Default"))

    if not profile_paths:
        for section in config.sections():
            if not section.startswith("Profile"):
                continue
            if config.get(section, "Default", fallback="0") == "1":
                profile_paths.append(config.get(section, "Path"))

    profiles: list[Path] = []
    for profile_path in profile_paths:
        path = Path(profile_path)
        if not path.is_absolute():
            path = firefox_root / path
        path = path.resolve()
        if path not in profiles:
            profiles.append(path)
    return profiles


def read_session_files(source_dir: Path) -> dict[str, bytes]:
    files: dict[str, bytes] = {}
    for filename in SESSION_FILES:
        path = source_dir / filename
        if not path.is_file():
            continue
        data = path.read_bytes()
        if len(data) <= len(MOZLZ4_HEADER) or not data.startswith(MOZLZ4_HEADER):
            print(f"Skipping invalid Firefox session file: {path}", file=sys.stderr)
            continue
        files[filename] = data
    return files


def digest_files(files: dict[str, bytes]) -> str:
    digest = hashlib.sha256()
    for filename in sorted(files):
        digest.update(filename.encode())
        digest.update(b"\0")
        digest.update(files[filename])
    return digest.hexdigest()


def latest_digest(profile_backup_root: Path) -> Optional[str]:
    snapshots = sorted(path for path in profile_backup_root.iterdir() if path.is_dir())
    if not snapshots:
        return None
    manifest = snapshots[-1] / "manifest.txt"
    if not manifest.is_file():
        return None
    for line in manifest.read_text().splitlines():
        if line.startswith("digest="):
            return line.removeprefix("digest=")
    return None


def remove_snapshot(snapshot: Path) -> None:
    for path in snapshot.iterdir():
        if path.is_dir() and not path.is_symlink():
            raise RuntimeError(f"Refusing to prune unexpected directory: {path}")
        path.unlink()
    snapshot.rmdir()


def prune_snapshots(profile_backup_root: Path, keep: int) -> None:
    snapshots = sorted(path for path in profile_backup_root.iterdir() if path.is_dir())
    for snapshot in snapshots[:-keep]:
        remove_snapshot(snapshot)


def save_profile(
    firefox_root: Path,
    backup_root: Path,
    profile: Path,
    timestamp: str,
    keep: int,
) -> None:
    source_dir = profile / "sessionstore-backups"
    files = read_session_files(source_dir)
    if not files:
        print(f"No valid Firefox session files found for {profile.name}")
        return

    profile_backup_root = backup_root / profile.name
    profile_backup_root.mkdir(parents=True, exist_ok=True)
    digest = digest_files(files)
    if latest_digest(profile_backup_root) == digest:
        print(f"Session unchanged for {profile.name}")
        return

    snapshot = profile_backup_root / timestamp
    if snapshot.exists():
        snapshot = profile_backup_root / f"{timestamp}-{os.getpid()}"
    temporary = profile_backup_root / f".{snapshot.name}.tmp"
    temporary.mkdir()
    try:
        for filename, data in files.items():
            (temporary / filename).write_bytes(data)
        source_relative = source_dir.relative_to(firefox_root)
        (temporary / "manifest.txt").write_text(
            f"profile={profile.name}\n"
            f"source={source_relative}\n"
            f"created_at={timestamp}\n"
            f"digest={digest}\n"
        )
        temporary.rename(snapshot)
    except BaseException:
        if temporary.exists():
            remove_snapshot(temporary)
        raise

    prune_snapshots(profile_backup_root, keep)
    print(f"Saved Firefox session: {snapshot}")


def main() -> int:
    firefox_root = Path(
        os.environ.get("FIREFOX_ROOT", default_firefox_root())
    ).expanduser().resolve()
    backup_root = Path(
        os.environ.get("FIREFOX_SESSION_BACKUP_ROOT", default_backup_root())
    ).expanduser().resolve()
    keep = int(os.environ.get("FIREFOX_SESSION_BACKUP_KEEP", "288"))
    if keep < 1:
        raise RuntimeError("FIREFOX_SESSION_BACKUP_KEEP must be at least 1")
    timestamp = os.environ.get("FIREFOX_SESSION_BACKUP_NOW") or datetime.now(
        timezone.utc
    ).strftime("%Y%m%dT%H%M%SZ")

    backup_root.mkdir(parents=True, exist_ok=True)
    with (backup_root / ".lock").open("w") as lock_file:
        fcntl.flock(lock_file, fcntl.LOCK_EX)
        profiles = find_profiles(firefox_root)
        if not profiles:
            raise RuntimeError("Firefox has no default profile")
        for profile in profiles:
            save_profile(firefox_root, backup_root, profile, timestamp, keep)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"Firefox session backup failed: {error}", file=sys.stderr)
        raise SystemExit(1)
