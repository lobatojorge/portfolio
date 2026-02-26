setwd("F:/TFM/desde enero/Funcional")
library(xlsx)
traits = read.xlsx2("matrizTraits.xlsx", sheetIndex = 1, row.names = 1) #cargar la matriz de traits
str(traits) #verificar


#####  PONDERAR TRAITS

## ponderamos traits con Random Forest no supervisado (sin variable explicita: grupo)

library(randomForest)
traits[, 1:3] <- lapply(traits[, 1:3], as.numeric)   # para que el modelo los reconozca
traits[, 4:19] <- lapply(traits[, 4:19], factor)     # pa lo mismo
traits[, c(1, 2, 3)] <- scale(traits[, c(1, 2, 3)])  # estandarizar traits numéricos
rf_model <- randomForest(x = traits[, 1:19], importance = TRUE)
importance(rf_model)   # ver importancia de los traits
varImpPlot(rf_model)   # con esto se qué traits son más importantes

# extraer importancia de los traits
importancia_traits <- importance(rf_model)[, 1]  # Extraer MeanDecreaseAccuracy
importancia_traits <- importancia_traits / sum(importancia_traits)  # Normalizar

library(cluster)
library(dendextend)
library(factoextra)
matDistancia <- daisy(traits, metric = "gower", weights = importancia_traits)
hc <- hclust(as.dist(matDistancia), method = "ward.D2")
dend <- as.dendrogram(hc)  # hacemos cluster el dendrograma
groups <- cutree(hc, k = 3)
dend <- color_branches(dend, k = 3)
fviz_dend(dend, k = 3, cex = 0.3, k_colors = rainbow(3),rect = TRUE, horiz = TRUE)

library(ape)
arbol_phylo <- as.phylo(hclust(as.dist(matDistancia), method="average"))
write.nexus(arbol_phylo, file = "arbolbueno.nexus")

#ponderando 1 a todo
#dist_matrix <- dist(traits, method = "euclidean")
#hc <- hclust(dist_matrix, method = "complete")
#dend <- as.dendrogram(hc)
#groups <- cutree(hc, k = 3)
#dend <- color_branches(dend, k = 3)
#fviz_dend(dend, k = 3, cex = 0.3, k_colors = rainbow(3),rect = TRUE) 


### quitar correlacionados
library(corrplot)
traits <- data.frame(lapply(traits, as.numeric))
#traits <- traits[, -1]
cor_matrix <- cor(traits, method = "pearson")  # O usa "spearman" si los datos no son normales
  write_xlsx(as.data.frame(cor_matrix), "correlation_matrix.xlsx")
corrplot(cor_matrix, method = "color", type = "upper", tl.cex = 0.8)





##############   CALCULAR DIVERSIDAD FUNCIONAL    #############
library(ape)
Ftree <- read.nexus("arbolbueno.nexus")
Ftree$tip.label<-gsub("'", "", Ftree$tip.label) #para eliminar las  comillas (') del nombre de las especies
library(readxl)
setwd("F:/TFM")
arañas = read_excel("arañas.xlsx")    #   leer el dataset crudo y filtrar hasta conseguir una matriz de abundancias (arañas_filtradas_table)
arañas <- arañas[, !colnames(arañas) %in% c("Cod_DZUL", "Año", "Ordenar","X","Y","Camp","Localidad","Código_95","Fecha","Muestreo","Trampa","Código_muestra","Orden","Familia","Género","Especie","Determinador","Observaciones")]
arañas$N_exx. <- as.numeric(arañas$N_exx.)
arañas=arañas[complete.cases(arañas), ]

arañas_filtradas <- arañas %>%
  dplyr::group_by(Código_localidad, Taxon, Año2) %>%
  dplyr::summarise(Abundance = sum(N_exx.))
arañas_filtradas=arañas_filtradas[complete.cases(arañas_filtradas), ]
arañas_filtradas$LocAño<-paste(arañas_filtradas$Código_localidad, arañas_filtradas$Año2, sep="_")
samp<-tidyr::pivot_wider(arañas_filtradas, LocAño, names_from = "Taxon", values_from = "Abundance",
                         values_fill = 0)

