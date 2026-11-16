#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/evilsaad0-hash/txt.git"
BOT_DIR="/root/txt"
SERVICE_NAME="bot"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

show_menu() {
  clear 2>/dev/null || true
  cat <<'BANNER'
███████╗██╗   ██╗██╗██╗     ███████╗ █████╗  █████╗ ██████╗
██╔════╝██║   ██║██║██║     ██╔════╝██╔══██╗██╔══██╗██╔══██╗
█████╗  ██║   ██║██║██║     ███████╗███████║███████║██║  ██║
██╔══╝  ╚██╗ ██╔╝██║██║     ╚════██║██╔══██║██╔══██║██║  ██║
███████╗ ╚████╔╝ ██║███████╗███████║██║  ██║██║  ██║██████╔╝
╚══════╝  ╚═══╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═════╝
                 LXC V8 DISCORD BOT INSTALLER
BANNER
  echo
  echo "======================================"
  echo "  1) INSTALL BOT"
  echo "  2) EXIT"
  echo "======================================"
}

install_bot() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Please run this installer as root:"
    echo "sudo bash install-lxc-v8.sh"
    return 1
  fi

  export DEBIAN_FRONTEND=noninteractive

  echo
  echo "[1/7] Updating system and installing requirements..."
  apt-get update
  apt-get install -y git python3 python3-pip python3-venv incus snapd nano

  echo
  echo "[2/7] Downloading bot repository..."
  if [[ -d "$BOT_DIR/.git" ]]; then
    echo "Repository already exists. Updating it..."
    git -C "$BOT_DIR" pull --ff-only
  elif [[ -e "$BOT_DIR" ]]; then
    echo "ERROR: $BOT_DIR exists but is not a Git repository."
    echo "Move or rename that folder, then run the installer again."
    return 1
  else
    git clone "$REPO_URL" "$BOT_DIR"
  fi

  echo
  echo "[3/7] Checking bot files and configuring .env..."
  if [[ ! -f "$BOT_DIR/bot.py" ]]; then
    echo "ERROR: $BOT_DIR/bot.py was not found in the repository."
    return 1
  fi

  if [[ ! -f "$BOT_DIR/.env" && -f "$BOT_DIR/env" ]]; then
    cp "$BOT_DIR/env" "$BOT_DIR/.env"
    echo "Created .env from env."
  elif [[ ! -f "$BOT_DIR/.env" ]]; then
    echo "ERROR: No env or .env file found in $BOT_DIR."
    echo "Create the environment file and run the installer again."
    return 1
  fi

  echo
  echo "Opening .env so you can check your bot settings..."
  nano "$BOT_DIR/.env"

  echo
  echo "[4/7] Creating Python virtual environment and installing packages..."
  python3 -m venv "$BOT_DIR/venv"
  "$BOT_DIR/venv/bin/python" -m pip install --upgrade pip
  "$BOT_DIR/venv/bin/python" -m pip install discord.py python-dotenv PyNaCl davey

  echo
  echo "[5/7] Incus setup..."
  echo "Incus is installed. Initialize it when ready with: incus admin init"
  read -r -p "Initialize Incus now? [y/N]: " INIT_INCUS
  if [[ "$INIT_INCUS" =~ ^[Yy]$ ]]; then
    incus admin init
  fi

  echo
  echo "[6/7] Optional LXD setup..."
  read -r -p "Also install LXD using Snap? [y/N]: " INSTALL_LXD
  if [[ "$INSTALL_LXD" =~ ^[Yy]$ ]]; then
    snap install lxd
    lxd init
  fi

  echo
  echo "[7/7] Creating and enabling the 24/7 systemd service..."
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=LXC V8 VPS Discord Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$BOT_DIR
ExecStart=$BOT_DIR/venv/bin/python $BOT_DIR/bot.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME"
  systemctl restart "$SERVICE_NAME"

  echo
  echo "======================================"
  echo "       INSTALLATION FINISHED"
  echo "======================================"
  echo "Bot service status:"
  systemctl --no-pager --full status "$SERVICE_NAME" || true
  echo
  echo "Useful commands:"
  echo "  systemctl restart bot"
  echo "  systemctl stop bot"
  echo "  systemctl status bot"
  echo "  journalctl -u bot -f"
}

while true; do
  show_menu
  read -r -p "Select an option [1-2]: " choice
  case "$choice" in
    1)
      install_bot
      echo
      read -r -p "Press Enter to return to the menu..."
      ;;
    2)
      echo "Exiting. Goodbye!"
      exit 0
      ;;
    *)
      echo "Invalid option. Please choose 1 or 2."
      sleep 2
      ;;
  esac
done
