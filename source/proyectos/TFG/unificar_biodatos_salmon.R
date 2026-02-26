# =============================================================================
# Unificación y limpieza de Biodatos capturas salmón (múltiples hojas Excel)
# Ingeniería de datos: tidyverse, lubridate, readxl, janitor
# =============================================================================

library(readxl)
library(tidyverse)
library(lubridate)
library(janitor)

# -----------------------------------------------------------------------------
# 1. Rutas y lectura de nombres de hojas
# -----------------------------------------------------------------------------
path_excel <- "Biodatos capturas salmon.xlsx"
hojas <- excel_sheets(path_excel)

# Órdenes de fecha/hora flexibles para parse_date_time
ordenes_fecha <- c(
  "dmY HMS", "dmy HMS", "dmY HM", "dmy HM",
  "Ymd HMS", "Ymd HM", "Y-m-d H:M:S", "Y-m-d H:M",
  "dmY", "dmy", "Ymd", "Y-m-d"
)

# -----------------------------------------------------------------------------
# 2. Función: parsear fecha y extraer fecha + hora por separado
# -----------------------------------------------------------------------------
#' Convierte un vector de fechas (con o sin hora) en fecha y hora por separado.
#' Si no hay hora, fecha se conserva y hora queda NA (o 00:00 según prefieras).
separar_fecha_hora <- function(x) {
  x <- as.character(x)
  parsed <- parse_date_time(x, orders = ordenes_fecha, quiet = TRUE)
  fecha <- as_date(parsed)
  # Hora: conservar solo si el original incluía hora (heurística: contiene ":")
  tiene_hora <- str_detect(str_trim(x), "\\d{1,2}:\\d{2}")
  hora <- if_else(tiene_hora, format(parsed, "%H:%M:%S"), NA_character_)
  tibble(fecha = fecha, hora = hora)
}

# -----------------------------------------------------------------------------
# 3. Función de normalización por hoja
# -----------------------------------------------------------------------------
normalizar_hoja <- function(nombre_hoja) {
  df <- read_excel(path_excel, sheet = nombre_hoja) %>%
    janitor::clean_names()

  # ----- Columnas a eliminar (PII y códigos de río) -----
  eliminar <- c(
    "dni", "cliente", "pescador", "precinto", "telefono", "domicilio",
    "cod", "c_rio", "id", "codigo", "codigo_rio", "codigo_de_rio"
  )
  # Cualquier columna que coincida con patrones de código de río
  nms <- names(df)
  codigos_rio <- nms[str_detect(nms, "cod|id_rio|c_rio|^id$")]
  df <- df %>% select(-any_of(c(eliminar, codigos_rio)))

  # ----- Detectar columna de fecha (puede ser fecha, fecha_captura, etc.) -----
  col_fecha <- nms[nms %in% c("fecha", "fecha_captura", "fecha_de_captura", "date")]
  if (length(col_fecha) == 0) {
    col_fecha <- nms[str_detect(nms, "fecha")]
  }
  if (length(col_fecha) == 0) {
    # Sin columna fecha explícita: mantener df y añadir fecha/hora NA
    df <- df %>% mutate(fecha = as_date(NA), hora = NA_character_)
  } else {
    col_fecha <- col_fecha[1]
    sep <- separar_fecha_hora(pull(df, !!col_fecha))
    df <- df %>%
      select(-!!col_fecha) %>%
      mutate(fecha = sep$fecha, hora = sep$hora)
  }

  # ----- Topónimo: Pozo / Lugar -> pozo (character) -----
  nms <- names(df)
  col_pozo <- nms[nms %in% c("pozo", "lugar", "lugar_de_captura", "toponimo")]
  if (length(col_pozo) == 0) {
    col_pozo <- nms[str_detect(nms, "pozo|lugar|toponimo")]
  }
  if (length(col_pozo) > 0) {
    col_pozo <- col_pozo[1]
    df <- df %>%
      rename(pozo = !!col_pozo) %>%
      mutate(pozo = as.character(pozo))
  } else {
    df <- df %>% mutate(pozo = NA_character_)
  }

  # ----- Río: nombre del río -> rio; NARCEA-NALON -> cuenca -----
  nms <- names(df)
  # Columna nombre del río (evitar códigos)
  col_rio <- nms[str_detect(nms, "rio|river|nombre_rio") & !str_detect(nms, "cod|id")]
  if (length(col_rio) == 0) col_rio <- nms[nms == "rio"]
  if (length(col_rio) > 0) {
    col_rio <- col_rio[1]
    df <- df %>% rename(rio = !!col_rio) %>% mutate(rio = as.character(rio))
  } else {
    df <- df %>% mutate(rio = NA_character_)
  }
  if (!"cuenca" %in% names(df)) df <- df %>% mutate(cuenca = NA_character_)
  # Si existe columna NARCEA-NALON (p. ej. narcea_nalon por clean_names), renombrar a cuenca
  if ("narcea_nalon" %in% names(df)) {
    df <- df %>% mutate(cuenca = coalesce(cuenca, as.character(narcea_nalon))) %>% select(-narcea_nalon)
  }

  # ----- Peso: unificar a gramos -----
  nms <- names(df)
  col_peso <- nms[nms %in% c("peso", "peso_gramos", "weight")]
  if (length(col_peso) == 0) col_peso <- nms[str_detect(nms, "peso")]
  if (length(col_peso) > 0) {
    col_peso <- col_peso[1]
    df <- df %>%
      mutate(peso_raw = as.numeric(!!sym(col_peso))) %>%
      mutate(peso_gramos = case_when(
        is.na(peso_raw) ~ NA_real_,
        peso_raw < 40   ~ peso_raw * 1000,
        TRUE            ~ peso_raw
      )) %>%
      select(-peso_raw, -!!col_peso)
  } else {
    df <- df %>% mutate(peso_gramos = NA_real_)
  }

  df
}

# -----------------------------------------------------------------------------
# 4. Unificar todas las hojas en el Dataframe maestro
# -----------------------------------------------------------------------------
salmon <- hojas %>%
  set_names(hojas) %>%
  map_dfr(normalizar_hoja, .id = "hoja_origen")

# -----------------------------------------------------------------------------
# 5. Glimpse y conteo hora vs solo fecha
# -----------------------------------------------------------------------------
cat("\n========== GLIMPSE DEL DATAFRAME MAESTRO 'salmon' ==========\n\n")
glimpse(salmon)

con_hora_valida <- salmon %>%
  filter(!is.na(hora)) %>%
  nrow()
solo_fecha <- salmon %>%
  filter(!is.na(fecha) & is.na(hora)) %>%
  nrow()
sin_fecha <- salmon %>%
  filter(is.na(fecha)) %>%
  nrow()

cat("\n========== REGISTROS: HORA VÁLIDA vs SOLO FECHA ==========\n")
cat("  Con hora válida (no NA): ", con_hora_valida, "\n")
cat("  Solo fecha (hora NA):   ", solo_fecha, "\n")
cat("  Sin fecha:              ", sin_fecha, "\n")
cat("  Total registros:        ", nrow(salmon), "\n")
cat("============================================================\n")
