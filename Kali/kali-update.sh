#!/bin/env bash

# --- Production Safety ---
# Set production safeties in place.
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error and exit immediately.
# -o pipefail: Return the exit status of the last command in the pipeline that failed
set -euo pipefail

# Communicate the initiation of the update process to the user.
echo "Initiate Update of Kali Linux"

# --- Root Privilege Check ---
# Check if the script is being run with root privilges.
# If not, then print an error message and exit the script with a non-zero status code.
if [[ $EUID -ne 0 ]]; then
    echo "Please run this script with sudo or as root."
    exit 1
fi

# --- Environment Variables and APT Options ---
# Set environment variables to ensure non-interactive package management and critical priority for updates.
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
export NEEDRESTART_MODE=a

# Define APT options to ensure that package management operations proceed without user interaction.
# Handle configuration file changes appropriately.
APT_OPTS=(
  -y
  -o Dpkg::Options::="--force-confdef"
  -o Dpkg::Options::="--force-confold"
)

# --- Logging ---
LOG_DIR="/var/log/kali-maint"
mkdir -p "$LOG_DIR"
chmod 0750 "$LOG_DIR"

RUN_TS="$(date '+%Y-%m-%d_%H-%M-%S')"
LOG_FILE="$LOG_DIR/kali-update_$RUN_TS.log"

exec > >(awk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), $0; fflush(); }' | tee -a "$LOG_FILE") 2>&1

# --- Execution ---
# Communicate lacking lists will be updated.
echo "Updating package lists for Kali Linux"

# Run commands to "update" package lists.
sudo -E apt-get update

# Communucate package lists will be installed and upgraded.
echo "Installing and Upgrading packages for Kali Linux"

# Run commands to "upgrade" packages.
sudo apt-get "${APT_OPTS[@]}" upgrade

# Perform "autoremove" to clean up unnecessary packages.
sudo -E apt-get -y autoremove

# Perform "autoclean" to clean up the local repository of retrieved package files.
sudo -E apt-get -y autoclean

# Communicate completion of update process
echo "Kali Linux Update Completed"

# --- Reboot detection (Debian/Kali style) ---
reboot_needed=false

if [[ -f /var/run/reboot-required ]]; then
  reboot_needed=true
fi

if $reboot_needed; then
  echo "Reboot required to fully apply updates."

  # Show what triggered it (if available)
  if [[ -f /var/run/reboot-required.pkgs ]]; then
    echo "Packages requiring reboot:"
    sed 's/^/    - /' /var/run/reboot-required.pkgs || true
  fi

  # Auto-reboot only if explicitly enabled
  if [[ "${AUTO_REBOOT:-0}" == "1" ]]; then
    echo "AUTO_REBOOT=1 set. Rebooting in 10 seconds..."
    sleep 10
    reboot
  else
    echo "To reboot now: sudo reboot"
  fi
else
  echo "No reboot required."
fi

# Gracefully exit the script.
exit 0