setwd('F:/TFM')
library(readxl)
arañas<- read_excel("arañas.xlsx")

arañas <- arañas[, !colnames(arañas) %in% c("Cod_DZUL", "Año", "Ordenar","X","Y","Camp","Localidad","Código_95","Fecha","Trampa","Código_muestra","Orden","Familia","Género","Especie","Determinador","Observaciones")]
library(dplyr)
arañas <- arañas %>%
  select(Código_localidad, Año2, Taxon, N_exx., Muestreo)%>%
  rename(Año = Año2)
arañas$N_exx. <- as.numeric(arañas$N_exx.)
arañas=arañas[complete.cases(arañas), ]        # elimina filas con NA

## riqueza por año
riqueza <- arañas %>%
  filter(Año %in% c(1995, 2024)) %>%  # Filtramos solo los años 1995 y 2024
  group_by(Código_localidad, Año) %>%
  summarise(riqueza = n_distinct(Taxon), .groups = "drop")  # Contamos taxones únic
library(ggplot2)
font_add_google("Lexend", "lexend")  # Carga la fuente desde Google Fonts
showtext_auto() 
ggplot(riqueza, aes(x = factor(Año), y = riqueza, fill = factor(Año))) +
  geom_boxplot() +
  labs(title = "Comparación de Riqueza entre 1995 y 2024",
       x = "Año",
       y = "Riqueza", fill = "Año") +
  scale_fill_manual(values = c("#AEC6CF", "#F08080")) +  # Puedes cambiar los colores
  theme_minimal()+
  theme(
    text = element_text(family = "lexend"),  # Aplicar Lexend a todo el gráfico
    plot.title = element_text(size = 50, face = "bold"),  # Tamaño del título
    axis.title = element_text(size = 30),  # Tamaño de ejes
    axis.text = element_text(size = 40),  # Tamaño de texto en ejes  
    legend.title = element_text(size = 30),  # Aumentar tamaño del título de la leyenda
    legend.text = element_text(size = 25))
setwd('F:/TFM/desde enero/Taxonomica/riqueza año')
ggsave("boxplot_riqueza.png", width = 6, height = 4, dpi = 300)

## GLM riqueza año
riqueza$Año <- factor(riqueza$Año)
# Modelo Poisson        modelo_poisson <- glm(riqueza ~ Año, data = riqueza, family = poisson)
# Modelo Quasipoisson   modelo_quasipoisson <- glm(riqueza ~ Año, data = riqueza, family = quasipoisson)
# Modelo Binomial Negativa  library(MASS)  modelo_nb <- glm.nb(riqueza ~ Año, data = riqueza)
# Comparar AIC de los modelos
AIC(modelo_poisson)
AIC(modelo_quasipoisson)
AIC(modelo_nb)
summary(modelo_poisson)
anova_result <- anova(modelo_poisson, test = "Chisq")
anova_result


###################  riqueza año muestreo ###################
arañas <- arañas[, !colnames(arañas) %in% c("Cod_DZUL", "Año", "Ordenar","X","Y","Camp","Localidad","Código_95","Fecha","Trampa","Código_muestra","Orden","Familia","Género","Especie","Determinador","Observaciones")]
arañas <- arañas %>%  rename(Año = Año2)
riqueza_loc_muest<-arañas %>%                  # nun se pa que hacemos esta pudiendo agrupar por año/muestreo
  group_by(Código_localidad, Año, Muestreo) %>% 
  summarise(
    Riqueza = n_distinct(Taxon), .groups = "drop")
riqueza_loc_muest$Año=as.factor(riqueza_loc_muest$Año)
ggplot(riqueza_loc_muest, aes(x=Muestreo, y=Riqueza, fill=Año))+ 
  geom_boxplot(lwd=0.3,outlier.size = 0.7)+
  labs(y="Riqueza")+
  scale_fill_manual(values = c("1995" = "#AEC6CF", "2024" = "#F08080")) +
  theme_linedraw() +
  theme(panel.grid=element_line(linetype=0), aspect.ratio=1) +
  theme(plot.title = element_text(hjust = 0.5, size = 40))+
  theme(panel.grid = element_blank(),
        axis.title.x = element_blank(),  # No mostrar título en eje X
        axis.text.x = element_text(size = 30),
        axis.ticks = element_blank(),
        axis.text.y = element_text(size = 30),
        axis.title.y = element_text(size = 30),  # Tamaño del título del eje Y
        text = element_text(family = "lexend"),  # Fuente Lexend
        legend.title = element_text(size = 30),  # Aumentar tamaño del título de la leyenda
        legend.text = element_text(size = 25)) 
setwd('F:/TFM/desde enero/Taxonomica/riqueza año')
ggsave("riqueza_año_muest.png", width = 6, height = 4, dpi = 300)

