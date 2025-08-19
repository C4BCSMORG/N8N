#!/usr/bin/env sh
# Name: docker+n8n install
# Zweck: Auf Debian 12/13 System-Update, Docker & Docker Compose installieren
#       und n8n via Docker Compose mit persistenter Speicherung & Webhook-URL einrichten.
# Ausführung: als root

set -eu

# Root-Check (POSIX)
if [ "$(id -u)" -ne 0 ]; then
  echo "Bitte als root ausführen."
  exit 1
fi

# --- 0) Vorbereitungen / Variablen ---
OS_CODENAME=""
if [ -f /etc/os-release ]; then
  # VERSION_CODENAME aus /etc/os-release lesen
  OS_CODENAME=$(
    awk -F= '/^VERSION_CODENAME=/{gsub(/"/,"",$2);print $2}' /etc/os-release 2>/dev/null
  )
fi

if [ -z "$OS_CODENAME" ]; then
  echo "Konnte Debian-Codename nicht ermitteln. Abbruch."
  exit 1
fi

COMPOSE_DIR="/opt/n8n"
DATA_DIR="/root/c4b_n8n"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"

# --- 1) System aktualisieren ---
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# --- 2) Docker installieren (offizielles Repo) ---
apt-get install -y ca-certificates curl gnupg lsb-release

install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${OS_CODENAME} stable" > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker

# --- 3) URL vom User abfragen und validieren ---
echo
echo "Bitte die öffentlich erreichbare URL für n8n eingeben (mit http:// oder https://):"
printf "> "
IFS= read -r N8N_URL

# POSIX-Variante: mit grep -E prüfen (anstatt [[ =~ ]])
URL_REGEX='^https?://((([A-Za-z0-9-]+\.)+[A-Za-z]{2,})|((25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])){3}))(:[0-9]+)?(/.*)?$'

while ! printf %s "$N8N_URL" | grep -Eq "$URL_REGEX"; do
  echo "Ungültige URL. Beispiel: https://example.com oder http://203.0.113.10:5678"
  printf "> "
  IFS= read -r N8N_URL
done

# --- 4) Verzeichnisse & Rechte ---
mkdir -p "${COMPOSE_DIR}"
mkdir -p "${DATA_DIR}"
# n8n-Container läuft als user "node" (UID 1000). Datenverzeichnis darauf anpassen:
chown -R 1000:1000 "${DATA_DIR}"

# --- 5) Docker Compose Datei für n8n schreiben ---
cat > "${COMPOSE_FILE}" <<'YAML'
services:
  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
    ports:
      - "5678:5678"       # Standard-Port von n8n
    environment:
      # Platzhalter; werden direkt nach dem Here-Doc ersetzt
      - N8N_WEBHOOK_URL=__TO_BE_FILLED__
      # Optionale, sinnvolle Defaults
      - N8N_PORT=5678
      - GENERIC_TIMEZONE=Europe/Berlin
    volumes:
      - /root/c4b_n8n:/home/node/.n8n
    # Für saubere Datei-Ownership
    user: "1000:1000"
YAML

# Platzhalter ersetzen
# (POSIX sed)
sed -i "s|N8N_WEBHOOK_URL=__TO_BE_FILLED__|N8N_WEBHOOK_URL=${N8N_URL}|g" "${COMPOSE_FILE}"

# --- 6) n8n starten ---
echo "Starte n8n via Docker Compose ..."
docker compose -f "${COMPOSE_FILE}" up -d

echo
echo "Fertig! n8n läuft nun (Port 5678)."
echo "Webhook-URL: ${N8N_URL}"
echo "Compose-Datei: ${COMPOSE_FILE}"
echo "Datenverzeichnis (persistent): ${DATA_DIR}"
echo
echo "Logs ansehen:  docker compose -f ${COMPOSE_FILE} logs -f"

