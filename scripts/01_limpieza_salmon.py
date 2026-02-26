import pandas as pd
import numpy as np
import sqlite3
import os
from datetime import datetime
import re
from collections import Counter
import warnings
warnings.filterwarnings('ignore')
# ==========================================
# CONFIGURACIÓN
# ==========================================
EXCEL_FILE = "proyectos/TFG/Biodatos capturas salmon.xlsx"
OUTPUT_DB = "proyectos/TFG/salmones_asturias.db"
OUTPUT_CSV = "proyectos/TFG/salmones_asturias_limpio.csv"
REPORT_FILE = "proyectos/TFG/reporte_limpieza.txt"

# ==========================================
# FUNCIONES AUXILIARES
# ==========================================

def normalize_text(text):
    """Normaliza texto: elimina espacios extra, convierte a mayúsculas, etc."""
    if pd.isna(text):
        return None
    text = str(text).strip().upper()
    # Elimina espacios múltiples
    text = re.sub(r'\s+', ' ', text)
    # Normaliza acentos comunes
    replacements = {
        'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U',
        'Ñ': 'N'
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text if text else None

def detect_outliers_iqr(series):
    """Detecta outliers usando el método IQR"""
    Q1 = series.quantile(0.25)
    Q3 = series.quantile(0.75)
    IQR = Q3 - Q1
    lower_bound = Q1 - 1.5 * IQR
    upper_bound = Q3 + 1.5 * IQR
    return (series < lower_bound) | (series > upper_bound)

def validate_weight_length_ratio(peso, longitud):
    """Valida que la relación peso/longitud sea razonable para salmones"""
    # Relación aproximada: peso (g) ≈ 0.01 * longitud(cm)^3 para salmones
    # Rangos razonables: longitud 20-120 cm, peso 100-15000 g
    if pd.isna(peso) or pd.isna(longitud) or longitud <= 0:
        return True  # No podemos validar sin ambos valores
    
    # Ratio esperado (g/cm³)
    expected_ratio = 0.01
    calculated_ratio = peso / (longitud ** 3) if longitud > 0 else None
    
    # Rangos razonables
    min_ratio = 0.001  # Mínimo razonable
    max_ratio = 0.1    # Máximo razonable
    
    if calculated_ratio is None:
        return True
    
    # Verificar si está fuera de rango razonable
    if calculated_ratio < min_ratio or calculated_ratio > max_ratio:
        return False
    
    return True

def validate_weight_length_ratio_vectorized(peso_series, longitud_series):
    """Versión vectorizada de validate_weight_length_ratio"""
    # Crear máscara para valores válidos (ambos presentes y longitud > 0)
    valid_mask = pd.notna(peso_series) & pd.notna(longitud_series) & (longitud_series > 0)
    
    # Calcular ratio solo donde es válido
    ratio = pd.Series(np.nan, index=peso_series.index)
    ratio[valid_mask] = peso_series[valid_mask] / (longitud_series[valid_mask] ** 3)
    
    # Rangos razonables
    min_ratio = 0.001
    max_ratio = 0.1
    
    # Retornar True donde no hay error (NaN o dentro de rango)
    result = pd.Series(True, index=peso_series.index)
    result[valid_mask] = (ratio[valid_mask] >= min_ratio) & (ratio[valid_mask] <= max_ratio)
    
    return result

# ==========================================
# MAPEO DE NOMBRES DE RÍOS (normalización)
# ==========================================
# Este diccionario se puede expandir según encuentres variaciones

RIO_NORMALIZATION = {
    # Ejemplos comunes - expandir según tus datos
    'RIO NALON': ['NALON', 'NALÓN', 'R. NALON', 'R. NALÓN'],
    'RIO NARCEA': ['NARCEA', 'NARCEA', 'R. NARCEA'],
    'RIO Sella': ['SELLA', 'SELLA', 'R. SELLA'],
    'RIO Cares': ['CARES', 'CARES', 'R. CARES'],
    'RIO Deva': ['DEVA', 'DEVA', 'R. DEVA'],
    # Añadir más según encuentres en el análisis
}

def normalize_rio_name(rio):
    """Normaliza el nombre del río usando el diccionario de mapeo"""
    if pd.isna(rio):
        return None
    
    rio_normalized = normalize_text(rio)
    
    # Buscar en el diccionario de normalización
    for standard_name, variants in RIO_NORMALIZATION.items():
        if rio_normalized in variants or rio_normalized == standard_name:
            return standard_name
    
    # Si no está en el diccionario, devolver normalizado
    return rio_normalized

# ==========================================
# ANÁLISIS INICIAL DEL EXCEL
# ==========================================

print("=" * 80)
print("ANÁLISIS INICIAL DEL ARCHIVO EXCEL")
print("=" * 80)

# Leer todas las hojas del Excel
excel_file = pd.ExcelFile(EXCEL_FILE)
sheet_names = excel_file.sheet_names

print(f"\n📊 Hojas encontradas: {len(sheet_names)}")
for i, sheet in enumerate(sheet_names, 1):
    print(f"   {i}. {sheet}")

# Analizar estructura de cada hoja
structure_report = []
all_sheets_data = {}

for sheet_name in sheet_names:
    print(f"\n🔍 Analizando hoja: {sheet_name}")
    
    # Intentar leer con diferentes configuraciones
    df = None
    skip_rows = 0
    
    # Intentar leer normalmente primero
    try:
        df = pd.read_excel(EXCEL_FILE, sheet_name=sheet_name)
    except:
        pass
    
    # Si falla o parece tener encabezados en filas posteriores, intentar con skiprows
    if df is None or df.empty:
        for skip in range(1, 10):
            try:
                df = pd.read_excel(EXCEL_FILE, sheet_name=sheet_name, skiprows=skip)
                if not df.empty:
                    skip_rows = skip
                    break
            except:
                continue
    
    if df is None or df.empty:
        print(f"   ⚠️  No se pudo leer la hoja {sheet_name}")
        continue
    
    # Guardar datos
    all_sheets_data[sheet_name] = {
        'data': df,
        'skip_rows': skip_rows,
        'columns': list(df.columns),
        'shape': df.shape
    }
    
    print(f"   ✓ Filas: {df.shape[0]}, Columnas: {df.shape[1]}")
    print(f"   ✓ Columnas: {', '.join([str(c)[:20] for c in df.columns[:5]])}...")

# ==========================================
# PROCESAMIENTO Y LIMPIEZA
# ==========================================

print("\n" + "=" * 80)
print("PROCESAMIENTO Y LIMPIEZA DE DATOS")
print("=" * 80)

all_records = []
errors_log = []

for sheet_name, sheet_info in all_sheets_data.items():
    df = sheet_info['data'].copy()
    skip_rows = sheet_info['skip_rows']
    
    # Extraer año del nombre de la hoja
    year_match = re.search(r'(\d{4})', sheet_name)
    year = year_match.group(1) if year_match else None
    
    print(f"\n📅 Procesando {sheet_name} (Año: {year})")
    
    # Normalizar nombres de columnas
    df.columns = [normalize_text(str(c)) for c in df.columns]
    
    # Identificar columnas clave
    col_rio = None
    col_fecha = None
    col_peso = None
    col_longitud = None
    col_precinto = None
    col_lugar = None
    
    for col in df.columns:
        col_upper = str(col).upper()
        if not col_rio and any(x in col_upper for x in ['RIO', 'RÍO', 'CUENCA']):
            col_rio = col
        if not col_fecha and any(x in col_upper for x in ['FECHA', 'F.', 'DATE']):
            col_fecha = col
        if not col_peso and any(x in col_upper for x in ['PESO', 'WEIGHT', 'P.']):
            col_peso = col
        if not col_longitud and any(x in col_upper for x in ['LONGITUD', 'LONG', 'LON', 'LENGTH']):
            col_longitud = col
        if not col_precinto and any(x in col_upper for x in ['PRECINTO', 'ID', 'NUMERO']):
            col_precinto = col
        if not col_lugar and any(x in col_upper for x in ['LUGAR', 'LOCALIDAD', 'SITIO']):
            col_lugar = col
    
    print(f"   Columnas identificadas:")
    print(f"     - Río: {col_rio}")
    print(f"     - Fecha: {col_fecha}")
    print(f"     - Peso: {col_peso}")
    print(f"     - Longitud: {col_longitud}")
    
    # Crear DataFrame limpio con todas las filas procesadas (vectorizado)
    clean_df = pd.DataFrame(index=df.index)
    
    # Metadata
    clean_df['source_sheet'] = sheet_name
    clean_df['source_year'] = year
    clean_df['source_row'] = clean_df.index + skip_rows + 2  # +2 para contar header y 1-indexado
    
    # Procesar RÍO (vectorizado)
    if col_rio:
        clean_df['rio_raw'] = df[col_rio].astype(str).replace('nan', np.nan)
        clean_df['rio'] = df[col_rio].apply(normalize_rio_name)
    else:
        clean_df['rio_raw'] = None
        clean_df['rio'] = None
    
    # Procesar FECHA (vectorizado)
    if col_fecha:
        # Convertir toda la columna de una vez
        clean_df['fecha'] = pd.to_datetime(df[col_fecha], errors='coerce', dayfirst=True)
    else:
        clean_df['fecha'] = None
    
    # Procesar PESO (vectorizado)
    if col_peso:
        # Convertir a string, reemplazar comas por puntos, luego a numérico
        peso_str = df[col_peso].astype(str).str.replace(',', '.', regex=False)
        clean_df['peso'] = pd.to_numeric(peso_str, errors='coerce')
        
        # Convertir kg a gramos: si peso < 30 y > 0, multiplicar por 1000 (vectorizado)
        mask_kg = (clean_df['peso'] < 30) & (clean_df['peso'] > 0)
        clean_df.loc[mask_kg, 'peso'] = clean_df.loc[mask_kg, 'peso'] * 1000
    else:
        clean_df['peso'] = None
    
    # Procesar LONGITUD (vectorizado)
    if col_longitud:
        long_str = df[col_longitud].astype(str).str.replace(',', '.', regex=False)
        clean_df['longitud'] = pd.to_numeric(long_str, errors='coerce')
    else:
        clean_df['longitud'] = None
    
    # Procesar PRECINTO (vectorizado)
    if col_precinto:
        clean_df['precinto'] = df[col_precinto].astype(str).str.strip().replace('nan', np.nan)
    else:
        clean_df['precinto'] = None
    
    # Procesar LUGAR (vectorizado)
    if col_lugar:
        clean_df['lugar'] = df[col_lugar].apply(normalize_text)
    else:
        clean_df['lugar'] = None
    
    # ==========================================
    # DETECCIÓN DE ERRORES (vectorizada)
    # ==========================================
    
    # Crear máscaras booleanas para cada tipo de error
    error_masks = {}
    error_messages = {}
    
    # Error 1: Ratio peso/longitud inconsistente
    if col_peso and col_longitud:
        valid_ratio_mask = validate_weight_length_ratio_vectorized(
            clean_df['peso'], clean_df['longitud']
        )
        error_masks['ratio_inconsistente'] = ~valid_ratio_mask
        error_messages['ratio_inconsistente'] = (
            "Ratio peso/longitud inconsistente: " + 
            clean_df['peso'].astype(str) + "g / " + 
            clean_df['longitud'].astype(str) + "cm"
        )
    
    # Error 2: Peso fuera de rango
    if col_peso:
        peso_valido = pd.notna(clean_df['peso'])
        peso_fuera_rango = peso_valido & ((clean_df['peso'] < 50) | (clean_df['peso'] > 20000))
        error_masks['peso_fuera_rango'] = peso_fuera_rango
        error_messages['peso_fuera_rango'] = (
            "Peso fuera de rango: " + clean_df['peso'].astype(str) + "g"
        )
    
    # Error 3: Longitud fuera de rango
    if col_longitud:
        long_valida = pd.notna(clean_df['longitud'])
        long_fuera_rango = long_valida & ((clean_df['longitud'] < 10) | (clean_df['longitud'] > 150))
        error_masks['longitud_fuera_rango'] = long_fuera_rango
        error_messages['longitud_fuera_rango'] = (
            "Longitud fuera de rango: " + clean_df['longitud'].astype(str) + "cm"
        )
    
    # Error 4: Fecha inconsistente con año de la hoja
    if col_fecha and year:
        fecha_valida = pd.notna(clean_df['fecha'])
        fecha_year = clean_df['fecha'].dt.year
        fecha_inconsistente = fecha_valida & (np.abs(fecha_year - int(year)) > 1)
        error_masks['fecha_inconsistente'] = fecha_inconsistente
        error_messages['fecha_inconsistente'] = (
            "Fecha inconsistente: " + clean_df['fecha'].astype(str) + 
            " vs año hoja " + str(year)
        )
    
    # Combinar todas las máscaras de error
    tiene_errores = pd.Series(False, index=clean_df.index)
    for mask in error_masks.values():
        tiene_errores = tiene_errores | mask
    
    # Separar filas con errores y sin errores
    filas_con_errores = clean_df[tiene_errores].copy()
    filas_sin_errores = clean_df[~tiene_errores].copy()
    
    # Construir errors_log para filas con errores
    if len(filas_con_errores) > 0:
        for idx, row in filas_con_errores.iterrows():
            errors = []
            for error_type, mask in error_masks.items():
                if mask.loc[idx]:
                    errors.append(error_messages[error_type].loc[idx])
            
            errors_log.append({
                'sheet': sheet_name,
                'row': int(row['source_row']),
                'errors': errors,
                'data': row.to_dict()
            })
    
    # Filtrar filas válidas: deben tener al menos peso o longitud
    filas_validas = filas_sin_errores[
        pd.notna(filas_sin_errores['peso']) | pd.notna(filas_sin_errores['longitud'])
    ]
    
    # Convertir a lista de diccionarios para all_records
    if len(filas_validas) > 0:
        records = filas_validas.to_dict('records')
        all_records.extend(records)

# ==========================================
# CREAR DATAFRAME FINAL
# ==========================================

print("\n" + "=" * 80)
print("CREANDO DATAFRAME FINAL")
print("=" * 80)

df_final = pd.DataFrame(all_records)

# Detección adicional de outliers usando estadísticas
if len(df_final) > 0:
    print(f"\n📊 Total de registros procesados: {len(df_final)}")
    
    # Detectar outliers estadísticos
    if 'peso' in df_final.columns:
        peso_validos = df_final['peso'].dropna()
        if len(peso_validos) > 10:
            outliers_peso = detect_outliers_iqr(peso_validos)
            print(f"   ⚠️  Outliers en peso detectados: {outliers_peso.sum()}")
    
    if 'longitud' in df_final.columns:
        long_validos = df_final['longitud'].dropna()
        if len(long_validos) > 10:
            outliers_long = detect_outliers_iqr(long_validos)
            print(f"   ⚠️  Outliers en longitud detectados: {outliers_long.sum()}")

# ==========================================
# ANÁLISIS DE NOMBRES DE RÍOS
# ==========================================

print("\n" + "=" * 80)
print("ANÁLISIS DE NOMBRES DE RÍOS")
print("=" * 80)

if 'rio_raw' in df_final.columns:
    rios_raw = df_final['rio_raw'].dropna().unique()
    rios_normalized = df_final['rio'].dropna().unique()
    
    print(f"\n📊 Nombres únicos de ríos (raw): {len(rios_raw)}")
    print(f"📊 Nombres únicos de ríos (normalizados): {len(rios_normalized)}")
    
    # Contar frecuencias
    rio_counts = df_final['rio'].value_counts()
    print(f"\n🔝 Top 10 ríos por frecuencia:")
    for rio, count in rio_counts.head(10).items():
        print(f"   {rio}: {count} capturas")
    
    # Identificar posibles duplicados (nombres similares)
    print(f"\n🔍 Posibles variaciones de nombres (revisar manualmente):")
    rios_sorted = sorted(rios_normalized)
    for i, rio1 in enumerate(rios_sorted):
        for rio2 in rios_sorted[i+1:]:
            # Calcular similitud simple (nombres que comparten muchas letras)
            if rio1 and rio2:
                common_chars = len(set(rio1) & set(rio2))
                similarity = common_chars / max(len(rio1), len(rio2))
                if similarity > 0.7 and rio1 != rio2:
                    print(f"   '{rio1}' vs '{rio2}' (similitud: {similarity:.2f})")

# ==========================================
# REPORTE DE ERRORES
# ==========================================

print("\n" + "=" * 80)
print("REPORTE DE ERRORES DETECTADOS")
print("=" * 80)

print(f"\n⚠️  Total de registros con errores: {len(errors_log)}")

if errors_log:
    error_types = Counter()
    for error_entry in errors_log:
        for error_msg in error_entry['errors']:
            error_type = error_msg.split(':')[0]
            error_types[error_type] += 1
    
    print("\n📋 Tipos de errores encontrados:")
    for error_type, count in error_types.most_common():
        print(f"   - {error_type}: {count}")

# ==========================================
# EXPORTACIÓN A SQL
# ==========================================

print("\n" + "=" * 80)
print("EXPORTACIÓN A SQL")
print("=" * 80)

# Preparar datos para SQL
df_sql = df_final.copy()

# Eliminar columnas auxiliares si es necesario
columns_to_keep = ['rio', 'fecha', 'peso', 'longitud', 'precinto', 'lugar', 
                   'source_year', 'source_sheet']
df_sql = df_sql[[c for c in columns_to_keep if c in df_sql.columns]]

# Renombrar para SQL (sin acentos, minúsculas)
df_sql.columns = [c.upper() for c in df_sql.columns]

# Conectar a SQLite
conn = sqlite3.connect(OUTPUT_DB)

# Crear tabla principal
df_sql.to_sql('capturas', conn, if_exists='replace', index=False)

# Crear tabla de errores si hay
if errors_log:
    df_errors = pd.DataFrame(errors_log)
    df_errors.to_sql('errores_detectados', conn, if_exists='replace', index=False)

# Crear índices para mejorar consultas
try:
    conn.execute("CREATE INDEX IF NOT EXISTS idx_rio ON capturas(RIO)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_fecha ON capturas(FECHA)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_year ON capturas(SOURCE_YEAR)")
except:
    pass

conn.close()

print(f"✅ Base de datos SQL creada: {OUTPUT_DB}")

# Exportar también a CSV
df_sql.to_csv(OUTPUT_CSV, index=False, encoding='utf-8-sig')
print(f"✅ CSV exportado: {OUTPUT_CSV}")

# ==========================================
# VERIFICACIÓN FINAL
# ==========================================

print("\n" + "=" * 80)
print("VERIFICACIÓN FINAL")
print("=" * 80)

conn = sqlite3.connect(OUTPUT_DB)

# Estadísticas básicas
query_stats = """
SELECT 
    COUNT(*) as total_registros,
    COUNT(DISTINCT RIO) as rios_unicos,
    COUNT(DISTINCT SOURCE_YEAR) as anos,
    ROUND(AVG(PESO), 2) as peso_promedio_g,
    ROUND(AVG(LONGITUD), 2) as longitud_promedio_cm,
    MIN(FECHA) as fecha_minima,
    MAX(FECHA) as fecha_maxima
FROM capturas
WHERE PESO IS NOT NULL OR LONGITUD IS NOT NULL
"""

stats = pd.read_sql_query(query_stats, conn)
print("\n📊 Estadísticas generales:")
print(stats.to_string(index=False))

# Top ríos
query_rios = """
SELECT 
    RIO,
    COUNT(*) as capturas,
    ROUND(AVG(PESO), 2) as peso_promedio_g,
    ROUND(AVG(LONGITUD), 2) as longitud_promedio_cm
FROM capturas
WHERE RIO IS NOT NULL
GROUP BY RIO
ORDER BY capturas DESC
LIMIT 10
"""

rios_stats = pd.read_sql_query(query_rios, conn)
print("\n🏞️  Top 10 ríos por capturas:")
print(rios_stats.to_string(index=False))

conn.close()

print("\n" + "=" * 80)
print("✅ PROCESO COMPLETADO")
print("=" * 80)
print(f"\n📁 Archivos generados:")
print(f"   - Base de datos SQL: {OUTPUT_DB}")
print(f"   - CSV limpio: {OUTPUT_CSV}")
print(f"\n💡 Próximos pasos:")
print(f"   1. Revisar el diccionario RIO_NORMALIZATION y expandirlo con variaciones encontradas")
print(f"   2. Revisar los errores detectados en la tabla 'errores_detectados'")
print(f"   3. Ajustar los rangos de validación si es necesario")
print(f"   4. Ejecutar el script nuevamente después de ajustes")