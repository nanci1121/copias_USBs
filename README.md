# Scripts de Copia de Discos USB

Sistema de backup automático entre discos USB, optimizado para **Proxmox Backup Server (PBS)** y grandes volúmenes de datos.

## 📋 Requisitos

- Linux (bash)
- `rsync` (para la versión secuencial)
- `rclone` (para la versión paralela, recomendada)
- `curl` (para notificaciones móviles)
- `bc` (para cálculos de espacio)

## ⚙️ Configuración

1. Copia el archivo de ejemplo:

   ```bash
   cp .env.example .env
   ```

2. Edita el archivo `.env` con los UUIDs de tus discos y el tema de notificaciones (ntfy):

   ```bash
   UUID_ORIGEN="..."
   UUID_DESTINO="..."
   
   # Para recibir notificaciones en tu móvil (ntfy.sh)
   NTFY_TOPIC="tu_tema_secreto_aqui"
   ```

## 🚀 Uso

Tienes dos versiones disponibles según tus necesidades:

**Opción A: Rclone Paralelo (Recomendado para PBS)**
Ideal para millones de archivos pequeños ("chunks" de Proxmox Backup Server). Utiliza 16 hilos en paralelo para maximizar la velocidad del USB.
```bash
sudo ./copiaHuayi_v2.sh
```

**Opción B: Rsync Secuencial**
La versión clásica de sincronización. Ideal para copias donde la estructura de archivos es más estándar.
```bash
sudo ./copiaHuayi.sh
```

## ✨ Características

- **Gestión automática de espacio**: Verifica el espacio y limpia copias obsoletas (las más antiguas) cuando es necesario antes de empezar.
- **Notificaciones Push**: Integración con **ntfy.sh** para avisarte al móvil cuando empieza la copia, cuando termina con éxito o si hay algún error (con alerta prioritaria).
- **Optimizado para PBS**: Maneja eficientemente grandes volúmenes de backups.
- **Logs automáticos**: Genera registros de las operaciones.
- **Montaje inteligente**: Verifica y monta los discos de origen y destino automáticamente usando sus UUIDs para evitar errores de ruta.

## 📄 Documentación adicional

- [comandos_linux.md](comandos_linux.md): Comandos útiles de Linux para gestión de discos y transferencias.
- [checklist_restore_produccion.md](checklist_restore_produccion.md): Pasos para restaurar los backups en un entorno de pruebas.
- [migracion_pbs_proxmox.md](migracion_pbs_proxmox.md): Guía de buenas prácticas para migrar un PBS.

## 🔒 Seguridad

El archivo `.env` contiene información sensible y los puntos de montaje de tu infraestructura. **Está excluido del control de versiones (`.gitignore`) y no debe compartirse.**
