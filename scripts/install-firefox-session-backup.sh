#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
label=com.daiego.firefox-session-backup
launch_agents=$HOME/Library/LaunchAgents
plist=$launch_agents/$label.plist
backup_root="$HOME/Library/Application Support/Firefox Session Backups"
uid=$(id -u)

mkdir -p "$launch_agents" "$backup_root"

cat >"$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>$repo_dir/scripts/firefox-session-backup.py</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>300</integer>
  <key>ProcessType</key>
  <string>Background</string>
  <key>StandardOutPath</key>
  <string>$backup_root/launchd.out.log</string>
  <key>StandardErrorPath</key>
  <string>$backup_root/launchd.err.log</string>
</dict>
</plist>
EOF

plutil -lint "$plist" >/dev/null
launchctl bootout "gui/$uid" "$plist" 2>/dev/null || true
launchctl bootstrap "gui/$uid" "$plist"
launchctl kickstart -k "gui/$uid/$label"

printf 'Installed %s. Firefox sessions are saved every 5 minutes.\n' "$label"
printf 'Backups: %s\n' "$backup_root"
