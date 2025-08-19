#!/usr/bin/env bash
# Führt täglich ein Update/Upgrade durch und protokolliert ins Log.
# Ausführung: root, idealerweise via Cron um 01:00

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

LOGFILE="/var/log/system-auto-upgrade.log"
{
  echo "==== $(date '+%Y-%m-%d %H:%M:%S') – Beginn Auto-Upgrade ===="
  apt-get update -y
  apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade
  apt-get -y autoremove --purge
  apt-get -y autoclean
  echo "==== $(date '+%Y-%m-%d %H:%M:%S') – Ende Auto-Upgrade ===="
  echo
} >> "${LOGFILE}" 2>&1



# Dieses script hier mit mit "mv ./system-auto-upgrade.sh /usr/local/sbin/system-auto-upgrade.sh" in das richtige Verzeichnis verschieben
# nach dem Befehl "crontab -e" zu ergänzen
# 0 1 * * * root /usr/local/sbin/system-auto-upgrade.sh
