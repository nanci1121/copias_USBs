# Scripts de Copia de Discos USB

Sistema de backup automático entre discos USB usando rsync.

## 📋 Requisitos

- Linux (bash)
- rsync
- sudo
- bc (para cálculos de espacio)

## ⚙️ Configuración

1. Copia el archivo de ejemplo:
   ```bash
   cp .env.example .env
   ```

2. Edita el archivo `.env` con los UUIDs de tus discos:
   ```bash
   # Para obtener los UUIDs:
   sudo blkid
   ```

3. Configura los UUIDs y puntos de montaje en `.env`

## 🚀 Uso

### Script de copia básico con log
```bash
./clonar_con_log.sh
```

### Script optimizado con limpieza automática
```bash
./copiaHuayi.sh
```

## 📝 Scripts

- **clonar_con_log.sh**: Copia completa con registro detallado
- **copiaHuayi.sh**: Copia optimizada con gestión automática de espacio
- **comandos_linux.md**: Comandos útiles de Linux para gestión de discos

## 🔒 Seguridad

El archivo `.env` contiene información sensible y **no debe compartirse**. Está excluido del control de versiones.

## 📄 Logs

Los logs se generan automáticamente en el disco de destino con timestamp.
