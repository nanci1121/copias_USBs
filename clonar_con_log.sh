#!/bin/bash

# === CARGAR CONFIGURACIÓN DESDE .env ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "❌ ERROR: Archivo .env no encontrado en $SCRIPT_DIR"
    exit 1
fi

# === INICIO ===
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
TMP_LOGFILE="/tmp/backup_$TIMESTAMP.log"

echo "== Iniciando proceso de copia ==" | tee -a "$TMP_LOGFILE"
echo "Log temporal: $TMP_LOGFILE" | tee -a "$TMP_LOGFILE"

# Crear puntos de montaje si no existen
sudo mkdir -p "$MOUNT_ORIGEN"
sudo mkdir -p "$MOUNT_DESTINO"

# === Montar los discos usando UUID ===
echo "🔍 Verificando y montando discos..." | tee -a "$TMP_LOGFILE"

if ! mountpoint -q "$MOUNT_ORIGEN"; then
    echo "Montando disco de origen en $MOUNT_ORIGEN..." | tee -a "$TMP_LOGFILE"
    sudo mount -U "$UUID_ORIGEN" "$MOUNT_ORIGEN"
    if [ $? -ne 0 ]; then
        echo "❌ ERROR: No se pudo montar el disco de origen con UUID $UUID_ORIGEN." | tee -a "$TMP_LOGFILE"
        exit 1
    fi
fi

if ! mountpoint -q "$MOUNT_DESTINO"; then
    echo "Montando disco de destino en $MOUNT_DESTINO..." | tee -a "$TMP_LOGFILE"
    sudo mount -U "$UUID_DESTINO" "$MOUNT_DESTINO"
    if [ $? -ne 0 ]; then
        echo "❌ ERROR: No se pudo montar el disco de destino con UUID $UUID_DESTINO." | tee -a "$TMP_LOGFILE"
        exit 1
    fi
fi

# === Verificar que los puntos de montaje existen ===
if [ ! -d "$MOUNT_ORIGEN" ]; then
    echo "❌ ERROR: El origen '$MOUNT_ORIGEN' no existe o no está montado." | tee -a "$TMP_LOGFILE"
    exit 1
fi

if [ ! -d "$MOUNT_DESTINO" ]; then
    echo "❌ ERROR: El destino '$MOUNT_DESTINO' no existe o no está montado." | tee -a "$TMP_LOGFILE"
    exit 1
fi

# === Crear log definitivo ===
LOGFILE="$MOUNT_DESTINO/backup_$TIMESTAMP.log"
mv "$TMP_LOGFILE" "$LOGFILE"
echo "✅ Log definitivo: $LOGFILE" | tee -a "$LOGFILE"

# === Verificar espacio en disco ===
echo "🔍 Comprobando espacio en disco..." | tee -a "$LOGFILE"

TAMANO_ORIGEN=$(du -sk "$MOUNT_ORIGEN" | awk '{print $1}')
ESPACIO_DISPONIBLE=$(df -k "$MOUNT_DESTINO" | awk 'NR==2 {print $4}')

TAMANO_ORIGEN_GB=$(echo "scale=2; $TAMANO_ORIGEN / 1024 / 1024" | bc)
ESPACIO_DISPONIBLE_GB=$(echo "scale=2; $ESPACIO_DISPONIBLE / 1024 / 1024" | bc)

echo "💾 Tamaño de los datos en el origen: ${TAMANO_ORIGEN_GB} GB" | tee -a "$LOGFILE"
echo "💾 Espacio disponible en el destino: ${ESPACIO_DISPONIBLE_GB} GB" | tee -a "$LOGFILE"

if [ "$TAMANO_ORIGEN" -gt "$ESPACIO_DISPONIBLE" ]; then
    echo "❌ ERROR: No hay suficiente espacio en el disco de destino." | tee -a "$LOGFILE"
    exit 1
fi

# === Crear directorio único para el backup ===
DESTINO_UNICO="$MOUNT_DESTINO/backup_$TIMESTAMP"
sudo mkdir -p "$DESTINO_UNICO"

# === Ejecutar rsync ===
echo "🚀 Iniciando copia con rsync..." | tee -a "$LOGFILE"

sudo stdbuf -oL rsync -aAXH --info=progress2 --stats "$MOUNT_ORIGEN"/ "$DESTINO_UNICO"/ > "$LOGFILE" 2>&1
if [ $? -ne 0 ]; then
    echo "❌ ERROR: La copia con rsync falló." | tee -a "$LOGFILE"
    exit 1
fi

# === Desmontar los discos ===
echo "💾 Desmontando discos..." | tee -a "$LOGFILE"

if ! sudo umount "$MOUNT_ORIGEN"; then
    echo "❌ ERROR: No se pudo desmontar el disco de origen." | tee -a "$LOGFILE"
fi

if ! sudo umount "$MOUNT_DESTINO"; then
    echo "❌ ERROR: No se pudo desmontar el disco de destino." | tee -a "$LOGFILE"
fi

# === Finalización ===
echo "✅ Copia completada. Revisa el log en: $LOGFILE" | tee -a "$LOGFILE"

