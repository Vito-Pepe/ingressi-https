#!/usr/bin/env bash
# update.sh — aggiorna gli ingressi HTTPS sul Raspberry Pi
# Uso manuale: ./update.sh
# Pensato anche per cron: se non ci sono commit nuovi non tocca i container.
# Prerequisiti: git, docker, docker compose

set -e

BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo "==> Controllo aggiornamenti su origin/$BRANCH..."
git fetch origin "$BRANCH"

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "origin/$BRANCH")

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') — nessun aggiornamento, già alla versione più recente."
    exit 0
fi

echo "==> Nuovi commit trovati, aggiorno..."
git pull --ff-only origin "$BRANCH"

# Avvia gli ingressi nuovi e ricrea quelli cambiati nel compose
echo "==> Avvio degli ingressi..."
docker compose up -d --remove-orphans

# Se sono cambiate le regole in serve/, riavvio: Tailscale le legge all'avvio
if git diff --name-only "$LOCAL" "$REMOTE" | grep -q '^serve/'; then
    echo "==> Regole cambiate, riavvio degli ingressi..."
    docker compose restart
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') — aggiornamento completato."
