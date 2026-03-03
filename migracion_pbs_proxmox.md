# Migración segura de archivos a PBS (Proxmox Backup Server)

Guía práctica para recolocar datos sin perder permisos ni consistencia.

## 1) Requisitos previos

- Tener conectividad entre origen y servidor PBS (red estable y rápida).
- Confirmar espacio libre en destino.
- Instalar `rsync` en ambos lados.
- Ejecutar como `root` (o con `sudo`) para preservar metadatos.

Comprobaciones rápidas:

```bash
ssh root@IP_PBS "hostname && df -h"
rsync --version
```

## 2) Definir rutas

Ejemplo (ajusta a tu caso):

- Origen local: `/media/huayi/47b9f4ee-440a-426b-9989-fc9862b20dc8/datos`
- Destino PBS montado o ruta destino: `/mnt/datastore/datos`

## 3) Primera sincronización (sin parada)

Hace la copia gruesa mientras el sistema sigue funcionando.

```bash
rsync -aHAX --numeric-ids --info=progress2 --partial --inplace \
  /media/huayi/47b9f4ee-440a-426b-9989-fc9862b20dc8/datos/ \
  root@IP_PBS:/mnt/datastore/datos/
```

## 4) Verificación previa al corte

Validación rápida por metadatos/tamaño:

```bash
rsync -aHAXn --delete --numeric-ids \
  /media/huayi/47b9f4ee-440a-426b-9989-fc9862b20dc8/datos/ \
  root@IP_PBS:/mnt/datastore/datos/
```

- Si no lista cambios relevantes, estás listo para el corte.

## 5) Ventana de mantenimiento (corte final)

1. Parar servicios que escriban en origen (VMs, contenedores, tareas).
2. Ejecutar delta final:

```bash
rsync -aHAX --delete --numeric-ids --info=progress2 \
  /media/huayi/47b9f4ee-440a-426b-9989-fc9862b20dc8/datos/ \
  root@IP_PBS:/mnt/datastore/datos/
```

## 6) Verificación final (opcional, más lenta)

Para máxima seguridad, comparar por checksum:

```bash
rsync -aHAXnc --delete --numeric-ids \
  /media/huayi/47b9f4ee-440a-426b-9989-fc9862b20dc8/datos/ \
  root@IP_PBS:/mnt/datastore/datos/
```

- Si no muestra diferencias, la migración está consistente.

## 7) Post-migración

- Montar/usar la nueva ruta en producción.
- Mantener el origen en modo solo lectura durante 24-72h como respaldo.
- Documentar fecha, comando usado y resultado de validación.

## 8) Recomendaciones para evitar sorpresas

- Evita `--delete` en la primera sincronización; úsalo en el corte final.
- Si hay millones de ficheros pequeños, planifica ventana más amplia.
- Si hay ACL/atributos extendidos, no quites `-A` ni `-X`.

## Plantilla rápida (copiar/pegar)

```bash
# 1) Sync inicial
rsync -aHAX --numeric-ids --info=progress2 --partial --inplace ORIGEN/ root@IP_PBS:DESTINO/

# 2) Dry-run de validación
rsync -aHAXn --delete --numeric-ids ORIGEN/ root@IP_PBS:DESTINO/

# 3) Corte final
rsync -aHAX --delete --numeric-ids --info=progress2 ORIGEN/ root@IP_PBS:DESTINO/

# 4) Validación checksum (opcional)
rsync -aHAXnc --delete --numeric-ids ORIGEN/ root@IP_PBS:DESTINO/
```
