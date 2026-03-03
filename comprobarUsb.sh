#!/bin/bash
# =============================================
#   VERIFICAR COPIAS USB (COMPLETO)
#   Compara UUID, tamaño, archivos y fechas
# =============================================

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

# === FUNCIÓN DE USO ===
mostrar_uso() {
    echo "Uso: $0 [RUTA_ORIGEN] [RUTA_DESTINO] [-c|--checksum]"
    echo ""
    echo "Si no se proporcionan rutas, se usará la configuración del .env"
    echo ""
    echo "Opciones:"
    echo "  -c, --checksum    Verificar checksums (lento pero exhaustivo)"
    echo ""
    echo "Ejemplos:"
    echo "  $0"
    echo "  $0 /media/huayi/USB_ORIGEN /media/huayi/USB_DESTINO"
    echo "  $0 --checksum"
    exit 1
}

# === PARSEAR ARGUMENTOS ===
CHECKSUM_MODE=false
ORIGEN=""
DESTINO=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--checksum)
            CHECKSUM_MODE=true
            shift
            ;;
        -h|--help)
            mostrar_uso
            ;;
        *)
            if [ -z "$ORIGEN" ]; then
                ORIGEN="$1"
            elif [ -z "$DESTINO" ]; then
                DESTINO="$1"
            else
                echo -e "${RED}❌ ERROR: Demasiados argumentos${NC}"
                mostrar_uso
            fi
            shift
            ;;
    esac
done

# === CARGAR RUTAS ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USAR_ENV=false

if [ -z "$ORIGEN" ] && [ -z "$DESTINO" ]; then
    # Cargar desde .env
    if [ -f "$SCRIPT_DIR/.env" ]; then
        source "$SCRIPT_DIR/.env"
        ORIGEN="$MOUNT_ORIGEN"
        DESTINO="$MOUNT_DESTINO"
        USAR_ENV=true
    else
        echo -e "${RED}❌ ERROR: Archivo .env no encontrado y no se proporcionaron rutas${NC}"
        mostrar_uso
    fi
elif [ -z "$ORIGEN" ] || [ -z "$DESTINO" ]; then
    echo -e "${RED}❌ ERROR: Debes proporcionar ambas rutas o ninguna${NC}"
    mostrar_uso
fi

# === VALIDAR QUE EXISTAN LAS RUTAS ===
if [ ! -d "$ORIGEN" ]; then
    echo -e "${RED}❌ ERROR: La ruta de origen no existe: $ORIGEN${NC}"
    exit 1
fi

if [ ! -d "$DESTINO" ]; then
    echo -e "${RED}❌ ERROR: La ruta de destino no existe: $DESTINO${NC}"
    exit 1
fi

# === VERIFICACIÓN ===
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  VERIFICACIÓN DE COPIAS USB${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}📂 Origen:${NC}  $ORIGEN"
echo -e "${YELLOW}📂 Destino:${NC} $DESTINO"

# === VERIFICAR UUID SI SE USA .env ===
UUID_OK=true
if [ "$USAR_ENV" = true ]; then
    echo ""
    echo -e "${BLUE}🔍 Verificando UUID de los discos...${NC}"
    
    # Obtener UUID del punto de montaje origen
    ORIGEN_DEVICE=$(findmnt -n -o SOURCE "$ORIGEN" 2>/dev/null)
    if [ -n "$ORIGEN_DEVICE" ]; then
        ORIGEN_UUID_ACTUAL=$(lsblk -no UUID "$ORIGEN_DEVICE" 2>/dev/null)
        echo -e "   Origen esperado: ${YELLOW}$UUID_ORIGEN${NC}"
        echo -e "   Origen actual:   ${YELLOW}$ORIGEN_UUID_ACTUAL${NC}"
        
        if [ "$ORIGEN_UUID_ACTUAL" = "$UUID_ORIGEN" ]; then
            echo -e "   ${GREEN}✅ UUID de origen correcto${NC}"
        else
            echo -e "   ${RED}❌ UUID de origen no coincide${NC}"
            UUID_OK=false
        fi
    else
        echo -e "   ${YELLOW}⚠️  No se pudo verificar UUID de origen (no montado?)${NC}"
    fi
    
    # Obtener UUID del punto de montaje destino
    DESTINO_DEVICE=$(findmnt -n -o SOURCE "$DESTINO" 2>/dev/null)
    if [ -n "$DESTINO_DEVICE" ]; then
        DESTINO_UUID_ACTUAL=$(lsblk -no UUID "$DESTINO_DEVICE" 2>/dev/null)
        echo -e "   Destino esperado: ${YELLOW}$UUID_DESTINO${NC}"
        echo -e "   Destino actual:   ${YELLOW}$DESTINO_UUID_ACTUAL${NC}"
        
        if [ "$DESTINO_UUID_ACTUAL" = "$UUID_DESTINO" ]; then
            echo -e "   ${GREEN}✅ UUID de destino correcto${NC}"
        else
            echo -e "   ${RED}❌ UUID de destino no coincide${NC}"
            UUID_OK=false
        fi
    else
        echo -e "   ${YELLOW}⚠️  No se pudo verificar UUID de destino (no montado?)${NC}"
    fi
    
    if [ "$UUID_OK" = false ]; then
        echo ""
        echo -e "${RED}❌ ERROR: Los UUID no coinciden. Verifica que los discos correctos estén montados.${NC}"
        exit 1
    fi
