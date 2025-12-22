cambiar a usuario root -> sudo su
borrar un archivo ->     rm archivo.txt
borrar una carpeta ->    rm -R direccion_carpeta(/home/huayi/)
comprobar espacio en disco -> df -h
llegar a una carpeta del disco duro exterior
     -> cd /media/huayi/47b9f4ee-440a-426b-9989-fc9862b20dc8
comprobar espacio en disco externo -> df -h 
para ordenarlos por fecha creacion-> ls -lt
para ordenarlos por fecha de modificacion -> ls -l --time=ctime
comparar dos carpetas con txt -> diff -rq /media/huayi/47b9f4ee-440a-426b-9989-fc9862b20dc8/backup_2025-07-15_07-56-35/ /media/huayi/10d52072-62b6-4206-9aeb-1bd182442891/
comparar dos carpetas -> rsync -rvn --size-only /media/huayi/47b9f4ee-440a-426b-9989-fc9862b20dc8/backup_2025-07-15_07-56-35/ /media/huayi/10d52072-62b6-4206-9aeb-1bd182442891/
para ver como va la copia -> tail -f backup_2025-10-06_08-32-12.log 