#Import libraries.
library(caret) #v. 6.0.84
library(MLmetrics) #v. 1.1.1
library(data.table) #v. 1.14.0
library(Boruta) #v. 8.0.0
library(cvAUC) #v. 1.1.0
library(pROC) #v. 1.14.0
library(doParallel) #v. 1.0.17

#Set 12 cores for parallel computing.
cl <- makeCluster(12)
registerDoParallel(cl)

#Define ith iteration.
i = 1

#Define working directory. Working directory must have the following sub-directories: "metrics", "models", "Train" and "Test".
path = "your_path_to_working_directory"

#Read electronic health records.
Continuous = fread(file = file.path(path, "continuous_data.txt"), header = TRUE, data.table = FALSE)
Categorical = fread(file = file.path(path, "categorical_data.txt"), header = TRUE, data.table = FALSE)

#Variables for patient ID and case/control status must be labeled "IDs" and "CAD", respectively.
#Last 8 variables of the Continuous dataset must be as follow: c("age", "gender", "DMSAA", "DMSEA", "DMSHA", "DMSO", "CAD", "IDs").
#Last 2 variables of the Categorical dataset must be as follow: c("CAD", "IDs").
#Patients in the Continuous and Categorical dataset must be in the same order.
I = Continuous$IDs[sample(which(Continuous$CAD == "CAD"), size = round(length(which(Continuous$CAD == "CAD")) * 0.90))]
I = c(I, sample(Continuous$IDs[which(Continuous$CAD == "nonCAD")], size = length(I)))
Continuous_train = Continuous[which(Continuous$IDs %in% I),]
Categorical_train = Categorical[which(Categorical$IDs %in% I),]
J = Continuous$IDs[which(!Continuous$IDs %in% I)]
I = J[which(J %in% Continuous$IDs[which(Continuous$CAD == "CAD")])]
Continuous = Continuous[-which(Continuous$IDs %in% Continuous_train$IDs),]
I = c(I, sample(Continuous$IDs[which(Continuous$CAD == "nonCAD")], size = length(I)))
Continuous_test = Continuous[which(Continuous$IDs %in% I),]
Categorical_test = Categorical[which(Categorical$IDs %in% I),]

#scale continuous variables.
fit_scale = preProcess(Continuous_train[,c(1:(ncol(Continuous_train)-8))], method = c("center", "scale"))
Continuous_train = predict(fit_scale, Continuous_train)
Continuous_test = predict(fit_scale, Continuous_test)

#Select features in continuous variables.
BB = Boruta(x = Continuous_train[,c(1:(ncol(ukbcon_train)-2))], y = as.factor(Continuous_train$CAD))
W = sort(unique(c(which(colnames(Continuous_train) %in% names(BB$finalDecision[which(BB$finalDecision != "Rejected")])), 
which(colnames(Continuous_train) %in% c("DMSAA", "DMSEA", "DMSHA", "DMSO", "age", "gender")))))
Continuous_train = Continuous_train[,c(W, (ncol(Continuous_train) - 1):ncol(Continuous_train))]
Continuous_test = Continuous_test[,which(colnames(Continuous_test) %in% colnames(Continuous_train))]

#Select features in categorical variables.
BB = Boruta(x = cbind(Categorical_train[,c(1:(ncol(Categorical_train)-1))], Continuous_train[,which(colnames(Continuous_train) %in% 
c("DMSAA", "DMSEA", "DMSHA", "DMSO", "age", "gender"))]), y = as.factor(Continuous_train$CAD))
W = which(colnames(Categorical_train) %in% names(BB$finalDecision[which(BB$finalDecision != "Rejected")]))
Categorical_train = Categorical_train[,c(W, ncol(Categorical_train))]
Categorical_test = Categorical_test[,which(colnames(Categorical_test) %in% colnames(Categorical_train))]

#Generate Train and Test set using continuous and categorical variables.
Train = merge(Categorical_train, Continuous_train, by = "IDs")
Test = merge(Categorical_test, Continuous_test, by = "IDs")
Train = Train[,c(2:ncol(Train), 1)]
Test = Test[,c(2:ncol(Test), 1)]

IDs_train = Train$IDs
IDs_test = Test$IDs

Train$CAD = as.factor(Train$CAD)
Test$CAD = as.factor(Test$CAD)

rm(Continuous_train, Categorical_train, Continuous_test, Categorical_test, Continuous, Categorical)

#Define training scheme.
fitControl_10CV = trainControl(method = "cv", number = 10, savePredictions="final", classProbs=T, summaryFunction=defaultSummary)

#Train random forest model.
fit_model = train(CAD ~ ., data = Train[,-ncol(Train)], method = "rf", trControl=fitControl_10CV)

