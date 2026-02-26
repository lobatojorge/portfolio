setwd("F:/TFM")
library(readxl)
#######  datos de comunidad
library(dplyr)
arañas = read_excel("arañas.xlsx") 
arañas <- arañas %>%
  dplyr::select(Código_localidad, Año2, Taxon, N_exx., Muestreo)%>%
  dplyr::rename(Año = Año2)
arañas$N_exx. <- as.numeric(arañas$N_exx.)
arañas=arañas[complete.cases(arañas), ]

matrizab <- arañas %>%
  dplyr::group_by(Código_localidad, Taxon, Año) %>%
  dplyr::summarise(Abundance = sum(N_exx.))
matrizab=matrizab[complete.cases(matrizab), ]
matrizab$Taxon <- gsub("\\(|\\)", "", matrizab$Taxon)  # quitar paréntesis de Zelotes n. sp. (gr. pallidus)
matrizab$Taxon <- gsub(" ", "_", matrizab$Taxon)   # sustituir espacio por barra baja y que coincida con el nombre de las seq del árbol

matrizab$LocAño<-paste(matrizab$Código_localidad, matrizab$Año, sep="_")
matrizab_table<-tidyr::pivot_wider(matrizab, LocAño, names_from = "Taxon", values_from = "Abundance",
                              values_fill = 0)
library(tibble)
samp=matrizab_table #a partir de ahora, la llamaremos samp
samp=samp %>% remove_rownames %>% tibble::column_to_rownames(var="LocAño") #para que la primera columna sea el nombre de las filas
samp=as.data.frame(samp) #dar formato dataframe
samp[,][samp[,]>1] = 1 #para convertir a presencia-ausencia
samp[] <- lapply(samp, as.numeric) #aplicar formato numérico a todas las columnas
str(samp) #verificar
setwd("F:/TFM/desde enero/Funcional")
zonas <- read_excel("zonas.xlsx") # para posteriores agrupamientos


########datos filogenéticos
library(ape)
library(phytools)
setwd("F:/TFM/desde enero/Filogenetica")
tree<-ape::read.tree("RAxML_bestTree.result")
species_present <- colnames(samp)[colSums(samp) > 0]
ut<-force.ultrametric(tree, method=c("nnls","extend")) #Force ultrametric tree
pt <- keep.tip(ut, species_present) #Tree prunning
plot(pt)
write.nexus(pt, file = "arbol_podado.nex")


#PD
library(picante)
SES_PD<-ses.pd(samp, pt, null.model = "taxa.labels",
               runs = 999, iterations = 1000, include.root=T) #calcular PD
SES_PD_zonas<-cbind(SES_PD,zonas) #unir para agrupar
SES_PD_zonas$año=as.factor(SES_PD_zonas$año) #dar formato factor a año
SES_PD_zonas$zona = factor(SES_PD_zonas$zona, levels=unique(c("W","E")))
plot_fd<-ggplot(SES_PD_zonas, aes(x=año, y=pd.obs.z, fill=zona)) +
  geom_boxplot(width=0.5,lwd=0.3,outlier.size = 0.7)+
  theme_bw() 
plot_fd
ggsave("PD.png", plot=plot_fd)

modelo_pd<-glm(pd.obs.z~año*zona, data=SES_PD_zonas, family=gaussian, na.action=na.omit) #glm de distribución gaussiana (PD frente a año y zona)
summary(modelo_pd) #tabla de coeficientes
Anova(modelo_pd) #tabla Anova
simulationOutput <- simulateResiduals(fittedModel = modelo_pd) #para verificar si se ajusta el modelo
plot(simulationOutput) #visualizar el ajuste
marginal=emmeans(modelo_pd,  ~año*zona) #para hacer comparaciones múltiples
pairs(marginal, adjust="tukey") #visualizar comparaciones múltiples

#MPD
distm<-cophenetic.phylo(pt) #computes the pairwise distances between the pairs of tips from a phylogenetic tree using its branch lengths
SES_MPD<-ses.mpd(samp, distm, null.model = "taxa.labels",
                 runs = 999, iterations = 1000)
SES_MPD_zonas<-cbind(SES_MPD,zonas)
SES_MPD_zonas$año=as.factor(SES_MPD_zonas$año)
SES_MPD_zonas$zona = factor(SES_MPD_zonas$zona, levels=unique(c("W","E")))
plot_fmpd<-ggplot(SES_MPD_zonas, aes(x=año, y=mpd.obs.z, fill=zona)) +
  geom_boxplot(width=0.5,lwd=0.3,outlier.size = 0.7)+
  theme_bw() 
plot_fmpd
ggsave("Plot_PD_MPD.png", plot=plot_fmpd)

modelo_mpd<-glm(mpd.obs.z~año*zona, data=SES_MPD_zonas, family=gaussian, na.action=na.omit)
summary(modelo_mpd)
Anova(modelo_mpd)
simulationOutput <- simulateResiduals(fittedModel = modelo_mpd)
plot(simulationOutput)
marginal=emmeans(modelo_mpd,  ~año*zona)
pairs(marginal, adjust="tukey")


#MNTD
SES_MNTD<-ses.mntd(samp, distm, null.model = "taxa.labels",
                   runs = 999, iterations = 1000)
SES_MNTD_zonas<-cbind(SES_MNTD,zonas)
SES_MNTD_zonas$año=as.factor(SES_MNTD_zonas$año)
SES_MNTD_zonas$zona = factor(SES_MNTD_zonas$zona, levels=unique(c("W","E")))
plot_fmntd<-ggplot(SES_MNTD_zonas, aes(x=año, y=mntd.obs.z, fill=zona)) +
  geom_boxplot(width=0.5,lwd=0.3,outlier.size = 0.7)+
  theme_bw() 
