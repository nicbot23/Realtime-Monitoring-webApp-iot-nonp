# Reto Capa de Datos – Nueva consulta y pruebas de carga

Documento base para la entrega del reto. Completar los espacios marcados con `[ ... ]` y reemplazar los placeholders de imágenes antes de generar el PDF/documento final.

---

## a. Enlace al repositorio e indicaciones de las modificaciones

### Enlace al repositorio

**[INSERTAR AQUÍ ENLACE AL REPOSITORIO DE LA PAREJA]**

Ejemplo: `https://github.com/<usuario>/<repositorio>`

---

### Indicaciones de las modificaciones realizadas

Se agregó una **nueva consulta** en ambas aplicaciones (Postgre y Timescale) que expone estadísticas por estación y medición en un rango de tiempo. La consulta es la misma en propósito: *estadísticas (mínimo, máximo, promedio y cantidad de muestras) por par (estación, medición) sobre la entidad Data y sus entidades relacionadas (Station, Measurement, Location, User)*. El código difiere según el modelo de datos (patrón estrella vs Blob).

#### Endpoint definido

- **Método y ruta:** `GET /api/v1/analytics/range-stats`
- **Parámetros opcionales (query):**
  - `from`: inicio del rango (timestamp Unix en milisegundos)
  - `to`: fin del rango (timestamp Unix en milisegundos)
  - `station_id`: filtrar por ID de estación
  - `measurement`: filtrar por nombre de medición (ej. `temperatura`)

Si no se envían `from` ni `to`, se usa por defecto la última semana (igual que en el tutorial).

#### Formato del JSON de respuesta (común para ambas aplicaciones)

```json
{
  "from": "01/07/2021",
  "to": "31/07/2021",
  "filters": { "station_id": null, "measurement": null },
  "results": [
    {
      "station_id": 1,
      "station_display": "user1 @ Bogotá, Cundinamarca, Colombia",
      "measurement_id": 1,
      "measurement_name": "temperatura",
      "unit": "°C",
      "min": 18.5,
      "max": 26.3,
      "avg": 22.1,
      "count": 1440
    }
  ]
}
```

---

### Archivos modificados

| Aplicación | Archivo | Cambio |
|------------|---------|--------|
| Postgre | `realtimeMonitoringPOSGRES/realtimeGraph/views.py` | Nueva función `range_stats`. |
| Postgre | `realtimeMonitoringPOSGRES/realtimeGraph/urls.py` | Nueva ruta `api/v1/analytics/range-stats`. |
| Timescale | `realtimeMonitoringTIMESCALE/realtimeGraph/views.py` | Nueva función `range_stats`. |
| Timescale | `realtimeMonitoringTIMESCALE/realtimeGraph/urls.py` | Nueva ruta `api/v1/analytics/range-stats`. |

**[OPCIONAL: INSERTAR RUTA REAL DE TU REPO SI DIFIERE]**  
Ejemplo: `tutoriales/Capa de Datos/realtimeMonitoringPOSGRES/realtimeGraph/views.py`

---

### Fragmentos de código implementado

#### 1. Registro del endpoint (urls.py)

**Postgre** – `realtimeMonitoringPOSGRES/realtimeGraph/urls.py`:

```python
path("api/v1/analytics/range-stats", range_stats, name="range_stats"),
```

**Timescale** – `realtimeMonitoringTIMESCALE/realtimeGraph/urls.py`:

```python
path("api/v1/analytics/range-stats", range_stats, name="range_stats"),
```

---

#### 2. Vista Postgre (patrón estrella) – fragmento principal

**Archivo:** `realtimeMonitoringPOSGRES/realtimeGraph/views.py`

La consulta filtra `Data` por `time` (datetime) y agrega sobre la columna `value`; agrupa por `station` y `measurement`:

```python
def range_stats(request):
    """
    GET api/v1/analytics/range-stats
    Parámetros opcionales: from (ms), to (ms), station_id, measurement (nombre).
    Devuelve estadísticas (min, max, avg, count) por (estación, medición) en el rango.
    Consulta sobre Data y entidades relacionadas (Station, Measurement) - patrón estrella.
    """
    start, end = get_daterange(request)
    station_id_param = request.GET.get("station_id", None)
    measurement_name = request.GET.get("measurement", None)

    qs = Data.objects.filter(time__gte=start, time__lte=end)
    if station_id_param:
        try:
            qs = qs.filter(station_id=int(station_id_param))
        except ValueError:
            pass
    if measurement_name:
        qs = qs.filter(measurement__name=measurement_name)

    annotated = qs.values("station", "measurement").annotate(
        min_val=Min("value"),
        max_val=Max("value"),
        avg_val=Avg("value"),
        count=Count("value"),
    ).order_by("station", "measurement")
    # ... construcción de results con Station/Measurement para display, payload JSON
```

En Postgre cada fila de `Data` es una muestra; por tanto `Min('value')`, `Max('value')`, `Avg('value')` y `Count('value')` se calculan sobre los valores crudos.

---

#### 3. Vista Timescale (patrón Blob) – fragmento principal

**Archivo:** `realtimeMonitoringTIMESCALE/realtimeGraph/views.py`

La consulta filtra por `time` en **microsegundos** y usa las columnas precalculadas de cada registro Blob (`min_value`, `max_value`, `avg_value`, `length`):

