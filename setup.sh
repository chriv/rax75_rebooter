#!/bin/bash
set -u

SERVICE_NAME="rebootrax75"
SCRIPT_NAME="rebootrax75.sh"
ENV_FILE="config.env"

# Target Locations
BIN_DIR="/usr/local/bin"
CONF_DIR="/etc/rebootrax75"
SYSTEMD_DIR="/etc/systemd/system"
OLD_SYSTEMD_DIR="/lib/systemd/system"

# Root Check
if [[ "$EUID" -ne 0 ]]; then
   echo "CRITICAL: Run as root."
   exit 1
fi

# Files Check
if [[ ! -f "./$SCRIPT_NAME" ]] || [[ ! -f "./$ENV_FILE" ]]; then
    echo "CRITICAL: Script or Env file missing."
    exit 1
fi

echo "--- Step 1: Verification Run (Dry Run) ---"
# Temporarily force DRY_RUN=1 for the test to avoid actually rebooting the router
export DRY_RUN=1
if ./$SCRIPT_NAME; then
    echo "SUCCESS: The script completed the dry run."
else
    echo "FAILURE: The script exited with an error."
    exit 1
fi
unset DRY_RUN

echo "--- Step 2: Cleanup Old Install ---"
if [[ -f "$OLD_SYSTEMD_DIR/$SERVICE_NAME.service" ]]; then
    echo "Found legacy unit in $OLD_SYSTEMD_DIR. Removing..."
    rm "$OLD_SYSTEMD_DIR/$SERVICE_NAME.service"
    rm "$OLD_SYSTEMD_DIR/$SERVICE_NAME.timer"
fi

echo "--- Step 3: Installation ---"
# Install Config
mkdir -p "$CONF_DIR"
cp "./$ENV_FILE" "$CONF_DIR/config.env"
chmod 600 "$CONF_DIR/config.env"
echo "[*] Config installed to $CONF_DIR/config.env"

# Install Script
cp "./$SCRIPT_NAME" "$BIN_DIR/rebootrax75"
chmod 700 "$BIN_DIR/rebootrax75"
echo "[*] Script installed to $BIN_DIR/rebootrax75"

# Install Systemd Units
cp "./$SERVICE_NAME.service" "$SYSTEMD_DIR/"
cp "./$SERVICE_NAME.timer" "$SYSTEMD_DIR/"
systemctl daemon-reload

echo "--- Step 4: Activation ---"
systemctl enable --now "$SERVICE_NAME.timer"
systemctl list-timers --no-pager | grep "$SERVICE_NAME"
echo "Done."
