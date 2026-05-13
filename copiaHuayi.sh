#!/bin/bash
# =============================================
#   COPIA COMPLETA DE DISCO USB → DISCO USB
#   (Optimizado para VELOCIDAD + Limpieza Condicional)
# =============================================

# === CARGAR CONFIGURACIÓN DESDE .env ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "❌ ERROR: Archivo .env no encontrado en $SCRIPT_DIR"
    exit 1
fi

# === INICIO ===
START_TIME=$SECONDS
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

# Crear directorio de logs local si no existe
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/backup_rsync_$TIMESTAMP.log"

# Redirigir toda la salida al log y a la pantalla
exec > >(tee -a "$LOGFILE") 2>&1

echo "== Iniciando proceso de copia completa (MODO VELOZ) =="
echo "📝 Log guardado en: $LOGFILE"
curl -d "Iniciando copia de seguridad (rsync) 🚀" ntfy.sh/"$NTFY_TOPIC" >/dev/null 2>&1

sudo mkdir -p "$MOUNT_ORIGEN" "$MOUNT_DESTINO"

# === Montar los discos ===
echo "🔍 Verificando y montando discos..."

mount_disco() {
    local punto=$1
    local uuid=$2
    if ! mountpoint -q "$punto"; then
        sudo mount -o noatime,nodiratime -U "$uuid" "$punto" 2>/dev/null || return 1
    fi
}

# Intentar montar el origen (principal o alternativo)
ORIGEN_MONTADO=false
for uuid in "$UUID_ORIGEN" "$UUID_ORIGEN_ALT"; do
    if [ -n "$uuid" ]; then
        echo "🔄 Intentando montar origen con UUID: $uuid"
        if mount_disco "$MOUNT_ORIGEN" "$uuid"; then
            ORIGEN_MONTADO=true
            break
        fi
    fi
done

if [ "$ORIGEN_MONTADO" = false ]; then
    echo "❌ ERROR: No se pudo montar ningún disco de origen."
    exit 1
fi

# Montar destino
mount_disco "$MOUNT_DESTINO" "$UUID_DESTINO" || {
    echo "❌ ERROR: No se pudo montar el disco de destino."
    exit 1
}

# === Verificar espacio ===
echo "🔍 Comprobando espacio..."

# === Verificar que el origen contiene archivos ===
NUM_ARCHIVOS_ORIGEN=$(find "$MOUNT_ORIGEN" -type f | wc -l)
if [ "$NUM_ARCHIVOS_ORIGEN" -eq 0 ]; then
    echo "❌ ERROR: El origen no contiene archivos. No se realizará la copia."
    sudo umount "$MOUNT_ORIGEN"
    sudo umount "$MOUNT_DESTINO"
    exit 1
fi

TAMANO_ORIGEN=$(du -skd 0 "$MOUNT_ORIGEN" | awk '{print $1}')
ESPACIO_DISPONIBLE=$(df -k "$MOUNT_DESTINO" | awk 'NR==2 {print $4}')

TAMANO_ORIGEN_GB=$(echo "scale=2; $TAMANO_ORIGEN / 1024 / 1024" | bc)
ESPACIO_DISPONIBLE_GB=$(echo "scale=2; $ESPACIO_DISPONIBLE / 1024 / 1024" | bc)

echo "💾 Tamaño origen: ${TAMANO_ORIGEN_GB} GB"
echo "💾 Espacio destino (antes): ${ESPACIO_DISPONIBLE_GB} GB"

# === LÓGICA DE ESPACIO Y LIMPIEZA CONDICIONAL (NUEVA FUNCIÓN) ===
while [ "$TAMANO_ORIGEN" -gt "$ESPACIO_DISPONIBLE" ]; do
    echo "❌ ERROR: No hay suficiente espacio en destino (${TAMANO_ORIGEN_GB} GB requeridos, ${ESPACIO_DISPONIBLE_GB} GB disponibles)."
    
    # 1. Encontrar la copia más antigua según el nombre del directorio (fecha en el nombre)
    OLDEST_BACKUP=$(find "$MOUNT_DESTINO" -maxdepth 1 -type d -name "backup_*" \
        -not -name "backup_$TIMESTAMP" | sort | head -n 1)

    if [ -z "$OLDEST_BACKUP" ]; then
        echo "❌ ERROR FATAL: No hay más copias antiguas para eliminar y el espacio sigue siendo insuficiente."
        exit 1
    fi
    
    echo "🚨 Eliminando la copia más antigua para liberar espacio: $OLDEST_BACKUP"
    sudo rm -rf "$OLDEST_BACKUP"
    
    # 2. Recalcular el espacio disponible
    ESPACIO_DISPONIBLE=$(df -k "$MOUNT_DESTINO" | awk 'NR==2 {print $4}')
    ESPACIO_DISPONIBLE_GB=$(echo "scale=2; $ESPACIO_DISPONIBLE / 1024 / 1024" | bc)
    
    # 3. Volver a mostrar el nuevo espacio
    echo "💾 Nuevo espacio disponible: ${ESPACIO_DISPONIBLE_GB} GB"