```python
def range_stats(request):
    """
    GET api/v1/analytics/range-stats
    Parámetros opcionales: from (ms), to (ms), station_id, measurement (nombre).
    Devuelve estadísticas (min, max, avg, count) por (estación, medición) en el rango.
    Consulta sobre Data (patrón Blob) usando min_value, max_value, avg_value y length.
    """
    start, end = get_daterange(request)
    start_ts = int(start.timestamp() * 1000000)
    end_ts = int(end.timestamp() * 1000000)

    station_id_param = request.GET.get("station_id", None)
    measurement_name = request.GET.get("measurement", None)

    qs = Data.objects.filter(time__gte=start_ts, time__lte=end_ts)
    if station_id_param:
        try:
            qs = qs.filter(station_id=int(station_id_param))
        except ValueError:
            pass
    if measurement_name:
        qs = qs.filter(measurement__name=measurement_name)

    annotated = qs.values("station", "measurement").annotate(
        min_val=Min("min_value"),
        max_val=Max("max_value"),
        avg_val=Avg("avg_value"),
        count=Sum("length"),
    ).order_by("station", "measurement")
    # ... construcción de results con Station/Measurement para display, payload JSON
```

En Timescale no se recorren las listas `values`/`times`; se usan los agregados ya almacenados en cada fila y `count` es la suma de `length` (cantidad de muestras en cada Blob).

---

## b. Reporte de comparación de resultados de pruebas de carga

Se crearon y ejecutaron pruebas de carga para el endpoint `GET /api/v1/analytics/range-stats` en ambas aplicaciones desplegadas en AWS (Postgre en una EC2, Timescale en otra), usando el script JMeter incluido en el repositorio.

### Script de pruebas utilizado

**[INSERTAR RUTA O NOMBRE DEL ARCHIVO JMETER EN EL REPO]**  
Ejemplo: `tutoriales/Capa de Datos/Pruebas range-stats.jmx`

- **Parámetros:** 60 hilos, ramp-up 1 s, 1 iteración por hilo (60 peticiones en total por grupo).
- **URL de prueba:** `/api/v1/analytics/range-stats?from=1625115600000&to=1627793999999` (rango junio–julio 2021).
- **Variables:** `ip_postgres`, `ip_timescale`, `puerto` (8000), `consulta_url`; se configuraron con las IPs públicas de las EC2.

### Resultados Postgre

**[INSERTAR AQUÍ CAPTURA DE PANTALLA – JMeter Summary Report (grupo Postgres)]**

![Summary Report - Postgres](placeholder-summary-postgres.png)

*Descripción breve: [ej. número de muestras, promedio, mín/máx tiempo de respuesta, % error, throughput].*

---

### Resultados Timescale

**[INSERTAR AQUÍ CAPTURA DE PANTALLA – JMeter Summary Report (grupo Timescale)]**

![Summary Report - Timescale](placeholder-summary-timescale.png)

*Descripción breve: [ej. número de muestras, promedio, mín/máx tiempo de respuesta, % error, throughput].*

---

### Comparación resumida

| Métrica | Postgre | Timescale | Observación breve |
|---------|---------|-----------|-------------------|
| [Ej.: Muestras] | [ ] | [ ] | [ ] |
| [Ej.: Promedio (ms)] | [ ] | [ ] | [ ] |
| [Ej.: Throughput] | [ ] | [ ] | [ ] |
| [Ej.: % Error] | [ ] | [ ] | [ ] |

**[COMPLETAR CON LOS VALORES REALES DE TUS CAPTURAS]**

---

## c. Explicación de los resultados (capa de datos IoT)

**[REDACTAR AQUÍ LA EXPLICACIÓN, APOYÁNDOSE EN LOS CONCEPTOS DE LA CAPA DE DATOS IoT.]**

Sugerencias de puntos a incluir:

1. **Patrón de datos:** En Postgre se usa un patrón tipo estrella con una fila por muestra en `Data`; en Timescale se usa el patrón Blob (varias muestras por fila, con listas `values`/`times` y columnas precalculadas `min_value`, `max_value`, `avg_value`, `length`). Cómo esto afecta el volumen de filas y el trabajo en consultas de agregación.

2. **Agregaciones:** En Postgre las agregaciones (min, max, avg, count) se calculan en tiempo de consulta sobre `value`; en Timescale se reutilizan agregados ya almacenados y solo se agrega entre filas (chunks). Impacto en tiempo de respuesta y uso de CPU/IO.

3. **Tiempo e índices:** Uso de la columna `time` (datetime en Postgre, microsegundos en Timescale) para filtrado y para el particionado/compresión en Timescale (hipertabla, chunks). Cómo eso puede reflejarse en las métricas de JMeter (latencia, throughput).

4. **Crecimiento y compresión:** En Timescale el crecimiento vertical es menor (menos filas para el mismo número de muestras) y la compresión por chunks puede mejorar lecturas; contrastar con el mayor número de filas en Postgre para la misma ventana temporal.

**[INSERTAR PÁRRAFOS FINALES CON TUS CONCLUSIONES SEGÚN TUS RESULTADOS REALES Y LA TEORÍA DEL CURSO.]**

---

## Resumen de archivos en el repositorio

| Archivo | Descripción |
|---------|-------------|
| `realtimeMonitoringPOSGRES/realtimeGraph/views.py` | Vista `range_stats` (Postgre). |
| `realtimeMonitoringPOSGRES/realtimeGraph/urls.py` | Ruta `api/v1/analytics/range-stats` (Postgre). |
| `realtimeMonitoringTIMESCALE/realtimeGraph/views.py` | Vista `range_stats` (Timescale). |
| `realtimeMonitoringTIMESCALE/realtimeGraph/urls.py` | Ruta `api/v1/analytics/range-stats` (Timescale). |
| `Pruebas range-stats.jmx` | Script JMeter para pruebas de carga del nuevo endpoint. |

**[AJUSTAR RUTAS SI TU REPO TIENE ESTRUCTURA DIFERENTE]**
