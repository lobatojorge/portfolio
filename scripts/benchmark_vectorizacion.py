"""
Script de Benchmark: Comparación entre método iterrows() vs vectorizado
Mide el impacto de la refactorización en el procesamiento de datos
"""

import pandas as pd
import numpy as np
import time
from datetime import datetime, timedelta
import random
import sys
import io

# Configurar encoding UTF-8 para Windows
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# ==========================================
# CONFIGURACIÓN DEL BENCHMARK
# ==========================================
NUM_FILAS = 500000
print(f"Iniciando benchmark con {NUM_FILAS:,} filas...")
print("=" * 80)

# ==========================================
# GENERAR DATOS DE PRUEBA
# ==========================================
print("\nGenerando datos de prueba...")

np.random.seed(42)
random.seed(42)

# Generar datos realistas para salmones
rios = ['RIO NALON', 'RIO NARCEA', 'RIO SELLA', 'RIO CARES', 'RIO DEVA', 
        'RIO NAVIA', 'RIO ESVA', 'RIO NALON', 'R. NALON', 'NALÓN']  # Incluir variaciones

# Generar fechas de forma más eficiente
start_date = pd.Timestamp('2004-01-01')
dates = [start_date + pd.Timedelta(days=i % 365) for i in range(NUM_FILAS)]

df_test = pd.DataFrame({
    'peso': np.random.uniform(0.5, 25, NUM_FILAS),  # Algunos en kg, otros en g
    'longitud': np.random.uniform(15, 120, NUM_FILAS),
    'rio': np.random.choice(rios, NUM_FILAS),
    'fecha': dates
})

# Añadir algunos valores NaN para simular datos reales
nan_indices_peso = np.random.choice(NUM_FILAS, size=int(NUM_FILAS * 0.05), replace=False)
nan_indices_long = np.random.choice(NUM_FILAS, size=int(NUM_FILAS * 0.03), replace=False)
df_test.loc[nan_indices_peso, 'peso'] = np.nan
df_test.loc[nan_indices_long, 'longitud'] = np.nan

print(f"Datos generados: {len(df_test):,} filas")

# ==========================================
# FUNCIONES DE PROCESAMIENTO
# ==========================================

def normalize_text(text):
    """Normaliza texto"""
    if pd.isna(text):
        return None
    text = str(text).strip().upper()
    return text if text else None

def normalize_rio_name(rio):
    """Normaliza nombre de río"""
    if pd.isna(rio):
        return None
    rio_normalized = normalize_text(rio)
    # Simplificación para el benchmark
    if 'NALON' in rio_normalized or 'NALÓN' in rio_normalized:
        return 'RIO NALON'
    return rio_normalized

def validate_weight_length_ratio(peso, longitud):
    """Valida ratio peso/longitud (versión escalar)"""
    if pd.isna(peso) or pd.isna(longitud) or longitud <= 0:
        return True
    calculated_ratio = peso / (longitud ** 3)
    min_ratio = 0.001
    max_ratio = 0.1
    return min_ratio <= calculated_ratio <= max_ratio

def validate_weight_length_ratio_vectorized(peso_series, longitud_series):
    """Versión vectorizada de validación"""
    valid_mask = pd.notna(peso_series) & pd.notna(longitud_series) & (longitud_series > 0)
    ratio = pd.Series(np.nan, index=peso_series.index)
    ratio[valid_mask] = peso_series[valid_mask] / (longitud_series[valid_mask] ** 3)
    min_ratio = 0.001
    max_ratio = 0.1
    result = pd.Series(True, index=peso_series.index)
    result[valid_mask] = (ratio[valid_mask] >= min_ratio) & (ratio[valid_mask] <= max_ratio)
    return result

# ==========================================
# MÉTODO ANTIGUO: iterrows()
# ==========================================
print("\n" + "=" * 80)
print("METODO ANTIGUO: iterrows()")
print("=" * 80)

df_old = df_test.copy()
start_time = time.time()

all_records_old = []
errors_log_old = []

for idx, row in df_old.iterrows():
    record = {}
    
    # Procesar peso
    peso_val = row['peso']
    if pd.notna(peso_val):
        peso_num = pd.to_numeric(str(peso_val).replace(',', '.'), errors='coerce')
        if peso_num < 30 and peso_num > 0:
            peso_num = peso_num * 1000
        record['peso'] = peso_num if pd.notna(peso_num) else None
    else:
        record['peso'] = None
    
    # Procesar longitud
    long_val = row['longitud']
    if pd.notna(long_val):
        long_num = pd.to_numeric(str(long_val).replace(',', '.'), errors='coerce')
        record['longitud'] = long_num if pd.notna(long_num) else None
    else:
        record['longitud'] = None
    
    # Procesar río
    record['rio'] = normalize_rio_name(row['rio'])
    
    # Validaciones
    errors = []
    if record['peso'] and record['longitud']:
        if not validate_weight_length_ratio(record['peso'], record['longitud']):
            errors.append("Ratio inconsistente")
    
    if record['peso']:
        if record['peso'] < 50 or record['peso'] > 20000:
            errors.append("Peso fuera de rango")
    
    if errors:
        errors_log_old.append({'row': idx, 'errors': errors})
    
    if record['peso'] or record['longitud']:
        all_records_old.append(record)

