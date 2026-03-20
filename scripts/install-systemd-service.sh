#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="touchway-kiosk"
WORKING_DIR="/opt/touchway-kiosk/current"
APPIMAGE_PATH="/opt/touchway-kiosk/current/touchway-kiosk.AppImage"
EXEC_START="/opt/touchway-kiosk/current/run-touchway-kiosk.sh"
RUN_USER="${SUDO_USER:-${USER:-touchway}}"
RESTART_SEC="5"
AUTO_UPDATE_ENABLED="true"
AUTO_UPDATE_INTERVAL_MINUTES="10"
AUTO_UPDATE_LINUX_ONLY="true"
AUTO_UPDATE_ROLLBACK_MAX_RESTARTS="3"
WAIT_FOR_GRAPHICAL="true"
DISPLAY_VALUE=":0"
XAUTHORITY_PATH=""
XDG_RUNTIME_DIR_VALUE=""

usage() {
  cat <<USAGE
Usage: $0 [options]

Options:
  --service-name NAME   Systemd service name (default: touchway-kiosk)
  --working-dir PATH    Working directory for the service (default: /opt/touchway-kiosk/current)
  --appimage PATH       AppImage path managed by the service (default: /opt/touchway-kiosk/current/touchway-kiosk.AppImage)
  --exec PATH           Wrapper path used by ExecStart (default: /opt/touchway-kiosk/current/run-touchway-kiosk.sh)
  --user USER           Linux user to run the app (default: current sudo user)
  --restart-sec SEC     Restart delay in seconds (default: 5)
  --auto-update-enabled VALUE             true|false (default: true)
  --auto-update-interval-minutes VALUE    positive integer (default: 10)
  --auto-update-linux-only VALUE          true|false (default: true)
  --max-update-restarts VALUE             positive integer (default: 3)
  --wait-for-graphical VALUE              true|false (default: true)
  --display VALUE                         DISPLAY value (default: :0)
  --xauthority PATH                       XAUTHORITY path (default: user's ~/.Xauthority)
  --xdg-runtime-dir PATH                  XDG_RUNTIME_DIR (default: /run/user/<uid>)
  -h, --help            Show this help
USAGE
}

is_positive_integer() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+$ ]] && (( value > 0 ))
}

is_boolean_string() {
  local value
  value="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
  [[ "$value" == "true" || "$value" == "false" || "$value" == "1" || "$value" == "0" || "$value" == "yes" || "$value" == "no" ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service-name)
      SERVICE_NAME="$2"
      shift 2
      ;;
    --working-dir)
      WORKING_DIR="$2"
      shift 2
      ;;
    --appimage)
      APPIMAGE_PATH="$2"
      shift 2
      ;;
    --exec)
      EXEC_START="$2"
      shift 2
      ;;
    --user)
      RUN_USER="$2"
      shift 2
      ;;
    --restart-sec)
      RESTART_SEC="$2"
      shift 2
      ;;
    --auto-update-enabled)
      AUTO_UPDATE_ENABLED="$2"
      shift 2
      ;;
    --auto-update-interval-minutes)
      AUTO_UPDATE_INTERVAL_MINUTES="$2"
      shift 2
      ;;
    --auto-update-linux-only)
      AUTO_UPDATE_LINUX_ONLY="$2"
      shift 2
      ;;
    --max-update-restarts)
      AUTO_UPDATE_ROLLBACK_MAX_RESTARTS="$2"
      shift 2
      ;;
    --wait-for-graphical)
      WAIT_FOR_GRAPHICAL="$2"
      shift 2
      ;;
    --display)
      DISPLAY_VALUE="$2"
      shift 2
      ;;
    --xauthority)
      XAUTHORITY_PATH="$2"
      shift 2
      ;;
    --xdg-runtime-dir)
      XDG_RUNTIME_DIR_VALUE="$2"
      shift 2
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
  exec sudo "$0" \
    --service-name "$SERVICE_NAME" \
    --working-dir "$WORKING_DIR" \
    --appimage "$APPIMAGE_PATH" \
    --exec "$EXEC_START" \
    --user "$RUN_USER" \
    --restart-sec "$RESTART_SEC" \
    --auto-update-enabled "$AUTO_UPDATE_ENABLED" \
    --auto-update-interval-minutes "$AUTO_UPDATE_INTERVAL_MINUTES" \
    --auto-update-linux-only "$AUTO_UPDATE_LINUX_ONLY" \
    --max-update-restarts "$AUTO_UPDATE_ROLLBACK_MAX_RESTARTS" \
    --wait-for-graphical "$WAIT_FOR_GRAPHICAL" \
    --display "$DISPLAY_VALUE" \
    --xauthority "$XAUTHORITY_PATH" \
    --xdg-runtime-dir "$XDG_RUNTIME_DIR_VALUE"