fi

echo ""

# === CONTAR ARCHIVOS (EN PARALELO) ===
echo -e "${BLUE}🔍 Analizando directorios en paralelo...${NC}"

# Lanzar análisis en paralelo
(
    ORIGEN_ARCHIVOS=$(find "$ORIGEN" -type f 2>/dev/null | wc -l)
    echo "ORIGEN_ARCHIVOS=$ORIGEN_ARCHIVOS" > /tmp/usb_check_origen_$$
) &
PID_ORIGEN=$!

(
    DESTINO_ARCHIVOS=$(find "$DESTINO" -type f 2>/dev/null | wc -l)
    echo "DESTINO_ARCHIVOS=$DESTINO_ARCHIVOS" > /tmp/usb_check_destino_$$
) &
PID_DESTINO=$!

# Esperar a que terminen
wait $PID_ORIGEN
wait $PID_DESTINO

# Leer resultados
source /tmp/usb_check_origen_$$
source /tmp/usb_check_destino_$$
rm -f /tmp/usb_check_origen_$$ /tmp/usb_check_destino_$$

echo -e "   Origen:  $ORIGEN_ARCHIVOS archivos"
echo -e "   Destino: $DESTINO_ARCHIVOS archivos"

# === COMPARACIÓN DETALLADA CON RSYNC (OPTIMIZADA) ===
echo ""
echo -e "${BLUE}🔍 Comparando archivos (tamaño y fecha de modificación)...${NC}"
RSYNC_OPTS="-rln --delete --stats --info=progress2"
if [ "$CHECKSUM_MODE" = true ]; then
    echo -e "${YELLOW}   ⚠️  Modo checksum: tardará mucho más (lee todo el contenido)${NC}"
    RSYNC_OPTS="-rlnc --delete --stats --info=progress2"
fi

# Ejecutar rsync en modo dry-run con estadísticas
RSYNC_OUTPUT=$(rsync $RSYNC_OPTS "$ORIGEN/" "$DESTINO/" 2>&1)
RSYNC_EXIT=$?

# Extraer estadísticas del rsync
TOTAL_FILES=$(echo "$RSYNC_OUTPUT" | grep "Number of files:" | awk '{print $4}' | sed 's/,//g')
TOTAL_SIZE=$(echo "$RSYNC_OUTPUT" | grep "Total file size:" | awk '{print $4}' | sed 's/,//g')
TOTAL_SIZE_LEGIBLE=$(numfmt --to=iec-i --suffix=B "${TOTAL_SIZE:-0}" 2>/dev/null || echo "$TOTAL_SIZE bytes")

# Contar diferencias (excluyendo líneas de sistema y estadísticas)
DIFERENCIAS=$(echo "$RSYNC_OUTPUT" | grep -E '^(deleting |<|>|cd)' | wc -l)

if [ $DIFERENCIAS -eq 0 ] && [ $RSYNC_EXIT -eq 0 ]; then
    echo -e "   ${GREEN}✅ Sin diferencias detectadas${NC}"
    RSYNC_OK=true
else
    echo -e "   ${RED}❌ Detectadas diferencias en $DIFERENCIAS archivos/carpetas${NC}"
    RSYNC_OK=false
    
    # Guardar diferencias en archivo temporal
    DIFF_FILE="/tmp/usb_diff_$(date +%s).txt"
    echo "$RSYNC_OUTPUT" > "$DIFF_FILE"