samp=samp %>% remove_rownames %>% tibble::column_to_rownames(var="LocAño")  # para que la primera columna sea el nombre de las filas
samp=as.data.frame(samp)  # dar formato dataframe
samp[,][samp[,]>1] = 1   #  para convertir a presencia-ausencia
samp[] <- lapply(samp, as.numeric)   #  aplicar formato numérico a todas las columnas
str(samp) #verificar
setwd("F:/TFM/desde enero/Funcional")
zonass = read_excel("zonas.xlsx")  # ANTES ERA prueba_merge_fd para posteriores agrupamientos




###########  PHILOTENTIC DIVERSITY  (val pa funcional tranki)
library(picante)
SES_fPD<-ses.pd(samp, Ftree, null.model = "taxa.labels",
               runs = 999, iterations = 1000, include.root=T) # calcular PD
#write.xlsx(standES, "standES.xlsx")

SES_fPD_zonass<-cbind(SES_fPD,zonass)   #  unir para agrupar
SES_fPD_zonass$año=as.factor(SES_fPD_zonass$año) # dar formato factor a año
SES_fPD_zonass$zona = factor(SES_fPD_zonass$zona, levels=unique(c("W","E")))  #Order in plot
plot_fd<-ggplot(SES_fPD_zonass, aes(x=año, y=pd.obs.z, fill=zona)) +
  geom_boxplot(width=0.5,lwd=0.3,outlier.size = 0.7)+
  theme_bw() 
plot_fd         
ggsave("pd.png", plot=plot_fd)

library(car)
modelo_pd<-glm(pd.obs.z~año*zona, data=SES_fPD_zonass, family=gaussian, na.action=na.omit) #glm de distribución gaussiana (PD frente a año y zona)
summary(modelo_pd) #tabla de coeficientes
Anova(modelo_pd) #tabla Anova
library(DHARMa)
simulationOutput <- simulateResiduals(fittedModel = modelo_pd) #para verificar si se ajusta el modelo
plot(simulationOutput) #visualizar el ajuste
library(emmeans)
marginal=emmeans(modelo_pd,  ~año*zona)   # para hacer comparaciones múltiples
pairs(marginal, adjust="tukey")   #  visualizar comparaciones múltiples

#####  MPD
  
distm<-cophenetic.phylo(Ftree) #computes the pairwise distances between the pairs of tips from a phylogenetic tree using its branch lengths
SES_MPD<-ses.mpd(samp, distm, null.model = "taxa.labels",
                 runs = 999, iterations = 1000)
SES_MPD_zonass<-cbind(SES_MPD,zonass)
SES_MPD_zonass$año=as.factor(SES_MPD_zonass$año)
SES_MPD_zonass$zona = factor(SES_MPD_zonass$zona, levels=unique(c("W","E")))  #Order in plot
plot_fmpd<-ggplot(SES_MPD_zonass, aes(x=año, y=mpd.obs.z, fill=zona)) +
  geom_boxplot(width=0.5,lwd=0.3,outlier.size = 0.7)+
  theme_bw() 
plot_fmpd
ggsave("MPD.png", plot=plot_fmpd)

modelo_mpd<-glm(mpd.obs.z~año*zona, data=SES_MPD_zonass, family=gaussian, na.action=na.omit)
summary(modelo_mpd)
Anova(modelo_mpd)
simulationOutput <- simulateResiduals(fittedModel = modelo_mpd)
plot(simulationOutput)
marginal=emmeans(modelo_mpd,  ~año*zona)
pairs(marginal, adjust="tukey")


######    MNTD
  
SES_MNTD<-ses.mntd(samp, distm, null.model = "taxa.labels",
                   runs = 999, iterations = 1000)
SES_MNTD_zonass<-cbind(SES_MNTD,zonass)
SES_MNTD_zonass$año=as.factor(SES_MNTD_zonass$año)
SES_MNTD_zonass$zona = factor(SES_MNTD_zonass$zona, levels=unique(c("W","E")))  #Order in plot
plot_fmntd<-ggplot(SES_MNTD_zonass, aes(x=año, y=mntd.obs.z, fill=zona)) +
  geom_boxplot(width=0.5,lwd=0.3,outlier.size = 0.7)+
  theme_bw() 
plot_fmntd
ggsave("MNTD.png", plot=plot_fmntd)

