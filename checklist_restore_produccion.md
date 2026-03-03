# Checklist de restauración en réplica (Proxmox)

Objetivo: validar que los backups del USB permiten recuperar producción de forma fiable.

## 1. Preparación de entorno (aislado)

- [ ] Crear VM/LXC réplica con misma versión de SO que producción.
- [ ] Asignar red aislada o sin salida pública para evitar conflictos.
- [ ] Configurar hostname distinto (ejemplo: `app-restore-test`).
- [ ] Confirmar CPU/RAM/disco mínimos para arrancar servicios.

## 2. Preparación del backup

- [ ] Conectar y montar USB origen de backups.
- [ ] Verificar integridad básica con:
  - `sudo ./comprobarUsb.sh`
- [ ] Confirmar fecha del backup a restaurar.
- [ ] Identificar ruta exacta de datos a restaurar.

## 3. Restauración

- [ ] Detener servicios en la VM/LXC de prueba antes de copiar datos.
- [ ] Restaurar con `rsync` preservando metadatos:
  - `sudo rsync -aHAX --numeric-ids --info=progress2 ORIGEN/ DESTINO/`
- [ ] Si aplica, restaurar también configuración (`/etc`, variables, secretos, cron, systemd).

## 4. Arranque y verificación técnica

- [ ] Iniciar servicios principales (web/app/db/colas).
- [ ] Revisar estado de servicios:
  - `systemctl --failed`
  - `journalctl -p err -b`
- [ ] Verificar permisos/owner de rutas críticas.
- [ ] Validar conectividad interna y puertos esperados.

## 5. Pruebas funcionales mínimas

- [ ] Login en aplicación.
- [ ] Lectura de datos históricos clave.
- [ ] Crear/editar un registro de prueba.
- [ ] Ejecutar tarea programada o job representativo.
- [ ] Confirmar que no hay errores en logs de aplicación.

## 6. Criterios de aceptación

- [ ] La réplica arranca sin errores críticos.
- [ ] Servicios clave operativos.
- [ ] Datos restaurados consistentes.
- [ ] Pruebas funcionales mínimas superadas.
- [ ] Tiempo de restauración documentado (RTO real).

## 7. Cierre

- [ ] Guardar evidencia (capturas/comandos/salida de logs).
- [ ] Registrar incidencias y acciones correctivas.
- [ ] Actualizar runbook de recuperación.
- [ ] Definir próxima prueba periódica (mensual/trimestral).

## Comandos rápidos (plantilla)

```bash
# 1) Verificación de USB
sudo ./comprobarUsb.sh

# 2) Restauración base
sudo rsync -aHAX --numeric-ids --info=progress2 /ruta/backup/ /ruta/restauracion/

# 3) Chequeo servicios
systemctl --failed
journalctl -p err -b
```
