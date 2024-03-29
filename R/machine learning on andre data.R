rm(list = ls())
graphics.off()

pacman::p_load(caret,GGally,magrittr,pacman,parallel,randomForest,rattle,rio,tictoc,tidyverse)

setwd("C:/Users/iande/Documentos/proyectos/ML on Parnaiba data/")
data = readxl::read_excel("sensibilidades-Amazon-Compilado_IdR.xlsx", sheet = "newdata") %>%
  print()

# select data ########################################################################
data %<>%
  filter(River == "Solim�es" | River == "Negro" | River == "Amazon" | River == "Madeira")

# K nearest neighbour (KNN) on training data ##########################################
set.seed(123)

#random subsample
#data %>% sample_n(250)

train = data %>% sample_frac(.75)
test = anti_join(data, train)

statctrl = trainControl(method = "repeatedcv", number = 10, repeats = 3)

fit.knn = train(Provenance ~ osl + irsl + tl110 + tl325 + irsl.osl,
                data = train, method = "knn", trControl = statctrl, tuneLength = 20,
                na.action = "na.omit")

tic("KNN")
fit.knn
toc()

osl.p = fit.knn %>% 
  predict(newdata = train)

table(actualclass = train$Provenance, predictedclass = osl.p) %>% 
  confusionMatrix() %>% 
  print()

#KNN on test data
osl.p = predict(fit.knn, newdata = test)
table(actualclass = test$Provenance, predictedclass = osl.p) %>% 
  confusionMatrix() %>% 
  print()

#Decision tree on training data ######################################################
#set.seed(10000)
train = data %>% sample_frac(.66)
test = anti_join(data, train)

train %>%
  gather(var, val, irsl:irsl.osl) %>%
  ggplot(aes(val,group = Provenance, fill = Provenance)) +
  geom_density(alpha = 0.4) +
  facet_wrap(~var)+
  theme(legend.position = "bottom")

#tic("Decision tree") # train data
fit.dt = train(River ~ osl + irsl + irsl.osl,
               data = train, method = "rpart", trControl = trainControl(method = "cv"),
               na.action = "na.omit")
#toc()
fit.dt

fit.dt$finalModel
fit.dt$finalModel %>% 
  fancyRpartPlot(main = "Predicting River", sub = "Training data")

osl.p = fit.dt %>% predict(newdata = train)
table(actualclass = train$River, predictedclass = osl.p) %>% 
  confusionMatrix() %>% 
  print()

#Decision tree on test data
osl.p = fit.dt %>% predict(newdata = test)
table(actualclass = test$River, predictedclass = osl.p) %>% 
  confusionMatrix() %>% 
  print()

# Random forest of decision trees on training data #####################################
#set.seed(123)
train = data %>% sample_frac(.66)
test = anti_join(data, train)

control = trainControl(method = "repeatedcv", number = 10, repeats = 3, search = "random",
                       allowParallel = T)

#tic("Random forest")
fit.rf = train(Group ~ osl + fast + med + slow + irsl + tl110 + tl110pos + tl325pos,
               data = train, method = "rf", trControl = control,
               metric = "Accuracy", tuneLength = 15, ntree = 300,
               na.action = "na.omit")
#toc()
fit.rf
fit.rf %>% plot()
fit.rf$finalModel
fit.rf$finalModel %>% plot()

osl.p = predict(fit.rf, newdata = train)
table(actualclass = train$Group, predictedclass = osl.p) %>% 
  confusionMatrix() %>% 
  print()

#Random forest on test data
osl.p = predict(fit.rf, newdata = test)
table(actualclass = test$Group, predictedclass = osl.p) %>% 
  confusionMatrix() %>% 
  print()

# Summary of results ####
test %>% pull(osl.t) %>% summary()

# Hierarchical clustering ###############################################################
library(factoextra); library(cluster); library(magrittr)
hc = data %>%
  select(osl:tl110, Unit) %>% 
  dist %>% hclust

hc %>% plot(labels = data$Unit, hang = -1, cex = 0.6)

#optimal number of clusters
data %>% 
  fviz_nbclust(FUN = hcut, method = "wss")+
  geom_vline(xintercept = 3, color = "red", linetype = "dotted")

data %>% 
  fviz_nbclust(FUN = hcut, method = "silhouette")

data %>% 
  na.omit(data) %>%
  select(-Unit, -Group, -sample, -osl.t, -...1) %>%
  clusGap(FUN = hcut, nstart = 50, K.max = 10, B = 100) %>%
  fviz_gap_stat()

hc %>% rect.hclust(k = 3, border = 2:5)

y.hc = cutree(hc, 3)
fviz_cluster(list(data = data %>% 
                    select(osl, fast, med, slow, irsl, tl110),
                  cluster = y.hc))

# K-means clustering #####
data.s = data %>% 
  select(-...1, -sample, -Group, -Unit, -osl.t) %>%
  scale() %>% 
  print()

km = data.s %>% kmeans(3) %>% print()
data.s %>% clusplot(km$cluster, color = T, lines = 0, labels = 2)

#add clusters to the dataframe
data %<>%
  mutate(cluster = km$cluster) %>% 
  select(-...1) %>%
  arrange(cluster) %>% 
  print()