modelo_mntd<-glm(mntd.obs.z~año*zona, data=SES_MNTD_zonass, family=gaussian, na.action=na.omit)
summary(modelo_mntd)
Anova(modelo_mntd)
simulationOutput <- simulateResiduals(fittedModel = modelo_mntd)
plot(simulationOutput)
marginal=emmeans(modelo_mntd,  ~año*zona)
pairs(marginal, adjust="tukey")


############# REPRESENTAR PARÁMETROS XUNTOS
library(ggplot2)
library(dplyr)
library(showtext)
font_add_google("Lexend", "lexend")
showtext_auto()

fpd_data <- data.frame(año = SES_fPD_zonass$año, valor = SES_fPD_zonass$pd.obs.z, tipo = "fPD", zona = SES_fPD_zonass$zona)
fmpd_data <- data.frame(año = SES_MPD_zonass$año, valor = SES_MPD_zonass$mpd.obs.z, tipo = "fMPD", zona = SES_MPD_zonass$zona)
fmntd_data <- data.frame(año = SES_MNTD_zonass$año, valor = SES_MNTD_zonass$mntd.obs.z, tipo = "fMNTD", zona = SES_MNTD_zonass$zona)
combined_data <- rbind(fpd_data, fmpd_data, fmntd_data)
combined_data$tipo <- factor(combined_data$tipo, levels = c("fPD", "fMPD", "fMNTD"))
ggplot(combined_data, aes(x = zona, y = valor, fill = año)) +
  geom_boxplot(position = position_dodge(width = 0.75)) +
  scale_fill_manual(values = c("1995" = "#AEC6CF", "2024" = "#F08080")) +
  facet_wrap(~ tipo) +
  theme_minimal(base_size = 14, base_family = "lexend") +
  labs(x = "Zona", y = "SES", fill = "Año") +
  theme(
    legend.position = "top",
    axis.title = element_text(size = 16),
    axis.text = element_text(size = 14),
    strip.text = element_text(size = 16),
    panel.border = element_rect(color = "black", fill = NA, linewidth = 0.5)  )
setwd("F:/TFM/desde enero/Funcional")
ggsave("zona_año.png", width = 8, height = 6)




##################  BETA FUNCIONAL
library(vegan)
fbeta=beta(  samp,  Ftree,  func = "jaccard",  abund = F)
fBtotal=as.matrix(fbeta$Btotal)
  fBtotal_df <- as.data.frame(fBtotal)
  write.xlsx(fBtotal_df, "fBtotal.xlsx")
fBrepl=as.matrix(fbeta$Brepl)
  fBrepl_df <- as.data.frame(fBrepl)
  write.xlsx(fBrepl_df, "fBrepl.xlsx")
fBrich=as.matrix(fbeta$Brich)
  fBrich_df <- as.data.frame(fBrich)
  write.xlsx(fBrich_df, "fBrich.xlsx")

spcontribution=contribution(samp, Ftree, abund=F)

obtener_top3 <- function(fila) {
  orden <- order(fila, decreasing = TRUE, na.last = NA)
  top3_valores <- fila[orden][1:3]
  top3_especies <- names(fila)[orden][1:3]
  return(c(top3_especies, top3_valores))}

top3_resultados <- t(apply(spcontribution, 1, obtener_top3))
top3_resultados=as.data.frame(top3_resultados)
top3_resultados <- top3_resultados[, c(1, 4, 2, 5, 3, 6)]
  top3_df <- as.data.frame(top3_resultados)
  write.xlsx(top3_df, "top3.xlsx")

disp_result=dispersion(  samp,  Ftree,  distm,  func = "originality",  abund = F,  relative = TRUE)
  disp_df <- as.data.frame(disp_result)
  write.xlsx(disp_df, "disp.xlsx")
evenness_result=evenness(  samp,  Ftree,  distm,  method = "expected",  func = "camargo",  abund = F)
  evenness_df <- as.data.frame(evenness_result)
  write.xlsx(evenness_df, "evenness.xlsx")

evenness_contrib=evenness.contribution(  samp,  Ftree,  distm,  method = "expected",  func = "camargo",  abund = F)
  evenn_con_df <- as.data.frame(evenness_contrib)
  write.xlsx(evenn_con_df, "even_con.xlsx")
originality_result=BAT::originality(samp, Ftree, distm, abund = FALSE, relative = FALSE)
  originality_df <- as.data.frame(originality_result)
  write.xlsx(originality_df, "originality.xlsx")