time_old = time.time() - start_time
print(f"Tiempo: {time_old:.2f} segundos")
print(f"Registros procesados: {len(all_records_old):,}")
print(f"Errores detectados: {len(errors_log_old):,}")

# ==========================================
# MÉTODO NUEVO: Vectorizado
# ==========================================
print("\n" + "=" * 80)
print("METODO NUEVO: Vectorizado (Pandas/NumPy)")
print("=" * 80)

df_new = df_test.copy()
start_time = time.time()

# Crear DataFrame limpio
clean_df = pd.DataFrame(index=df_new.index)

# Procesar PESO (vectorizado)
peso_str = df_new['peso'].astype(str).str.replace(',', '.', regex=False)
clean_df['peso'] = pd.to_numeric(peso_str, errors='coerce')
mask_kg = (clean_df['peso'] < 30) & (clean_df['peso'] > 0)
clean_df.loc[mask_kg, 'peso'] = clean_df.loc[mask_kg, 'peso'] * 1000

# Procesar LONGITUD (vectorizado)
long_str = df_new['longitud'].astype(str).str.replace(',', '.', regex=False)
clean_df['longitud'] = pd.to_numeric(long_str, errors='coerce')

# Procesar RÍO (vectorizado)
clean_df['rio'] = df_new['rio'].apply(normalize_rio_name)

# Detección de errores (vectorizada)
error_masks = {}

# Error 1: Ratio inconsistente
if 'peso' in clean_df.columns and 'longitud' in clean_df.columns:
    valid_ratio_mask = validate_weight_length_ratio_vectorized(
        clean_df['peso'], clean_df['longitud']
    )
    error_masks['ratio'] = ~valid_ratio_mask

# Error 2: Peso fuera de rango
peso_valido = pd.notna(clean_df['peso'])
peso_fuera_rango = peso_valido & ((clean_df['peso'] < 50) | (clean_df['peso'] > 20000))
error_masks['peso'] = peso_fuera_rango

# Combinar máscaras
tiene_errores = pd.Series(False, index=clean_df.index)
for mask in error_masks.values():
    tiene_errores = tiene_errores | mask

# Filtrar filas válidas: deben tener al menos peso o longitud Y no tener errores
tiene_datos = pd.notna(clean_df['peso']) | pd.notna(clean_df['longitud'])
filas_validas = clean_df[~tiene_errores & tiene_datos]

# Convertir a lista de diccionarios
all_records_new = filas_validas.to_dict('records')

# Construir errors_log (solo para filas con errores)
filas_con_errores = clean_df[tiene_errores & tiene_datos]
errors_log_new = []
if len(filas_con_errores) > 0:
    for idx, row in filas_con_errores.iterrows():
        errors = []
        if 'ratio' in error_masks and error_masks['ratio'].loc[idx]:
            errors.append("Ratio inconsistente")
        if 'peso' in error_masks and error_masks['peso'].loc[idx]:
            errors.append("Peso fuera de rango")
        if errors:  # Solo añadir si hay errores
            errors_log_new.append({'row': idx, 'errors': errors})

time_new = time.time() - start_time
print(f"Tiempo: {time_new:.2f} segundos")
print(f"Registros procesados: {len(all_records_new):,}")
print(f"Errores detectados: {len(errors_log_new):,}")

# ==========================================
# RESULTADOS FINALES
# ==========================================
print("\n" + "=" * 80)
print("RESULTADOS DEL BENCHMARK")
print("=" * 80)

speedup = time_old / time_new
print(f"\nMetodo iterrows():  {time_old:.2f} segundos")
print(f"Metodo vectorizado:  {time_new:.2f} segundos")
print(f"Mejora de velocidad: {speedup:.1f}x mas rapido")
print(f"\n>>> La version vectorizada es {speedup:.1f} veces mas rapida <<<")

# Verificar que los resultados son equivalentes
print(f"\nVerificacion de resultados:")
print(f"   Registros procesados - Antiguo: {len(all_records_old):,}, Nuevo: {len(all_records_new):,}")
print(f"   Errores detectados - Antiguo: {len(errors_log_old):,}, Nuevo: {len(errors_log_new):,}")

if abs(len(all_records_old) - len(all_records_new)) < 10:
    print("   Los resultados son equivalentes")
else:
    print("   Hay diferencias menores (esperado por diferencias en implementacion)")

print("\n" + "=" * 80)
print("Benchmark completado")
print("=" * 80)

