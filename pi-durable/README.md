# Pi Pocket profiles

This directory starts one Pi Pocket server for each Pi profile. Both servers use Tailscale and keep their durable data separate.

| Profile | Pi configuration | Tailscale URL | Durable data |
| --- | --- | --- | --- |
| Personal | `~/.pi/pi-personal` | `http://<tailscale-ip>:8788` | `~/.pi-pocket-personal` |
| Work | `~/.pi/pi-work` | `http://<tailscale-ip>:8789` | `~/.pi-pocket-work` |

The work profile uses Pi's default discovery under `~/.pi/agent/sessions`, including the project subdirectories that hold `pi-work` sessions. The personal profile keeps the shared session-directory override. A Pi Pocket continuation is a new durable session. It does not live-sync with the original terminal session after it starts.

## Start servers

```bash
./pi-durable/start.sh
```

Start one profile only:

```bash
./pi-durable/start.sh personal
./pi-durable/start.sh work
```

Each server creates a separate owner sign-in link and QR code in its `server.log`. The link is a secret. Do not paste it into chat or send it to anyone.

## Stop servers

```bash
./pi-durable/stop.sh
```

Stop one profile only:

```bash
./pi-durable/stop.sh personal
./pi-durable/stop.sh work
```

## Phone access

Connect Tailscale on the phone and Mac. Open the matching URL in the phone browser. Sign in with that server's owner QR code. Use the same profile URL on the Mac browser and phone browser to share the same Pi Pocket session.