###   modelo Negative Binomial
library(MASS)
library(car)
library(DHARMa)
model_NB <- glm.nb(Riqueza~Año*Muestreo, data=riqueza_loc_muest, na.action = "na.omit")
summary(model_NB)
anova_am <- Anova(model_NB)
simulationOutputNB <- simulateResiduals(fittedModel = model_NB)  # genera residuos similados pa ver si el modelo se ajusta bien a los datos
plot(simulationOutputNB)   # genera un gráfico a partir de los residuos simulados
library(emmeans)
marginal=emmeans(model_NB,  ~Año*Muestreo)  # da predicciones ajustadas: valor (riqueza) predicho por el modelo para cada combinación de año - muestreo
pairs(marginal, adjust="tukey")  # compara esas predicciones pa ver si son estadísticamente significativas



## hay menos abundancia en Pitfall???
pitfall_aranas <- arañas %>%
  filter(Muestreo == "PIT", Año %in% c(1995, 2024)) %>%
  group_by(Año) %>%
  summarise(total_aranas = n())
datos_pit <- subset(arañas, Muestreo == "PIT")
library(nortest)
ad.test(datos_pit$N_exx.)  # porque n>50  pvalor<0.001 no sigue dis normal
wilcox.test(N_exx. ~ Año, data = subset(arañas, Muestreo == "PIT"))
### pvalor>0.1 no hay dif significativa

### qué especies desaparecen en 2024 ¿son edáficas?
library(dplyr)
arañas <- arañas %>%
  select(Código_localidad, Año2, Taxon, N_exx., Muestreo)%>%
  rename(Año = Año2)
especies_1995 <- unique(arañas[arañas$Año == 1995, 'Taxon'])
especies_2024 <- unique(arañas[arañas$Año == 2024, 'Taxon'])
especies_perdidas <- setdiff(especies_1995, especies_2024)
especies_edaficas <- c( "Alopecosa cf. orotavensis", "Alopecosa orotavensis", "Arctosa cf. cinerea",  "Canariphantes alpicola", "Erigone vagans", "Filistata aff. teideensis",  "Haplodrassus signifer", "Haplodrassus sp", "Lathys teideensis",  "Leptodrassus sp", "Lycosidae indet", "Psammitis cf. Oromii", "Psammitis squalidus", "Ozyptila tenerifensis")
especies_perdidas$edafica <- ifelse(especies_perdidas$Taxon %in% especies_edaficas, "X", "")



###################  NMDS #####################

arañas <- arañas[, !colnames(arañas) %in% c("Cod_DZUL", "Año", "Ordenar","X","Y","Camp","Localidad","Código_95","Fecha","Muestreo","Trampa","Código_muestra","Orden","Familia","Género","Especie","Determinador","Observaciones")]
arañas <- arañas %>%  rename(Año = Año2)
arañas$localidad_año <- paste(arañas$Código_localidad, arañas$Año, sep = "_")
arañas <- arañas[, !colnames(arañas) %in% c("Código_localidad", "Año")]
arañas_resumido <- arañas %>%
  group_by(localidad_año, Taxon) %>%
  summarise(N_exx. = sum(N_exx., na.rm = TRUE), .groups = "drop")   ### todo esto pa preparar la matriz

matriz_NMDS <- tidyr::pivot_wider(
  data = arañas_resumido,
  id_cols = localidad_año,
  names_from = Taxon,
  values_from = N_exx.,
  values_fill = list(N_exx. = 0))   ### matriz pa hacer NMDS
NMDSPresAu <- matriz_NMDS %>%
  mutate(across(-localidad_año, ~ ifelse(. > 0, 1, 0)))
NMDSPresAu <- NMDSPresAu[, -1]

# jaccard para presencia/ausencia
matriz_distancia <- vegdist(NMDSPresAu, method = "jaccard", na.rm = TRUE)
nmds_result <- metaMDS(matriz_distancia, k = 2, trymax = 100)

plot(nmds_result, type = "t", main = "NMDS de Jaccard")
orditorp(nmds_result, display = "sites", cex = 0.8)  # Localidades
orditorp(nmds_result, display = "species", col = "red", cex = 0.8)  # Especies

nmds_sites <- as.data.frame(scores(nmds_result, display = "sites"))  # extraer coord ¿del gráfico? de las localidades
nmds_sites$localidad_año <- NMDSPresAu$localidad_año   # TUVE QUE VOLVER A HACER NMDSPresAu. añadir localidades como una columna

ggplot(nmds_sites, aes(x = NMDS1, y = NMDS2, label = localidad_año)) +
  geom_point(color = "blue", size = 3) +
  geom_text(vjust = -0.5, hjust = 0.5, size = 3) +
  theme_minimal() +
  labs(title = "NMDS (Bray-Curtis)", x = "Dimensión 1", y = "Dimensión 2")

