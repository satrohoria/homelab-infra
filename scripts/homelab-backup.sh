#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# HOMELAB BACKUP
# ============================================================

BACKUP_DIR="/opt/backups"
REMOTE="gdrive:Homelab/Backups"

LOCAL_RETENTION_DAYS=14
REMOTE_RETENTION_DAYS=30

RCLONE="/usr/bin/rclone"
RCLONE_USER="lenilson"
RCLONE_CONFIG="/home/lenilson/.config/rclone/rclone.conf"

DATE="$(date '+%Y-%m-%d_%H-%M-%S')"
BACKUP_FILE="${BACKUP_DIR}/homelab-${DATE}.tar.gz"

STAGING_DIR="$(mktemp -d /tmp/homelab-backup-XXXXXX)"

# ============================================================
# LIMPEZA AO SAIR
# ============================================================

cleanup() {
    rm -rf "$STAGING_DIR"
}

trap cleanup EXIT


# ============================================================
# PREPARAÇÃO
# ============================================================

mkdir -p "$BACKUP_DIR"

echo
echo "============================================================"
echo " HOMELAB BACKUP - $(date)"
echo "============================================================"
echo


# ============================================================
# [1/5] PREPARANDO ARQUIVOS
# ============================================================

echo "[1/5] Preparando arquivos..."

mkdir -p "$STAGING_DIR/opt"


# ============================================================
# VAULTWARDEN
# Backup consistente do banco SQLite
# ============================================================

if [ -d /opt/vaultwarden ]; then

    echo "      Preparando Vaultwarden..."

    cp -a /opt/vaultwarden "$STAGING_DIR/opt/vaultwarden"

    # Remove banco copiado diretamente
    rm -f \
        "$STAGING_DIR/opt/vaultwarden/data/db.sqlite3" \
        "$STAGING_DIR/opt/vaultwarden/data/db.sqlite3-wal" \
        "$STAGING_DIR/opt/vaultwarden/data/db.sqlite3-shm"

    # Cria snapshot consistente
    sqlite3 /opt/vaultwarden/data/db.sqlite3 \
        ".backup '$STAGING_DIR/opt/vaultwarden/data/db.sqlite3'"

    # Validação de integridade
    DB_CHECK="$(
        sqlite3 \
        "$STAGING_DIR/opt/vaultwarden/data/db.sqlite3" \
        "PRAGMA integrity_check;"
    )"

    if [ "$DB_CHECK" != "ok" ]; then
        echo "ERRO: banco do Vaultwarden falhou na verificação."
        exit 1
    fi

    echo "      Vaultwarden SQLite: OK"

fi


# ============================================================
# FUNÇÃO PARA COPIAR ARQUIVOS/PASTAS PRESERVANDO CAMINHO
# ============================================================

copy_item() {

    ITEM="$1"

    if [ ! -e "$ITEM" ]; then
        echo "      AVISO: não encontrado: $ITEM"
        return
    fi

    DEST="$STAGING_DIR$(dirname "$ITEM")"

    mkdir -p "$DEST"

    cp -a "$ITEM" "$DEST/"
}


# ============================================================
# SERVIÇOS
# ============================================================

echo "      Copiando serviços..."

copy_item /opt/pihole
copy_item /opt/uptime-kuma
copy_item /opt/portainer
copy_item /opt/homepage
copy_item /opt/homeassistant
copy_item /opt/diun
copy_item /opt/beszel
copy_item /opt/beszel-agent
copy_item /opt/dozzle
copy_item /opt/scrutiny
copy_item /opt/speedtest-tracker


# ============================================================
# CADDY
#
# IMPORTANTE:
# Não copiamos /opt/caddy/data porque contém a CA privada.
# ============================================================

copy_item /opt/caddy/Caddyfile
copy_item /opt/caddy/compose.yml


# ============================================================
# CONFIGURAÇÕES DO SISTEMA
# ============================================================

echo "      Copiando configurações do sistema..."

copy_item /etc/network/interfaces
copy_item /etc/resolv.conf

if [ -d /etc/resolvconf ]; then
    copy_item /etc/resolvconf
fi

if [ -d /etc/systemd ]; then
    copy_item /etc/systemd
fi

if [ -d /etc/sysctl.d ]; then
    copy_item /etc/sysctl.d
fi


# ============================================================
# SCRIPTS LOCAIS
# ============================================================

if [ -f /usr/local/sbin/homelab-health.sh ]; then
    copy_item /usr/local/sbin/homelab-health.sh
fi

if [ -f /usr/local/sbin/homelab-backup.sh ]; then
    copy_item /usr/local/sbin/homelab-backup.sh
fi


# ============================================================
# [2/5] CRIANDO ARQUIVO
# ============================================================

echo "[2/5] Criando arquivo compactado..."

tar \
    -czf "$BACKUP_FILE" \
    -C "$STAGING_DIR" \
    .

if [ ! -s "$BACKUP_FILE" ]; then
    echo "ERRO: arquivo de backup não foi criado corretamente."
    exit 1
fi

# O rclone será executado como lenilson,
# então o backup precisa ser legível por ele.
chown "$RCLONE_USER:$RCLONE_USER" "$BACKUP_FILE"
chmod 600 "$BACKUP_FILE"

echo "      Backup criado:"
echo "      $BACKUP_FILE"
echo


# ============================================================
# [3/5] RETENÇÃO LOCAL
# ============================================================

echo "[3/5] Limpando backups locais antigos..."

find "$BACKUP_DIR" \
    -type f \
    -name 'homelab-*.tar.gz' \
    -mtime "+$LOCAL_RETENTION_DAYS" \
    -delete

echo "      Retenção local: ${LOCAL_RETENTION_DAYS} dias"
echo


# ============================================================
# [4/5] GOOGLE DRIVE
# ============================================================

echo "[4/5] Enviando para Google Drive..."

if [ ! -r "$RCLONE_CONFIG" ]; then
    echo "ERRO: configuração do rclone não pode ser lida:"
    echo "$RCLONE_CONFIG"
    exit 1
fi

sudo -u "$RCLONE_USER" \
    "$RCLONE" \
    --config "$RCLONE_CONFIG" \
    copy \
    "$BACKUP_FILE" \
    "$REMOTE"

echo "      Upload concluído."
echo


# ============================================================
# [5/5] RETENÇÃO GOOGLE DRIVE
# ============================================================

echo "[5/5] Limpando backups antigos no Google Drive..."

sudo -u "$RCLONE_USER" \
    "$RCLONE" \
    --config "$RCLONE_CONFIG" \
    delete \
    "$REMOTE" \
    --min-age "${REMOTE_RETENTION_DAYS}d" \
    --include "homelab-*.tar.gz"

echo "      Retenção remota: ${REMOTE_RETENTION_DAYS} dias"
echo


# ============================================================
# RESULTADO
# ============================================================

BACKUP_SIZE="$(du -h "$BACKUP_FILE" | cut -f1)"

echo "============================================================"
echo " BACKUP CONCLUÍDO"
echo "============================================================"
echo
echo "Arquivo : $BACKUP_FILE"
echo "Tamanho : $BACKUP_SIZE"
echo "Drive   : $REMOTE"
echo
