# Touchway Kiosk Linux Install

This repository is the public distribution source for Touchway kiosk binaries and Linux bootstrap scripts.

## One-Command Install

Run this from the target Linux machine:

```bash
git clone https://github.com/touchway-track/touchway-kiosk-releases.git && cd touchway-kiosk-releases && sudo ./scripts/bootstrap-linux-kiosk.sh --user touchway
```

This single command performs all required setup:

- Downloads and installs the latest compatible AppImage
- Configures the `touchway-kiosk` systemd service
- Enables automatic start after reboot (`systemctl enable`)
- Enables automatic restart on crash (`Restart=always`)

## Architecture

`bootstrap-linux-kiosk.sh` auto-detects architecture:

- `x64`
- `arm64`
- `armv7l`

If needed, force architecture explicitly.

arm64 example:

```bash
sudo ./scripts/bootstrap-linux-kiosk.sh --arch arm64 --user touchway
```

armv7l example:

```bash
sudo ./scripts/bootstrap-linux-kiosk.sh --arch armv7l --user touchway
```

## Service Operations

```bash
systemctl status touchway-kiosk --no-pager
journalctl -u touchway-kiosk -n 200 --no-pager
sudo systemctl restart touchway-kiosk
```