fi

# === MOSTRAR RESULTADOS ===
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  RESULTADOS${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "📊 ${YELLOW}Número de archivos:${NC}"
echo -e "   Origen:  $ORIGEN_ARCHIVOS archivos"
echo -e "   Destino: $DESTINO_ARCHIVOS archivos"

if [ "$ORIGEN_ARCHIVOS" -eq "$DESTINO_ARCHIVOS" ]; then
    echo -e "   ${GREEN}✅ Coinciden${NC}"
    ARCHIVOS_OK=true
else
    DIFF_ARCHIVOS=$((ORIGEN_ARCHIVOS - DESTINO_ARCHIVOS))
    echo -e "   ${RED}❌ Diferencia: $DIFF_ARCHIVOS archivos${NC}"
    ARCHIVOS_OK=false
fi

echo ""
echo -e "💾 ${YELLOW}Tamaño total:${NC}"
echo -e "   Total en origen: $TOTAL_SIZE_LEGIBLE (${TOTAL_FILES:-$ORIGEN_ARCHIVOS} archivos)"

echo ""
echo -e "🔍 ${YELLOW}Comparación detallada (archivos + fechas):${NC}"
if [ "$RSYNC_OK" = true ]; then
    echo -e "   ${GREEN}✅ Todos los archivos coinciden en tamaño y fecha${NC}"
    if [ "$CHECKSUM_MODE" = true ]; then
        echo -e "   ${GREEN}✅ Checksums verificados${NC}"
    fi
else
    echo -e "   ${RED}❌ Detectadas $DIFERENCIAS diferencias${NC}"
    echo -e "   ${YELLOW}💾 Detalles guardados en: $DIFF_FILE${NC}"
fi

# === RESUMEN FINAL ===
echo ""
echo -e "${BLUE}========================================${NC}"
if [ "$ARCHIVOS_OK" = true ] && [ "$RSYNC_OK" = true ]; then
    echo -e "${GREEN}✅ VERIFICACIÓN EXITOSA${NC}"
    echo -e "   Las copias son idénticas"
    if [ "$CHECKSUM_MODE" = true ]; then
        echo -e "   Checksums verificados ✓"
    fi
    EXIT_CODE=0
elif [ "$RSYNC_OK" = false ]; then
    echo -e "${RED}❌ VERIFICACIÓN FALLIDA${NC}"
    echo -e "   Diferencias detectadas: archivos faltantes, modificados o con fechas diferentes"
    if [ -n "$DIFF_FILE" ]; then
        echo -e "   Ver detalles en: ${YELLOW}$DIFF_FILE${NC}"
    fi
    EXIT_CODE=1
elif [ "$ARCHIVOS_OK" = false ] || [ "$TAMANO_OK" = false ]; then
    echo -e "${YELLOW}⚠️  ADVERTENCIA${NC}"
    echo -e "   Diferencia en el conteo de archivos"
    EXIT_CODE=2
else
    echo -e "${YELLOW}⚠️  VERIFICACIÓN PARCIAL${NC}"
    echo -e "   Detectadas algunas diferencias"
    EXIT_CODE=2
fi
echo -e "${BLUE}========================================${NC}"
echo ""

# === SUGERENCIAS ===
if [ "$EXIT_CODE" -ne 0 ]; then
    echo -e "${YELLOW}💡 Sugerencias:${NC}"
    
    if [ -n "$DIFF_FILE" ]; then
        echo -e "   • Ver diferencias completas:"
        echo -e "     ${BLUE}cat $DIFF_FILE${NC}"
        echo ""
    fi
    
    echo -e "   • Ver primera diferencia encontrada:"
    echo -e "     ${BLUE}rsync -rltn --delete \"$ORIGEN/\" \"$DESTINO/\" | head -20${NC}"
    echo ""
    
    if [ "$CHECKSUM_MODE" = false ]; then
        echo -e "   • Verificación exhaustiva con checksums:"
        echo -e "     ${BLUE}$0 $([ "$USAR_ENV" = true ] && echo "" || echo "\"$ORIGEN\" \"$DESTINO\"") --checksum${NC}"
        echo ""
    fi
    
    echo -e "   • Comparación manual detallada:"
    echo -e "     ${BLUE}diff -rq \"$ORIGEN\" \"$DESTINO\"${NC}"
    echo ""
fi

exit $EXIT_CODE