plot_fmntd
ggsave("Plot_PD_MNTD.png", plot=plot_fmntd)

modelo_mntd<-glm(mntd.obs.z~año*zona, data=SES_MNTD_zonas, family=gaussian, na.action=na.omit)
summary(modelo_mntd)
Anova(modelo_mntd)
simulationOutput <- simulateResiduals(fittedModel = modelo_mntd)
plot(simulationOutput)
marginal=emmeans(modelo_mntd,  ~año*zona)
pairs(marginal, adjust="tukey")

#########################  representar juntos PD, MPD y MNTD
library(patchwork)
library(dplyr)
library(ggplot2)
library(showtext)
font_add_google("Lexend", "lexend")
showtext_auto()

pd_data <- data.frame(año = SES_PD_zonas$año, valor = SES_PD_zonas$pd.obs.z, tipo = "PD", zona = SES_PD_zonas$zona)
mpd_data <- data.frame(año = SES_MPD_zonas$año, valor = SES_MPD_zonas$mpd.obs.z, tipo = "MPD", zona = SES_MPD_zonas$zona)
mntd_data <- data.frame(año = SES_MNTD_zonas$año, valor = SES_MNTD_zonas$mntd.obs.z, tipo = "MNTD", zona = SES_MNTD_zonas$zona)
combined_data <- rbind(pd_data, mpd_data, mntd_data)

ggplot(combined_data, aes(x = zona, y = valor, fill = factor(año))) +
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
setwd("F:/TFM/desde enero/Filogenetica")
ggsave("zona_año.png", width = 8, height = 6)



###phylo beta div
setwd("G:/TFM/desde enero/Filogenetica")
fbeta=beta(  samp,  pt,  func = "jaccard",  abund = F)

fBtotal=as.matrix(fbeta$Btotal)
  fBtotal_df <- as.data.frame(fBtotal)
  write.xlsx(fBtotal_df, "fBtotal.xlsx")
fBrepl=as.matrix(fbeta$Brepl)
  fBrepl_df <- as.data.frame(fBrepl)
  write.xlsx(fBrepl_df, "fBrepl.xlsx")
fBrich=as.matrix(fbeta$Brich)
  fBrich_df <- as.data.frame(fBrich)
  write.xlsx(fBrich_df, "fBrich.xlsx")
  
  

################# ANALISIS BETA TEMPORAL ############
  
setwd("F:/TFM/desde enero")
library(readxl)
BETA = read_excel("BETA TEMPORAL.xlsx", sheet = 2)

apply(BETA[ , -1], 2, sd)  #desviación estándar

### diagrama de puntos
orden_oeste_este <- c("ESC","PME","CTE","CNE","BCR","CBL","MSA","MIN","RVE","ANG","POR","FTZ")
library(tidyverse)
BETA <- BETA %>%
  select(localidad, T_total, Filo_total, Fun_total) %>%
  pivot_longer(cols = -localidad,
               names_to = "faceta",
               values_to = "beta_total") %>%
  mutate(localidad = factor(localidad, levels = orden_oeste_este)) %>%
  mutate(faceta = case_when(
    faceta == "T_total" ~ "Taxonómica",
    faceta == "Filo_total" ~ "Filogenética",
    faceta == "Fun_total" ~ "Funcional"  ))
BETA$faceta_comb <- factor(BETA$faceta, 
                                levels = c("Taxonómica", "Filogenética", "Funcional"),
                                labels = c("Taxonómica", "Filogenética", "Funcional"))
library(showtext)
font_add_google("Lexend", family = "Lexend")  # Cargar la fuente Lexend desde Google Fonts
showtext_auto()
ggplot(BETA, aes(x = localidad, y = beta_total, shape = faceta_comb, color = faceta_comb, group = faceta_comb)) +
  geom_point(size = 3, alpha = 0.9) +
  geom_line(linetype = "dashed", linewidth = 0.8) +
  scale_shape_manual(values = c("Taxonómica" = 16,   # círculo
                                "Filogenética" = 15, # cuadrado
                                "Funcional" = 17)) + # triángulo
  scale_color_manual(values = c("Taxonómica" = "violet",     # azul
                                "Filogenética" = "#2ca02c",   # verde
                                "Funcional" = "purple")) +   # rojo
  labs(title = "Diversidad Beta Total por Faceta y Localidad",
       x = "Localidad",
       y = "Beta Diversidad Total",
       shape = "Faceta",
       color = "Faceta") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        plot.title = element_text(hjust = 0.5, family = "Lexend"),   # Fuente Lexend en el título
        legend.position = "bottom",  # Colocar leyenda abajo
        legend.box = "horizontal",   # Leyenda en formato horizontal
        legend.key = element_rect(fill = "white", color = "white"),  # Fondo blanco para los íconos de leyenda
        axis.title.x = element_text(margin = margin(t = 15), family = "Lexend"),  # Fuente Lexend en el título del eje X
        axis.title.y = element_text(margin = margin(r = 15), family = "Lexend"),  # Fuente Lexend en el título del eje Y
        axis.text = element_text(family = "Lexend"),  # Fuente Lexend en los textos del eje
        legend.text = element_text(family = "Lexend"), # Fuente Lexend en los textos de la leyenda
        legend.title = element_text(family = "Lexend")) 

### proporción componente
BETA <- BETA %>%
  select(localidad,
         T_total, T_rich, T_repl,
         Filo_total, Filo_rich, Filo_repl,
         Fun_total, Fun_rich, Fun_repl)
