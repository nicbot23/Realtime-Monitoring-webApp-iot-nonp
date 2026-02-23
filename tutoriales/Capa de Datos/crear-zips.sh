#!/bin/bash
# Crear ZIPs para desplegar en EC2 (Ubuntu). Compatible con unzip en Linux.
# En macOS evita incluir __MACOSX y archivos ._* (COPYFILE_DISABLE).
# Ejecutar desde esta misma carpeta: ./crear-zips.sh

set -e
cd "$(dirname "$0")"

# En macOS: evita que zip añada resource forks (.__* y __MACOSX)
export COPYFILE_DISABLE=1

echo "Creando postgresMonitoring.zip (para Ubuntu)..."
zip -r postgresMonitoringReto.zip realtimeMonitoringPOSGRES \
  -x "*.pyc" "*__pycache__*" "*.git*" ".DS_Store" "__MACOSX*" "._*" \
  -x "realtimeMonitoringPOSGRES/.venv/*" "realtimeMonitoringPOSGRES/.env" 2>/dev/null || true

echo "Creando timescaleMonitoring.zip (para Ubuntu)..."
zip -r timescaleMonitoringReto.zip realtimeMonitoringTIMESCALE \
  -x "*.pyc" "*__pycache__*" "*.git*" ".DS_Store" "__MACOSX*" "._*" \
  -x "realtimeMonitoringTIMESCALE/.venv/*" "realtimeMonitoringTIMESCALE/.env" 2>/dev/null || true

echo "Listo. Archivos (descomprimir en EC2 con: unzip -o <archivo>.zip):"
ls -la postgresMonitoring.zip timescaleMonitoring.zip
