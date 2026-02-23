# Verificación del código y despliegue en EC2

## 1. Verificación: variables y nombres de base de datos

Se revisó que el código use los nombres correctos de campos y relaciones en ambos proyectos.

### Postgre (patrón estrella)

| Uso en `range_stats` | Modelo / BD | ¿Correcto? |
|----------------------|------------|------------|
| `Data.objects.filter(time__gte=start, time__lte=end)` | `Data.time` es `DateTimeField` | Sí |
| `Min('value')`, `Max('value')`, `Avg('value')`, `Count('value')` | `Data.value` existe (FloatField) | Sí |
| `station_id`, `measurement__name` | FKs y `Measurement.name` existen | Sí |
| `st.user.login`, `st.location.str()` | `User.login` (PK), `Location.str()` devuelve "ciudad, estado, país" | Sí |
| `me.name`, `me.unit` | `Measurement.name`, `Measurement.unit` existen | Sí |

### Timescale (patrón Blob)

| Uso en `range_stats` | Modelo / BD | ¿Correcto? |
|----------------------|------------|------------|
| `time__gte=start_ts`, `time__lte=end_ts` (microsegundos) | `Data.time` es `BigIntegerField` en µs | Sí |
| `Min('min_value')`, `Max('max_value')`, `Avg('avg_value')`, `Sum('length')` | Columnas precalculadas en `Data` | Sí |
| `station_id`, `measurement__name` | Igual que Postgre | Sí |
| `st.user.login`, `st.location.str()`, `me.name`, `me.unit` | Igual que Postgre | Sí |

### Ajuste realizado

- **`station_display`:** se usa `st.location.str()` en lugar de `str(st.location)` para alinearse con el resto de la app (`get_map_json` usa `location.city.name, ...` y en otros lados `loc.str()`). Los modelos definen el método `str(self)` (no `__str__`), por lo que hay que llamarlo explícitamente.

**Conclusión:** El código está alineado con los modelos y con la BD; no se cambiaron esquemas ni migraciones, solo vistas y URLs.

---

## 2. Crear los ZIP para subir a EC2

Desde la raíz del repositorio (o desde `tutoriales/Capa de Datos/`):

### Opción A – Zips desde la carpeta del tutorial

Los ZIP se descomprimen en **Ubuntu** (EC2). Si creas el zip en macOS, evita incluir metadatos de Mac (`__MACOSX`, `._*`) para no ensuciar el árbol en Linux:

```bash
cd "tutoriales/Capa de Datos"

# En macOS conviene usar COPYFILE_DISABLE para no meter resource forks
export COPYFILE_DISABLE=1

# Postgre (para la EC2 con PostgreSQL / Ubuntu)
zip -r postgresMonitoringReto.zip realtimeMonitoringPOSGRES \
  -x "*.pyc" "*__pycache__*" "*.git*" ".DS_Store" "__MACOSX*" "._*"

# Timescale (para la EC2 con Timescale / Ubuntu)
zip -r timescaleMonitoringReto.zip realtimeMonitoringTIMESCALE \
  -x "*.pyc" "*__pycache__*" "*.git*" ".DS_Store" "__MACOSX*" "._*"
```

O ejecutar el script (hace lo mismo): `./crear-zips.sh`

Los archivos `postgresMonitoring.zip` y `timescaleMonitoring.zip` quedarán en `tutoriales/Capa de Datos/`. En la EC2 (Ubuntu): `unzip -o postgresMonitoring.zip` y luego `cd realtimeMonitoringPOSGRES`.

### Opción B – Descargar desde el repo en cada EC2

Si el código ya está en GitHub/GitLab, en cada EC2 puedes clonar o hacer `git pull` en lugar de subir el zip:

```bash
# Ejemplo en la EC2 de Postgre (solo la primera vez o si clonas de nuevo)
git clone https://github.com/<usuario>/<repositorio>.git
cd <repositorio>/tutoriales/Capa\ de\ Datos/realtimeMonitoringPOSGRES
# Luego pasos de la sección 3
```

---

## 3. Qué hacer en cada EC2 (ya con el tutorial hecho)

Si las instancias ya tienen la base de datos creada, migraciones aplicadas y datos de prueba generados, **no hace falta repetir** creación de BD, migraciones ni `generate_data`. Solo actualizas el código y reinicias la app.

### En la EC2 de Postgre

1. Subir y descomprimir el código (o hacer `git pull` si usas repo):

   ```bash
   # Si subiste el zip (desde tu PC lo copias a la EC2 con scp; en la EC2):
   unzip -o postgresMonitoring.zip
   cd realtimeMonitoringPOSGRES
   ```

   Si en lugar de zip usas clone/pull:

   ```bash
   cd <ruta-del-repo>/tutoriales/Capa de Datos/realtimeMonitoringPOSGRES
   ```

2. Activar entorno e instalar dependencias (por si cambió algo):

   ```bash
   pipenv install
   pipenv shell
   ```

3. **No** es necesario `makemigrations` ni `migrate` (no se modificaron modelos).

4. Levantar el servidor:

   ```bash
   python manage.py runserver 0.0.0.0:8000
   ```

5. Probar el nuevo endpoint desde tu navegador o JMeter:

   `http://<IP-EC2-POSTGRE>:8000/api/v1/analytics/range-stats?from=1625115600000&to=1627793999999`

### En la EC2 de Timescale

Los mismos pasos, pero entrando en la carpeta de Timescale:

```bash
unzip -o timescaleMonitoring.zip
cd realtimeMonitoringTIMESCALE
# o: cd <ruta-del-repo>/tutoriales/Capa de Datos/realtimeMonitoringTIMESCALE

pipenv install
pipenv shell
python manage.py runserver 0.0.0.0:8000
```

Probar: `http://<IP-EC2-TIMESCALE>:8000/api/v1/analytics/range-stats?from=1625115600000&to=1627793999999`

---

## 4. Resumen: ¿hay que rehacer todo?

| Paso del tutorial | ¿Hacerlo de nuevo? |
|-------------------|--------------------|
| Crear bases de datos (CloudFormation / EC2) | No |
| Instalar app (primera vez: pipenv install, migrate) | No (solo pipenv install por si acaso) |
| Migraciones (`makemigrations` / `migrate`) | No (no hay cambios en modelos) |
| Generar datos de prueba (`generate_data`) | No |
| **Actualizar código** (zip o git pull) | Sí |
| **pipenv shell** y **runserver** | Sí |

Solo necesitas actualizar el código en cada EC2 (zip o repo), asegurarte de estar en el entorno (`pipenv shell`) y volver a ejecutar `runserver`. Las bases de datos y los datos ya generados se siguen usando igual.
