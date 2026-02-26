# Optimización de Procesamiento de Datos: Vectorización con Pandas/NumPy

## 📊 Resultados del Benchmark

**Configuración:** 500,000 filas de datos simulados  
**Método Antiguo (iterrows):** ~XX segundos  
**Método Nuevo (Vectorizado):** ~XX segundos  
**Mejora:** X.X veces más rápido

> **Nota:** Ejecuta `scripts/benchmark_vectorizacion.py` para obtener resultados reales en tu máquina.

---

## 🔬 Explicación Técnica: ¿Por qué es más rápido?

### El Problema con `iterrows()`

Cuando usas `iterrows()`, Python está ejecutando un bucle puro de Python sobre cada fila del DataFrame. Esto implica:

1. **Overhead de Python Loops**: Cada iteración requiere:
   - Crear un objeto `Series` para cada fila
   - Resolver nombres de columnas mediante diccionarios de Python
   - Llamadas a funciones Python (con overhead de call stack)
   - Type checking y conversiones en cada iteración
   - Gestión de memoria para objetos Python individuales

2. **Interpretación vs Compilación**: Python es un lenguaje interpretado. Cada línea de código se traduce a bytecode y luego se ejecuta, añadiendo overhead significativo.

3. **Cache Misses**: Acceder a datos fila por fila no aprovecha la localidad espacial de memoria. El CPU cache se llena y vacía constantemente.

### La Solución: Vectorización con Pandas/NumPy

Las operaciones vectorizadas aprovechan:

1. **C-level Optimization**: Pandas y NumPy están escritos en C/Cython. Cuando haces `df['col'] * 1000`, esta operación se ejecuta completamente en C, sin overhead de Python loops.

2. **SIMD Instructions**: Los procesadores modernos tienen instrucciones SIMD (Single Instruction, Multiple Data) que pueden procesar múltiples valores simultáneamente. NumPy aprovecha estas instrucciones automáticamente.

3. **Gestión de Memoria Eficiente**: 
   - Los datos se almacenan en arrays contiguos en memoria (no en objetos Python dispersos)
   - Operaciones en bloque reducen allocaciones/deallocaciones
   - Mejor uso del CPU cache (datos contiguos = mejor cache hit rate)

4. **Paralelización Implícita**: Muchas operaciones de NumPy pueden usar múltiples cores automáticamente (dependiendo de la implementación de BLAS/LAPACK).

### Ejemplo Concreto

**Antes (iterrows):**
```python
for idx, row in df.iterrows():
    peso = row['peso'] * 1000  # Python loop, type checking, dict lookup
```
- ~500,000 iteraciones de Python
- ~500,000 lookups de diccionario
- ~500,000 type checks

**Después (vectorizado):**
```python
df['peso'] = df['peso'] * 1000  # Una llamada a C, procesa todo el array
```
- 1 llamada a función C
- Operación en bloque sobre array contiguo
- Posible paralelización automática

### Escalabilidad

La diferencia se amplifica con el tamaño de los datos:
- **10K filas**: 2-5x más rápido
- **100K filas**: 10-50x más rápido  
- **1M+ filas**: 50-200x más rápido

Esto se debe a que el overhead de Python loops crece linealmente, mientras que las operaciones vectorizadas tienen overhead constante.

---

## 💼 Valor para el Empleador

### Bullet Point para CV

**Optimización de Procesamiento de Datos**
- Refactoricé un pipeline de limpieza de datos de 500K+ registros, reemplazando bucles `iterrows()` por operaciones vectorizadas de Pandas/NumPy, logrando una mejora de rendimiento de **X.X veces** y reduciendo el tiempo de procesamiento de **XX minutos a XX segundos**, mejorando significativamente la escalabilidad del sistema para datasets más grandes.

### Respuesta para Entrevista

**Pregunta:** "¿Cuéntame de un desafío técnico que resolviste y cómo optimizaste el código?"

**Respuesta:**

"Durante mi Trabajo Fin de Grado, trabajé con un dataset de capturas de salmón con más de 500,000 registros históricos. El código original procesaba los datos fila por fila usando `iterrows()`, lo cual funcionaba pero era extremadamente lento - tomaba varios minutos procesar el dataset completo.

Identifiqué que el cuello de botella era el uso de bucles Python puros sobre un DataFrame grande. Refactoricé el código para usar operaciones vectorizadas de Pandas y NumPy, reemplazando el procesamiento fila por fila con operaciones en bloque sobre columnas completas.

Los cambios clave incluyeron:
- Conversión de tipos usando `pd.to_numeric()` sobre columnas completas
- Detección de errores usando máscaras booleanas vectorizadas en lugar de condicionales fila por fila
- Aprovechamiento de operaciones vectorizadas de NumPy para cálculos matemáticos

El resultado fue una mejora de rendimiento de **X.X veces**, reduciendo el tiempo de procesamiento de minutos a segundos. Esto no solo mejoró la experiencia del usuario, sino que también hizo el código más escalable - ahora puede manejar datasets mucho más grandes sin problemas de rendimiento.

Lo más importante es que aprendí a identificar cuellos de botella de rendimiento y a aplicar técnicas de optimización apropiadas, balanceando legibilidad del código con eficiencia computacional."

---

## 📝 Notas Adicionales

### Cuándo usar cada método

**Usa vectorización cuando:**
- Operaciones matemáticas sobre columnas completas
- Filtrado y transformación de datos
- Operaciones que pueden expresarse como operaciones de array

**Considera iterrows/itertuples cuando:**
- Lógica compleja que requiere estado entre filas
- Operaciones que no se pueden vectorizar fácilmente
- Datasets muy pequeños donde el overhead es mínimo

### Métricas de Impacto Real

Para obtener métricas reales en tu máquina:
```bash
python scripts/benchmark_vectorizacion.py
```

Esto te dará números específicos que puedes usar en tu CV y presentaciones.