#Obtain performances in internal 10-fold cross-validation.
YtrainPredProb_stackglm = fit_model$pred[,4]
YtrainPredRaw_stackglm = fit_model$pred[,2]
YtrainTrue_stackglm = fit_model$pred[,3]
ConfMtrain_stackglm = confusionMatrix(data = YtrainPredRaw_stackglm, reference= YtrainTrue_stackglm)
YtrainTrue_stackglm = as.character(YtrainTrue_stackglm)
YtrainTrue_stackglm[which(YtrainTrue_stackglm == "nonCAD")] = "0"
YtrainTrue_stackglm[which(YtrainTrue_stackglm == "CAD")] = "1"
AUCtrain_stackglm = auc(predictor=as.numeric(YtrainPredProb_stackglm), response=as.numeric(YtrainTrue_stackglm))
PRAUCtrain_stackglm = PRAUC(y_pred=as.numeric(YtrainPredProb_stackglm), y_true=as.numeric(YtrainTrue_stackglm))

#Predict CAD risk in Test set and compute performance metrics.
YtestPredProb_stackglm = predict(fit_model, Test, type = "prob")
YtestPredRaw_stackglm = predict(fit_model, Test, type = "raw")
YtestTrue_stackglm = Test$CAD
ConfMtest_stackglm = confusionMatrix(data = YtestPredRaw_stackglm, reference= YtestTrue_stackglm)
YtestTrue_stackglm = as.character(YtestTrue_stackglm)
YtestTrue_stackglm[which(YtestTrue_stackglm == "nonCAD")] = "0"
YtestTrue_stackglm[which(YtestTrue_stackglm == "CAD")] = "1"
AUCtest_stackglm = auc(predictor=as.numeric(YtestPredProb_stackglm[,1]), response=as.numeric(YtestTrue_stackglm))
PRAUCtest_stackglm = PRAUC(y_pred=as.numeric(YtestPredProb_stackglm[,1]), y_true=as.numeric(YtestTrue_stackglm))

#Gather performance metrics for training and testing set.
metrics = data.frame(F1 = c(NA, NA), AUC = c(NA, NA), AUPRC = c(NA, NA), Accuracy = c(NA, NA), Sensitivity = c(NA, NA), Specificity = c(NA, NA), NPV = c(NA, NA), PPV = c(NA, NA))

metrics[1,1] = ConfMtrain_stackglm$byClass[7]
metrics[2,1] = ConfMtest_stackglm$byClass[7]
metrics[1,2] = AUCtrain_stackglm
metrics[2,2] = AUCtest_stackglm
metrics[1,3] = PRAUCtrain_stackglm
metrics[2,3] = PRAUCtest_stackglm
metrics[1,4] = ConfMtrain_stackglm$overall[1]
metrics[2,4] = ConfMtest_stackglm$overall[1]
metrics[1,5] = ConfMtrain_stackglm$byClass[1]
metrics[2,5] = ConfMtest_stackglm$byClass[1]
metrics[1,6] = ConfMtrain_stackglm$byClass[2]
metrics[2,6] = ConfMtest_stackglm$byClass[2]
metrics[1,7] = ConfMtrain_stackglm$byClass[4]
metrics[2,7] = ConfMtest_stackglm$byClass[4]
metrics[1,8] = ConfMtrain_stackglm$byClass[3]
metrics[2,8] = ConfMtest_stackglm$byClass[3]
metrics[1,9] = ConfMtrain_stackglm$byClass[5]
metrics[2,9] = ConfMtest_stackglm$byClass[5]

#Export relevant files.
write.table(x = data.frame(YtrainPredProb_stackglm), file = file.path(path, "Train/", i, "YtrainPredProb_stackglm.txt"), quote = FALSE, sep = "\t", row.names = TRUE)
write.table(x = data.frame(YtrainTrue_stackglm), file = file.path(path, "Train/", i, "YtrainTrue_stackglm.txt"), quote = FALSE, sep = "\t", row.names = TRUE)
write.table(x = data.frame(YtestPredProb_stackglm), file = file.path(path, "Test/", i, "YtestPredProb_stackglm.txt"), quote = FALSE, sep = "\t", row.names = TRUE)
write.table(x = data.frame(YtestTrue_stackglm), file = file.path(path, "Test/", i, "YtestTrue_stackglm.txt"), quote = FALSE, sep = "\t", row.names = TRUE)

write.table(metrics, file = file.path(path, "metrics/", i, "metrics.txt"), sep = "\t", row.names = FALSE, col.names = TRUE, quote = FALSE)

saveRDS(object = fit_model, file = file.path(path, "models/", i, "fit_model.RDS"))
saveRDS(object = fit_scale, file = file.path(path, "models/", i, "fit_scale.RDS"))

write.table(as.data.frame(IDs_train), file = file.path(path, "Train/", i, "IDs_train.txt"), sep = "\t", row.names = FALSE, col.names=TRUE, quote = FALSE)
write.table(as.data.frame(IDs_test), file = file.path(path, "Test/", i, "IDs_test.txt"), sep = "\t", row.names = FALSE, col.names=TRUE, quote = FALSE)



