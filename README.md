# Scripts de Copia de Discos USB

Sistema de backup automático entre discos USB usando rsync, optimizado para **Proxmox Backup Server (PBS)**.

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

```bash
./copiaHuayi.sh
```

## ✨ Características

- **Gestión automática de espacio**: Limpia archivos obsoletos cuando es necesario
- **Optimizado para PBS**: Maneja eficientemente grandes volúmenes de backups
- **Logs automáticos**: Genera registros con timestamp en el disco destino
- **Montaje inteligente**: Verifica y monta discos automáticamente

## 📄 Documentación adicional

- [comandos_linux.md](comandos_linux.md): Comandos útiles de Linux para gestión de discos

## 🔒 Seguridad

El archivo `.env` contiene información sensible y **no debe compartirse**. Está excluido del control de versiones.

## 📄 Logs

Los logs se generan automáticamente en el disco de destino con timestamp.
