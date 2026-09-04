#!/usr/bin/env bash
# Interactive, single-command installer for a Linux VPS.
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$PROJECT_DIR/.venv"
ENV_FILE="$PROJECT_DIR/.env"
SERVICE_NAME="vultmirror"

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || fail "Python 3.10 or newer is required. Install python3, then run this script again."

python3 - <<'PY' || fail "Python 3.10 or newer is required."
import sys
if sys.version_info < (3, 10):
    raise SystemExit(1)
PY

printf '\nVultMirror VPS setup\n===================\n'
printf 'This installs dependencies locally in %s.\n\n' "$VENV_DIR"

read -r -s -p 'Telegram bot token: ' BOT_TOKEN
printf '\n'
[[ "$BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]] || fail "That does not look like a Telegram bot token."

read -r -p 'Your Telegram user ID (admin): ' ADMIN_USER_ID
[[ "$ADMIN_USER_ID" =~ ^[0-9]+$ && "$ADMIN_USER_ID" != "0" ]] || fail "Admin user ID must be a positive number."

read -r -p 'Database path [bot_data_multiuser.db]: ' DB_PATH
DB_PATH="${DB_PATH:-bot_data_multiuser.db}"
[[ "$DB_PATH" != *$'\n'* && "$DB_PATH" != *$'\r'* ]] || fail "Database path cannot contain a newline."

cd "$PROJECT_DIR"

if [[ ! -d "$VENV_DIR" ]]; then
  printf '\nCreating virtual environment...\n'
  python3 -m venv "$VENV_DIR" || fail "Could not create a virtual environment. On Debian/Ubuntu, install python3-venv and run this script again."
fi

printf 'Installing Python dependencies...\n'
"$VENV_DIR/bin/python" -m pip install --upgrade pip >/dev/null
"$VENV_DIR/bin/python" -m pip install -r requirements.txt

# Keep unrelated .env values and comments, while replacing only setup values.
BOT_TOKEN="$BOT_TOKEN" ADMIN_USER_ID="$ADMIN_USER_ID" DB_PATH="$DB_PATH" ENV_FILE="$ENV_FILE" \
  "$VENV_DIR/bin/python" - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["ENV_FILE"])
values = {
    "BOT_TOKEN": os.environ["BOT_TOKEN"],
    "ADMIN_USER_ID": os.environ["ADMIN_USER_ID"],
    "DB_PATH": os.environ["DB_PATH"],
}
lines = path.read_text().splitlines() if path.exists() else []
written = set()
result = []
for line in lines:
    key = line.split("=", 1)[0].strip()
    if key in values:
        result.append(f"{key}={values[key]}")
        written.add(key)
    else:
        result.append(line)
for key, value in values.items():
    if key not in written:
        result.append(f"{key}={value}")
path.write_text("\n".join(result).rstrip() + "\n")
PY
chmod 600 "$ENV_FILE"

printf 'Initializing database...\n'
DB_PATH="$DB_PATH" "$VENV_DIR/bin/python" -c 'from database import Database; Database()'

printf '\nInstall and start a systemd service now? [Y/n] '
read -r INSTALL_SERVICE
if [[ ! "$INSTALL_SERVICE" =~ ^[Nn]$ ]]; then
  SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
  TMP_SERVICE="$(mktemp)"
  trap 'rm -f "$TMP_SERVICE"' EXIT
  CURRENT_USER="$(id -un)"
  CURRENT_GROUP="$(id -gn)"

  cat >"$TMP_SERVICE" <<EOF
[Unit]
Description=VultMirror Telegram contract-address mirror bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_GROUP
WorkingDirectory=$PROJECT_DIR
ExecStart=$VENV_DIR/bin/python $PROJECT_DIR/bot.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

  sudo install -m 644 "$TMP_SERVICE" "$SERVICE_FILE"
  sudo systemctl daemon-reload
  sudo systemctl enable --now "$SERVICE_NAME"
  printf '\nService is running. Check it with: sudo systemctl status %s\n' "$SERVICE_NAME"
  printf 'View logs with: sudo journalctl -u %s -f\n' "$SERVICE_NAME"
else
  printf '\nSetup complete. Start the bot with:\n  %s/bin/python %s/bot.py\n' "$VENV_DIR" "$PROJECT_DIR"
fi
