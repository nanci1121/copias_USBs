#!/bin/bash
# =============================================================
#  COPIA USB → USB (RCLONE + LIMPIEZA AUTOMÁTICA)
#  Optimizado para backups de PBS (600GB - 1TB)
# =============================================================

# === CARGAR CONFIGURACIÓN ===
# Intentar obtener el directorio del script de forma compatible con bash y sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    . "$SCRIPT_DIR/.env"
else
    echo "❌ ERROR: Archivo .env no encontrado en $SCRIPT_DIR"
    exit 1
fi

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
LOGFILE="/tmp/backup_rclone_$TIMESTAMP.log"

echo "== Iniciando proceso (MODO PARALELO CON RCLONE) =="
curl -d "Iniciando copia de seguridad (rclone) 🚀" ntfy.sh/"$NTFY_TOPIC" >/dev/null 2>&1

# === 1. MONTAJE ===
sudo mkdir -p "$MOUNT_ORIGEN" "$MOUNT_DESTINO"

mount_disco() {
    local punto=$1
    local uuid=$2
    if ! mountpoint -q "$punto"; then
        sudo mount -o noatime,nodiratime -U "$uuid" "$punto" || return 1
    fi
}

mount_disco "$MOUNT_ORIGEN" "$UUID_ORIGEN" || { echo "❌ Error origen"; exit 1; }
mount_disco "$MOUNT_DESTINO" "$UUID_DESTINO" || { echo "❌ Error destino"; exit 1; }

# === 2. CÁLCULO DE ESPACIO (INSTANTÁNEO) ===
# Usamos 'du -s' pero sin profundizar en subdirectorios para ir rápido
TAMANO_ORIGEN=$(sudo du -sk "$MOUNT_ORIGEN" | awk '{print $1}')
ESPACIO_DISPONIBLE=$(df -k "$MOUNT_DESTINO" | awk 'NR==2 {print $4}')

# Margen de seguridad del 5% para que el disco no se bloquee al llenarse
UMBRAL_SEGURIDAD=$(echo "$TAMANO_ORIGEN * 1.05" | bc | cut -d. -f1)

echo "🔍 Tamaño origen: $((TAMANO_ORIGEN/1024/1024)) GB"
echo "🔍 Espacio libre: $((ESPACIO_DISPONIBLE/1024/1024)) GB"

# === 3. BUCLE DE LIMPIEZA ===
while [ "$UMBRAL_SEGURIDAD" -gt "$ESPACIO_DISPONIBLE" ]; do
    echo "⚠️ Espacio insuficiente. Buscando copias antiguas para borrar..."
    
    # Buscamos directorios que empiecen por 'backup_' ordenados por fecha (el más viejo primero)
    OLDEST_BACKUP=$(find "$MOUNT_DESTINO" -maxdepth 1 -type d -name "backup_*" | sort | head -n 1)

    if [ -z "$OLDEST_BACKUP" ]; then
        echo "❌ ERROR: No hay más copias que borrar y sigue sin haber espacio."
        exit 1
    fi

    echo "🗑️ Borrando copia antigua: $(basename "$OLDEST_BACKUP")"
    sudo rm -rf "$OLDEST_BACKUP"

    # Recalcular espacio
    ESPACIO_DISPONIBLE=$(df -k "$MOUNT_DESTINO" | awk 'NR==2 {print $4}')
    echo "💾 Nuevo espacio disponible: $((ESPACIO_DISPONIBLE/1024/1024)) GB"
done

# === 4. EJECUCIÓN DE COPIA CON RCLONE ===
DESTINO_UNICO="$MOUNT_DESTINO/backup_$TIMESTAMP"
sudo mkdir -p "$DESTINO_UNICO"

echo "🚀 Lanzando rclone (16 hilos en paralelo)..."

# Explicación de flags:
# --transfers: archivos simultáneos.
# --checkers: hilos verificando metadatos.
# --metadata: para que PBS reconozca las fechas originales.
sudo rclone copy "$MOUNT_ORIGEN/" "$DESTINO_UNICO/" \
    --transfers 16 \
    --checkers 32 \
    --metadata \
    --buffer-size 128M \
    --stats 30s \
    -P

RCLONE_EXIT=$?

# === 5. FINALIZACIÓN ===
if [ $RCLONE_EXIT -eq 0 ]; then
    echo "🎉 Backup completado con éxito."
    curl -H "Tags: white_check_mark,backup" -d "Backup rclone completado con éxito 🎉" ntfy.sh/"$NTFY_TOPIC" >/dev/null 2>&1
else
    echo "❌ Error en la copia con rclone. Código: $RCLONE_EXIT"
    curl -H "Priority: 5" -H "Tags: warning,backup" -d "Error en la copia rclone ❌ Código: $RCLONE_EXIT" ntfy.sh/"$NTFY_TOPIC" >/dev/null 2>&1
fi

echo "💾 Desmontando discos..."
sudo umount "$MOUNT_ORIGEN"
sudo umount "$MOUNT_DESTINO"