############ hacer polígonos NMDS
nmds_sites$localidad <- sub("_.*", "", nmds_sites$localidad_año)  # Extraer la localidad
nmds_sites$año <- sub(".*_", "", nmds_sites$localidad_año)  # Extraer el año

hull <- nmds_sites %>%
  group_by(año) %>%
  slice(chull(NMDS1, NMDS2))

library(showtext)
font_add_google("Lexend", "lexend")  # Cargar fuente Lexend
showtext_auto() 
grafico <- ggplot(data = nmds_sites, aes(x = NMDS1, y = NMDS2)) +
  geom_point(aes(color = localidad), size = 3, show.legend = FALSE) +  # Puntos coloreados por localidad
  geom_polygon(data = hull, aes(group = año, fill = año), alpha = 0.3) +  # Polígonos con colores
  labs(title = "NMDS por Año y Localidad",
       x = "NMDS1", y = "NMDS2", color = "Localidad", fill = "Localidad") +
  geom_text(aes(label = localidad), vjust = -0.5, hjust = 0.5, size = 3) +  # Etiquetas con el nombre de la localidad
  theme_minimal() + 
  theme(    text = element_text(family = "lexend", size = 12),  # Aplicar fuente Lexend en todo el gráfico
    plot.title = element_text(hjust = 0.5, size = 18, family = "lexend"),  # Centrar título
    axis.title = element_text(size = 15, family = "lexend"),  # Títulos de los ejes en Lexend
    axis.text = element_text(size = 12, family = "lexend"),  # Texto de los ejes en Lexend
    legend.title = element_text(size = 15, family = "lexend"),  # Título de la leyenda
    legend.text = element_text(size = 12, family = "lexend")  ) +
  scale_color_manual(values = c("1995" = "#AEC6CF", "2024" = "#F08080")) +  # Cambiar colores de los años
  scale_fill_manual(values = c("1995" = "#AEC6CF", "2024" = "#F08080"))
print(grafico)


##############################  BETA
library(BAT)
setwd("F:/TFM/desde enero/Taxonomica")

NMDSPresAu <- as.data.frame(NMDSPresAu) 
rownames(NMDSPresAu) <- NMDSPresAu[[1]]  # Asignar la primera columna como rownames
NMDSPresAu <- NMDSPresAu[, -1] 

Tbeta=beta( NMDSPresAu, func="jaccard", abund = FALSE)
TBtotal=as.matrix(Tbeta$Btotal)
  TBtotal_df <- as.data.frame(TBtotal)
  write.xlsx(TBtotal_df, "TBtotal.xlsx")
TBrepl=as.matrix(Tbeta$Brepl)
  TBrepl_df <- as.data.frame(TBrepl)
  write.xlsx(TBrepl_df, "TBrepl.xlsx")
TBrich=as.matrix(Tbeta$Brich)
  TBrich_df <- as.data.frame(TBrich)
  write.xlsx(TBrich_df, "TBrich.xlsx")




###########################  CURVAS #############################

arañas <- arañas[, !colnames(arañas) %in% c("Cod_DZUL", "Año", "Ordenar","X","Y","Camp","Localidad","Código_95","Fecha","Muestreo","Trampa","Código_muestra","Orden","Familia","Género","Especie","Determinador","Observaciones")]
arañas <- arañas %>%  rename(Año = Año2)
arañas_95 <- arañas %>% filter(Año == 1995)
arañas_24 <- arañas %>% filter(Año == 2024)
library(tidyr)
matriz_95 <- arañas_95 %>% 
  pivot_wider(
    names_from = Taxon, 
    values_from = N_exx., values_fn = sum, values_fill = 0 )
matriz_24 <- arañas_24 %>% 
  pivot_wider(
    names_from = Taxon, values_from = N_exx.,  values_fn = sum, values_fill = 0 )

matriz_95 <- matriz_95[, -1]
library(vegan)
accum_95 <- specaccum(matriz_95, method = "random", permutations = 1000)
specpool_95 <- specpool(matriz_95)
completitud_95 <- specpool_95$Species / specpool_95$chao * 100
accum_95_df <- data.frame(Sites = accum_95$sites, Richness = accum_95$richness, SD = accum_95$sd)
matriz_24 <- matriz_24[, -1]
accum_24 <- specaccum(matriz_24, method = "random", permutations = 1000)
specpool_24 <- specpool(matriz_24)
completitud_24 <- specpool_24$Species / specpool_24$chao * 100
accum_24_df <- data.frame(Sites = accum_24$sites, Richness = accum_24$richness, SD = accum_24$sd)