fi

if [[ ! -x "$APPIMAGE_PATH" ]]; then
  echo "AppImage not found or not executable: $APPIMAGE_PATH" >&2
  exit 1
fi

if ! id "$RUN_USER" >/dev/null 2>&1; then
  echo "User does not exist: $RUN_USER" >&2
  exit 1
fi

if ! is_positive_integer "$RESTART_SEC"; then
  echo "Invalid --restart-sec value: $RESTART_SEC" >&2
  exit 1
fi

if ! is_positive_integer "$AUTO_UPDATE_INTERVAL_MINUTES"; then
  echo "Invalid --auto-update-interval-minutes value: $AUTO_UPDATE_INTERVAL_MINUTES" >&2
  exit 1
fi

if ! is_positive_integer "$AUTO_UPDATE_ROLLBACK_MAX_RESTARTS"; then
  echo "Invalid --max-update-restarts value: $AUTO_UPDATE_ROLLBACK_MAX_RESTARTS" >&2
  exit 1
fi

if ! is_boolean_string "$AUTO_UPDATE_ENABLED"; then
  echo "Invalid --auto-update-enabled value: $AUTO_UPDATE_ENABLED" >&2
  exit 1
fi

if ! is_boolean_string "$AUTO_UPDATE_LINUX_ONLY"; then
  echo "Invalid --auto-update-linux-only value: $AUTO_UPDATE_LINUX_ONLY" >&2
  exit 1
fi

if ! is_boolean_string "$WAIT_FOR_GRAPHICAL"; then
  echo "Invalid --wait-for-graphical value: $WAIT_FOR_GRAPHICAL" >&2
  exit 1
fi

RUN_HOME="$(getent passwd "$RUN_USER" | cut -d: -f6)"
if [[ -z "$RUN_HOME" ]]; then
  echo "Could not resolve home directory for user: $RUN_USER" >&2
  exit 1
fi

RUN_UID="$(id -u "$RUN_USER")"
if [[ -z "$XAUTHORITY_PATH" ]]; then
  XAUTHORITY_PATH="${RUN_HOME}/.Xauthority"
fi

if [[ -z "$XDG_RUNTIME_DIR_VALUE" ]]; then
  XDG_RUNTIME_DIR_VALUE="/run/user/${RUN_UID}"
fi

mkdir -p "$WORKING_DIR"

cat > "$EXEC_START" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail

APPIMAGE_PATH="${APPIMAGE_PATH}"
WORKING_DIR="${WORKING_DIR}"
MAX_UPDATE_RESTARTS="${AUTO_UPDATE_ROLLBACK_MAX_RESTARTS}"

UPDATE_PENDING_FILE="\${WORKING_DIR}/.touchway-kiosk-update-pending"
UPDATE_RESTART_COUNT_FILE="\${WORKING_DIR}/.touchway-kiosk-update-restart-count"
UPDATE_HEALTH_FILE="\${WORKING_DIR}/.touchway-kiosk-update-healthy"
APPIMAGE_BACKUP_PATH="\${APPIMAGE_PATH}.prev.AppImage"

if [[ ! -x "\${APPIMAGE_PATH}" ]]; then
  echo "[auto-update] missing-appimage path=\${APPIMAGE_PATH}" >&2
  exit 1