done

echo "✔️ Espacio verificado. Iniciando copia."
# =================================================================

# === Crear carpeta única de destino ===
DESTINO_UNICO="$MOUNT_DESTINO/backup_$TIMESTAMP"
sudo mkdir -p "$DESTINO_UNICO"

# === Log SOLO ERRORES de rsync ===
RSYNC_LOG="$MOUNT_DESTINO/rsync_errors_$TIMESTAMP.log"
echo "📄 Log de errores de rsync (solo si falla): $RSYNC_LOG"

# === COPIA RÁPIDA ===

echo "🚀 Iniciando copia (ver progreso en tiempo real en la consola)..."

# El progreso solo se muestra en la consola, el log solo guarda errores y el resumen final
sudo rsync -aAXH \
    --human-readable \
    --info=progress2 \
    --stats \
    --partial \
    "$MOUNT_ORIGEN"/ "$DESTINO_UNICO"/ \
    2> "$RSYNC_LOG"

RSYNC_EXIT=$?

# === Evaluar resultado ===
if [ $RSYNC_EXIT -ne 0 ]; then
    echo "❌ ERROR: Falló la copia (ver $RSYNC_LOG)."
    curl -H "Priority: 5" -H "Tags: warning,backup" -d "Error en la copia rsync ❌" ntfy.sh/"$NTFY_TOPIC" >/dev/null 2>&1
    exit 1
fi

# Si el archivo de errores está vacío, se borra
if [ ! -s "$RSYNC_LOG" ]; then
    rm "$RSYNC_LOG"
    RSYNC_LOG="(sin errores)"
fi

# === Resumen final (ANTES de desmontar para poder acceder a los datos) ===
TAMANO_COPIA=$(sudo du -skd 0 "$DESTINO_UNICO" | awk '{print $1}')
TAMANO_COPIA_GB=$(echo "scale=2; $TAMANO_COPIA / 1024 / 1024" | bc)
ESPACIO_FINAL_DISPONIBLE=$(df -k "$MOUNT_DESTINO" | awk 'NR==2 {print $4}')
ESPACIO_FINAL_DISPONIBLE_GB=$(echo "scale=2; $ESPACIO_FINAL_DISPONIBLE / 1024 / 1024" | bc)

echo ""
echo "===== RESUMEN DEL BACKUP ====="
echo "Estado: OK"
echo "Backup creado: $DESTINO_UNICO"
echo "Tamaño origen: ${TAMANO_ORIGEN_GB} GB"
echo "Tamaño copia en destino: ${TAMANO_COPIA_GB} GB"
echo "Espacio restante destino: ${ESPACIO_FINAL_DISPONIBLE_GB} GB"
echo "Errores rsync: $RSYNC_LOG"
echo "=============================="

# === Desmontar ===
echo "💾 Desmontando discos..."
sudo umount "$MOUNT_ORIGEN" || echo "⚠️ No se pudo desmontar origen"
sudo umount "$MOUNT_DESTINO" || echo "⚠️ No se pudo desmontar destino"

# === 6. RESUMEN FINAL ===
END_TIME=$SECONDS
DURATION=$((END_TIME - START_TIME))
H=$((DURATION / 3600))
M=$(( (DURATION % 3600) / 60 ))
S=$((DURATION % 60))

echo "------------------------------------------"
printf "⏱️ Tiempo total de ejecución: %02d:%02d:%02d\n" $H $M $S
echo "📂 Log final disponible en: $LOGFILE"
echo "------------------------------------------"

curl -H "Tags: white_check_mark,backup" -d "Backup rsync completado con éxito 🎉" ntfy.sh/"$NTFY_TOPIC" >/dev/null 2>&1