accum_95_df$Year <- "1995"
accum_24_df$Year <- "2024"
accum_df <- rbind(accum_95_df, accum_24_df)

# pendientes curvas
library(dplyr)
pendientes <- accum_df %>%group_by(Year) %>%
  do({    model <- lm(Richness ~ Sites, data = .)
    pendiente <- coef(model)[2]  # Obtener la pendiente
    data.frame(pendiente) })

font_add_google("Lexend", "lexend")  # Carga la fuente desde Google Fonts
showtext_auto()
accum_df$Sites <- as.factor(accum_df$Sites)  # Convertir 'Sites' a un factor (si es una variable categórica)
# Crear el gráfico
ggplot(accum_df, aes(x = Sites, y = Richness, color = Year, group = Year)) + 
  geom_point() + 
  geom_line(size = 1.5) +  # Usa líneas continuas
  scale_color_manual(values = c("1995" = "#AEC6CF", "2024" = "#F08080")) + 
  # Anotaciones de riqueza estimada
  annotate("text", x = 8, y = 70, label = paste("Chao 1995 =", round(specpool_95$chao)), col = "black", size = 4, family ="lexend") +
  annotate("text", x = 10, y = 40, label = paste("Chao 2024 =", round(specpool_24$chao)), col = "black", size = 4, family ="lexend") +
  labs(title = "Curvas de acumulación de especies por año",
       x = "Número de localidades",
       y = "Riqueza acumulada",
       color = "Año") +  # Título de la leyenda
  theme_minimal() + 
  theme(    text = element_text(family = "lexend", size = 10),
    plot.title = element_text(hjust = 0.5, size = 20, family = "lexend"),  # Centrar título y aumentar tamaño
    axis.title = element_text(size = 15, family = "lexend"),                # Tamaño de títulos de ejes
    axis.text = element_text(size = 10, family = "lexend"),                  # Tamaño del texto de los ejes
    legend.title = element_text(size = 15, family = "lexend"),               # Aumentar tamaño del título de la leyenda
    legend.text = element_text(size = 10, family = "lexend")) +
  scale_x_discrete(breaks = 1:12) +  # Limitar eje X a valores entre 1 y 12
  geom_smooth(method = "lm", aes(group = Year), se = FALSE, linetype = "dashed", color = "grey", size = 1) + 
  geom_text(data = pendientes, aes(x = 6, y = ifelse(Year == "1995", 58, 32), 
                                   label = paste("m = ", round(pendiente, 2))), 
            size = 3, color = "black", family = "lexend", inherit.aes = FALSE)


setwd('F:/TFM/desde enero/Taxonomica')
ggsave(curvas, file="curvas.png", width=20, height=20, units="cm")



###########################  VENN #############################
library(VennDiagram)

especies_95 <- arañas %>%
  filter(Año == 1995) %>%
  group_by(Código_localidad, Taxon) %>%  # Extraer solo los nombres de las especies
  unique()                 # nun hagas la pijada de 'pull' porque te hacen falta las localidades para el bucle de luego
especies_24 <- arañas %>%
  filter(Año == 2024) %>%
  group_by(Código_localidad, Taxon) %>%  
  unique()

venn.plot <- venn.diagram(  x = list("1995" = especies_95,
    "2024" = especies_24  ),
  filename = NULL,  # Para que no guarde en un archivo
  fill = c("blue", "red"),  alpha = 0.5,  cex = 2,  cat.cex = 1.5,  main = "Diagrama de Venn: Especies por año")
grid::grid.draw(venn.plot)
venn_list <- list()

# por localidad
arañas_resumido <- arañas %>%
  group_by(Código_localidad, Año, Taxon) %>%
  summarise(abundancia_total = sum(N_exx., na.rm = TRUE), .groups = 'drop')

venn_list <- list()
arañas$Código_localidad <- as.factor(arañas$Código_localidad)

library(ggVennDiagram)
for (loc in unique(arañas$Código_localidad)) {
  especies_95_loc <- especies_95 %>%
    filter(Código_localidad == loc) %>%
    pull(Taxon)
  especies_24_loc <- especies_24 %>%
    filter(Código_localidad == loc) %>%
    pull(Taxon)
  datos_venn <- list(
    A = especies_95_loc, 
    B = especies_24_loc
  )
    p <- ggVennDiagram(datos_venn, label_alpha = 0) +  scale_fill_gradient(low = "lightblue", high = "red") + theme_void() + theme(legend.position = "none")  # Sin leyenda
    venn_list[[loc]] <- p }
# Mostrar cada diagrama de Venn almacenado en la lista
for (loc in names(venn_list)) {
  print(venn_list[[loc]])}

library(patchwork)
multi_venn <- wrap_plots(venn_list, ncol = 4)
print(multi_venn)