fi

if [[ -f "\${UPDATE_PENDING_FILE}" ]]; then
  rm -f "\${UPDATE_HEALTH_FILE}"

  restart_count=0
  if [[ -f "\${UPDATE_RESTART_COUNT_FILE}" ]]; then
    restart_count="\$(cat "\${UPDATE_RESTART_COUNT_FILE}" 2>/dev/null || echo 0)"
  fi

  if ! [[ "\${restart_count}" =~ ^[0-9]+$ ]]; then
    restart_count=0
  fi

  restart_count=\$((restart_count + 1))
  echo "\${restart_count}" > "\${UPDATE_RESTART_COUNT_FILE}"

  echo "[auto-update] pending-update restart_count=\${restart_count} max=\${MAX_UPDATE_RESTARTS}" >&2

  if (( restart_count > MAX_UPDATE_RESTARTS )); then
    if [[ -f "\${APPIMAGE_BACKUP_PATH}" ]]; then
      cp -f "\${APPIMAGE_BACKUP_PATH}" "\${APPIMAGE_PATH}"
      chmod +x "\${APPIMAGE_PATH}"
      rm -f "\${UPDATE_PENDING_FILE}" "\${UPDATE_RESTART_COUNT_FILE}" "\${UPDATE_HEALTH_FILE}"
      echo "[auto-update] rollback-applied backup=\${APPIMAGE_BACKUP_PATH}" >&2
    else
      echo "[auto-update] rollback-skipped reason=missing-backup backup=\${APPIMAGE_BACKUP_PATH}" >&2
    fi
  fi
fi

exec "\${APPIMAGE_PATH}"
WRAPPER

chmod 0755 "$EXEC_START"
chown "$RUN_USER":"$RUN_USER" "$EXEC_START"
chown -R "$RUN_USER":"$RUN_USER" "$WORKING_DIR"

SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

UNIT_WANTS="network-online.target"
UNIT_AFTER="network-online.target"
INSTALL_WANTED_BY="multi-user.target"

normalized_wait_for_graphical="$(echo "$WAIT_FOR_GRAPHICAL" | tr '[:upper:]' '[:lower:]')"
if [[ "$normalized_wait_for_graphical" == "true" || "$normalized_wait_for_graphical" == "1" || "$normalized_wait_for_graphical" == "yes" ]]; then
  UNIT_WANTS="${UNIT_WANTS} graphical.target display-manager.service"
  UNIT_AFTER="${UNIT_AFTER} graphical.target display-manager.service"
  INSTALL_WANTED_BY="graphical.target"
fi

cat > "$SERVICE_FILE" <<SERVICE
[Unit]
Description=Touchway Kiosk
Wants=${UNIT_WANTS}
After=${UNIT_AFTER}

[Service]
Type=simple
User=${RUN_USER}
WorkingDirectory=${WORKING_DIR}
ExecStart=${EXEC_START}
Restart=always
RestartSec=${RESTART_SEC}
TimeoutStartSec=30
TimeoutStopSec=10
KillMode=mixed
Environment=NODE_ENV=production
Environment=AUTO_UPDATE_ENABLED=${AUTO_UPDATE_ENABLED}
Environment=AUTO_UPDATE_INTERVAL_MINUTES=${AUTO_UPDATE_INTERVAL_MINUTES}
Environment=AUTO_UPDATE_LINUX_ONLY=${AUTO_UPDATE_LINUX_ONLY}
Environment=AUTO_UPDATE_ROLLBACK_MAX_RESTARTS=${AUTO_UPDATE_ROLLBACK_MAX_RESTARTS}
Environment=DISPLAY=${DISPLAY_VALUE}
Environment=XAUTHORITY=${XAUTHORITY_PATH}
Environment=XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR_VALUE}

[Install]
WantedBy=${INSTALL_WANTED_BY}
SERVICE

chmod 0644 "$SERVICE_FILE"

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo "Service installed and running: $SERVICE_NAME"
echo "Check status with: systemctl status $SERVICE_NAME --no-pager"
