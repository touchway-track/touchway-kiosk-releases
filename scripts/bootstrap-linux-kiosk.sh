#!/usr/bin/env bash
set -euo pipefail

REPO="touchway-track/touchway-kiosk-releases"
TAG=""
ARCH=""
INSTALL_DIR="/opt/touchway-kiosk/current"
APPIMAGE_NAME="touchway-kiosk.AppImage"
RUN_USER="${SUDO_USER:-${USER:-touchway}}"
SERVICE_NAME="touchway-kiosk"
SKIP_SERVICE_INSTALL="false"

usage() {
  cat <<USAGE
Usage: $0 [options]

Options:
  --repo OWNER/REPO         GitHub repository (default: touchway-track/touchway-kiosk-releases)
  --tag TAG                 Release tag (default: latest release)
  --arch ARCH               x64, arm64, or armv7l (default: auto-detect from uname -m)
  --install-dir PATH        Install directory (default: /opt/touchway-kiosk/current)
  --appimage-name NAME      Installed AppImage filename (default: touchway-kiosk.AppImage)
  --user USER               Service Linux user (default: current sudo user)
  --service-name NAME       Systemd service name (default: touchway-kiosk)
  --skip-service-install    Download only; do not install/restart systemd service
  -h, --help                Show this help
USAGE
}

resolve_arch() {
  local uname_arch
  uname_arch="$(uname -m)"

  case "${uname_arch}" in
    x86_64)
      echo "x64"
      ;;
    aarch64|arm64)
      echo "arm64"
      ;;
    armv7l|armhf)
      echo "armv7l"
      ;;
    *)
      echo "Unsupported architecture from uname -m: ${uname_arch}" >&2
      exit 1
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="$2"
      shift 2
      ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    --arch)
      ARCH="$2"
      shift 2
      ;;
    --install-dir)
      INSTALL_DIR="$2"
      shift 2
      ;;
    --appimage-name)
      APPIMAGE_NAME="$2"
      shift 2
      ;;
    --user)
      RUN_USER="$2"
      shift 2
      ;;
    --service-name)
      SERVICE_NAME="$2"
      shift 2
      ;;
    --skip-service-install)
      SKIP_SERVICE_INSTALL="true"
      shift 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  sudo_args=(
    "$0"
    --repo "$REPO"
    --tag "$TAG"
    --arch "$ARCH"
    --install-dir "$INSTALL_DIR"
    --appimage-name "$APPIMAGE_NAME"
    --user "$RUN_USER"
    --service-name "$SERVICE_NAME"
  )

  if [[ "$SKIP_SERVICE_INSTALL" == "true" ]]; then
    sudo_args+=(--skip-service-install)
  fi

  exec sudo "${sudo_args[@]}"
fi

if [[ -z "$ARCH" ]]; then
  ARCH="$(resolve_arch)"
fi

if [[ "$ARCH" != "x64" && "$ARCH" != "arm64" && "$ARCH" != "armv7l" ]]; then
  echo "Invalid arch: $ARCH (expected x64, arm64, or armv7l)" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required but not installed." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required but not installed." >&2
  exit 1
fi

if ! id "$RUN_USER" >/dev/null 2>&1; then
  echo "User does not exist: $RUN_USER" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"

if [[ -z "$TAG" ]]; then
  RELEASE_API_URL="https://api.github.com/repos/${REPO}/releases/latest"
else
  RELEASE_API_URL="https://api.github.com/repos/${REPO}/releases/tags/${TAG}"
fi

release_json="$(curl -fsSL "$RELEASE_API_URL")"
if [[ -z "$release_json" ]]; then
  echo "GitHub API returned an empty response: ${RELEASE_API_URL}" >&2
  exit 1
fi

download_url="$(
  RELEASE_JSON="$release_json" python3 - "$ARCH" <<'PY'
import json
import os
import sys

arch = sys.argv[1]
raw = os.environ.get("RELEASE_JSON", "").strip()
if not raw:
    sys.exit(2)

data = json.loads(raw)
pattern = f"-linux-{arch}.AppImage"

for asset in data.get("assets", []):
    name = asset.get("name", "")
    if name.endswith(pattern):
        print(asset.get("browser_download_url", ""))
        sys.exit(0)

sys.exit(1)
PY
)"

if [[ -z "$download_url" ]]; then
  echo "Could not find AppImage asset for arch=${ARCH} in release ${RELEASE_API_URL}" >&2
  exit 1
fi

target_path="${INSTALL_DIR}/${APPIMAGE_NAME}"
tmp_path="${target_path}.download"

curl -fL "$download_url" -o "$tmp_path"
mv "$tmp_path" "$target_path"
chmod +x "$target_path"
chown -R "$RUN_USER":"$RUN_USER" "$INSTALL_DIR"

echo "AppImage installed at: $target_path"

if [[ "$SKIP_SERVICE_INSTALL" == "true" ]]; then
  echo "Skipping systemd service installation as requested."
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/install-systemd-service.sh" \
  --service-name "$SERVICE_NAME" \
  --working-dir "$INSTALL_DIR" \
  --appimage "$target_path" \
  --exec "${INSTALL_DIR}/run-touchway-kiosk.sh" \
  --user "$RUN_USER"
