# Comandos Varios de Linux

## Gestión de usuarios

* **Cambiar a usuario `root`**:

    ```bash
    sudo su
    ```

## Gestión de archivos y directorios

* **Borrar un archivo**:

    ```bash
    rm archivo.txt
    ```

* **Borrar una carpeta y su contenido**:

    ```bash
    rm -R /home/huayi/direccion_carpeta/
    ```

* **Navegar a una carpeta**:

    ```bash
    cd /media/huayi/47b9f4ee-440a-426b-9989-fc9862b20dc8
    ```

* **Ordenar archivos por fecha de creación**:

    ```bash
    ls -lt
    ```

* **Ordenar archivos por fecha de modificación**:

    ```bash
    ls -l --time=ctime
    ```

## Gestión del sistema

* **Comprobar espacio en disco**:

    ```bash
    df -h
    ```

## Comparación y seguimiento

* **Comparar dos carpetas (simple)**:

    ```bash
    diff -rq /ruta/a/la/carpeta1/ /ruta/a/la/carpeta2/
    ```

* **Comparar dos carpetas (avanzado con rsync)**:

    ```bash
    rsync -rvn --size-only /ruta/a/la/carpeta1/ /ruta/a/la/carpeta2/
    ```

* **Ver el progreso de un proceso en un log**:

    ```bash
    tail -f nombre_del_archivo.log
    ```

## Comandos para copiar entre discos USB

Aquí tienes una selección de los comandos más útiles para copiar archivos y carpetas entre dos unidades USB, con ejemplos.

### 1. Identificar los discos USB

Antes de nada, necesitas saber cómo se llaman tus discos USB en el sistema.

* `df -h`: Muestra el espacio usado y disponible en todos los sistemas de archivos montados. Es útil para ver los puntos de montaje de tus USB.

    ```bash
    df -h
    ```

* `lsblk`: Lista todos los dispositivos de bloque. Es la forma más fiable de ver los nombres de los dispositivos (ej: `/dev/sdb1`, `/dev/sdc1`) y dónde están montados.

    ```bash
    lsblk
    ```

### 2. Copiar archivos y carpetas

Una vez identificados los puntos de montaje de los USB (por ejemplo, `/media/usuario/USB_ORIGEN` y `/media/usuario/USB_DESTINO`).

* `rsync` (Recomendado): Es la herramienta más potente y flexible. Solo copia los archivos nuevos o modificados, puede reanudar copias interrumpidas y muestra el progreso.

  * `-a`: Modo "archive", preserva permisos, fechas, etc.
  * `-v`: Modo "verbose", muestra los archivos que se están copiando.
  * `--progress`: Muestra el progreso de la transferencia.
  * `--delete`: Borra en el destino los archivos que no existen en el origen. **¡Usar con cuidado!**

    **Ejemplo de copia simple:**

    ```bash
    rsync -av --progress /media/usuario/USB_ORIGEN/ /media/usuario/USB_DESTINO/
    ```

* `cp`: El comando de copia básico.

  * `-r`: Copia directorios de forma recursiva.
  * `-v`: Muestra los archivos que se están copiando.

    **Ejemplo de copia de una carpeta:**

    ```bash
    cp -rv /media/usuario/USB_ORIGEN/mi_carpeta /media/usuario/USB_DESTINO/
    ```

### 3. Verificar la copia

Para asegurarte de que todo se ha copiado correctamente.

* `diff`: Compara dos carpetas recursivamente. No mostrará nada si son idénticas.

    ```bash
    diff -rq /media/usuario/USB_ORIGEN/ /media/usuario/USB_DESTINO/
    ```

* **Script automático de verificación**: Usa el script `comprobarUsb.sh` que compara UUID, tamaño total, número de archivos y fechas de modificación entre dos carpetas.

    ```bash
    # Usando rutas del archivo .env (verifica UUID automáticamente)
    ./comprobarUsb.sh
    
    # Especificando rutas manualmente
    ./comprobarUsb.sh /media/usuario/USB_ORIGEN /media/usuario/USB_DESTINO
    
    # Verificación exhaustiva con checksums (lento pero preciso)
    ./comprobarUsb.sh --checksum
    ```

## Gestión de repositorios APT

### Reparar clave GPG faltante o corrupta

Si `apt update` falla con error de firma digital o clave GPG faltante:

1. **Identificar el repositorio problemático**: Busca en la salida de `apt update` la huella de la clave que falta (ejemplo: `35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3`).

2. **Localizar la configuración del repositorio**:

    ```bash
    grep -r "nombre-del-repo" /etc/apt/sources.list /etc/apt/sources.list.d/
    ```

3. **Descargar e instalar la clave GPG correcta**:

    Para repositorios de Google Artifact Registry (`apt.pkg.dev`):

    ```bash
    # Verificar la huella de la clave antes de instalar
    wget -qO- https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | gpg --show-keys --with-fingerprint
    
    # Instalar la clave en el keyring
    wget -qO- https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | gpg --dearmor | sudo tee /etc/apt/keyrings/nombre-repo-key.gpg >/dev/null
    
    # Ajustar permisos
    sudo chmod 644 /etc/apt/keyrings/nombre-repo-key.gpg
    
    # Actualizar
    sudo apt update
    ```

4. **Alternativa: Desactivar el repositorio** (si no lo usas):

    ```bash
    sudo mv /etc/apt/sources.list.d/nombre-repo.list /etc/apt/sources.list.d/nombre-repo.list.disabled
    sudo apt update
    ```

5. **Verificar que no haya más claves corruptas**:

    ```bash
    # Buscar archivos de clave vacíos o problemáticos
    find /etc/apt/keyrings /etc/apt/trusted.gpg.d -type f -size 0
    ```
