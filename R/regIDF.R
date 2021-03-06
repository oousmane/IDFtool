#' @name
#' regIDF
#' 
#' @title 
#' Determine coefficients of IDF curves by means Levenberg-Marquardt algorithm
#' 
#' @description 
#' An Intensity-Duration-Frequency curve (IDF Curve) is a graphical representation
#' of the probability that a given average rainfall intensity will occur. 
#' This function allows compute the coefficients of an equation that represents 
#' IDF per each return period: I(D) = A/(B+D)^C.
#' 
#' where \emph{I} are intensities [mm/h] per each return periods, \emph{D} is time duration [min] 
#' and \emph{A}, \emph{B} and \emph{C} are coefficients. The last are calibrated by the Levenberg-Marquardt 
#' algorithm (see  \code{\link{nls.lm}}). Moreover, \code{regIDF} computes confidence and prediction
#' intervals to calibrate equiations by means of \code{\link{predFit}} function (see \pkg{investr} package). Finally, this function 
#' assesses the performance of the equations by means of four metrics: roor mean square error (\code{\link{rmse}}),
#' coefficient of determination (br2) multiplied by the slope of the regression line between sim and obs (\code{\link{br2}}), 
#' mean square error \code{\link{mse}} and information criteria \code{\link{AIC}} and \code{\link{BIC}}.
#'
#' @param Intensity a matrix with intensity values per specific time durations 
#' (by rows) and return \code{Periods} (by columns). To use this function, the smallest 
#' matrix dimension must be 3 rows and 1 column.
#' @param Periods a numeric vector with return periods.
#' @param Durations a numeric vector specifying a time duration of the \code{Intensity} in minutes. 
#' @param logaxe a character to plot axis in log scale: x, y or both (xy). In other case used "". 
#' @param Plot use (3) to plot IDF curves (\code{Durations} versus \code{Intensity})
#'  for all return \code{Periods}. Use (4) to plot IDF curve for each return
#'  period with its confidence and prediction intervals. Or use both numbers to get these graphs. If you use other number the graphs will not appear. 
#' @param Intervals a logical value specifying whether confidence and prediction intervals will be computed.
#' @param Resolution a number to determine resolution that the plot function will used to save graphs. 
#' It can has two options: 300 and 600 ppi. See \code{\link{resoPLOT}}.
#' @param SAVE a logical value. TRUE will save \code{Plot} FALSE just will show \code{Plot} it. 
#' @param Strategy a numeric vector used to identify Strategy when it is used to \code{SAVE}. 
#' @param M.fit a character specifying a name or number of pluviographic station where data were measured, and it is used to save results. 
#' @param Type  a character specifying the name of distribution function that it will be employed: exponencial, gamma, gev, gumbel, log.normal3, normal,
#' log.pearson3 and wakeby (see \code{\link{selecDIST}}).
#' @param name a vector of characters used to save graphs. It allows differentiation strategy to compute IDF curves. 
#' @param Station a character specifying a name or number of pluviographic station where data were measured, and it is used to save results.  
#'
#' @return A list of
#' 
#' \itemize{
#'  \item \code{Predict} a numeric matrix with the intensities values of the IDF 
#'  equation calibrated. Durations by rows and return periods by columns.
#'  \item \code{Coefficients} a numeric matrix with values of the coefficients \emph{A}, \emph{B} and \emph{C} for each return period.
#'  \item \code{test.fit.reg} a numeric matrix with perfomance metrics (\emph{rmse}, \emph{mse}, \emph{br2}, \emph{AIC} and \emph{BIC} by each equation.
#'  \item \code{Prediction.Int} a list with matrices. Each matrix has the lower and upper limit of the \bold{prediction} interval 
#'  per each specific time duration. Two columns by \emph{n} durations.
#'  \item \code{Confidence.Int} a list with matrices. Each matrix has the lower and upper limit of the \bold{confidence} interval 
#'  per each specific time duration. Two columns by \emph{n} durations.
#' }
#' 
#' @author David Zamora <dazamoraa@unal.edu.co> 
#' Water Resources Engineering Research Group - GIREH
#' 
#' @export
#' 
#' @import hydroGOF 
#'
#' @examples
#' 
#' # Meteorology station in the Airport Farfan in Tulua, Colombia.
#' data(IDFdata)
#' TEST.out <- regIDF(Intensity = IDFdata, Periods = c(2,3,5,10,25,50,100), 
#'                  Durations = c(5,10,15,20,30,60,120,360), logaxe = "", Plot = 34, 
#'                  Resolution = 300, SAVE = FALSE, Strategy = 1,
#'                  M.fit = "lmoments", Type = "gumbel", name = "Test", Station = "2601")
#'                  
regIDF <- function(Intensity, Periods, Durations, logaxe,
         Plot = 34, Intervals = TRUE, Resolution = 300, SAVE = FALSE, Strategy,
         M.fit, Type, name, Station){
  
  # ----Define variables and outputs----
  estr <- Strategy
  idf <- Intensity
  Tp <- Periods
  nTp <- length(Tp)
  logaxe <- logaxe
  durations.2 <- Durations    # change durations to minutes
  yfit <- matrix(NA, nrow = length(durations.2), ncol = length(Tp)) # Predictions
  M.coeficientes <- matrix(NA, nrow = length(Tp), ncol = 3) # Regression coefficients of the IDF curve
  colnames(M.coeficientes)  <-  c("A", "B", "C")
  
  # -----Calibration IDF equation----
  Modelos <- list()
  Inter.Conf.R <- Inter.Pred.R <- list()
  fit.model <- matrix(NA, nrow = length(Tp), ncol = 5) # Akaike's An Information Criterion y Bayesian Criterion
  colnames(fit.model) <- c("aic.pr", "bic.pr", "BR2", "MSE", "RMSE")
  
  for (iT in 1:nTp) {
    MD.INT <- as.data.frame(cbind(durations.2, idf[ ,iT]))
    colnames(MD.INT) <- c("Dura", "Inten")
    mod.lm <- minpack.lm::nlsLM(Inten~((A)/((B+Dura)^C)), data = MD.INT,
                                start = list(A = 1000, B = 0.2, C = 0.01), control = minpack.lm::nls.lm.control(maxiter=1000))
    Modelos[[as.character(Tp[iT])]] <- mod.lm
    M.coeficientes[iT, ] <- stats::coef(mod.lm)
    yfit[ ,iT]  <-  stats::predict(mod.lm, interval = "confidence", level=0.95)
    
    fit.model[iT,1] <- stats::AIC(mod.lm)
    fit.model[iT,2] <- stats::BIC(mod.lm)
    fit.model[iT,3] <- hydroGOF::br2(idf[ ,iT], yfit[ ,iT])
    fit.model[iT,4] <- hydroGOF::mse(idf[ ,iT], yfit[ ,iT])
    fit.model[iT,5] <- hydroGOF::rmse(idf[ ,iT], yfit[ ,iT])
  
    nam.int<-paste(as.character(Tp)[iT], " years", sep= "")
    if (Intervals){
      Inter.Conf.R[[nam.int]] <- investr::predFit(mod.lm, interval = "confidence")
      Inter.Pred.R[[nam.int]] <- investr::predFit(mod.lm, interval = "prediction")
      
      rownames(Inter.Conf.R[[iT]])<-as.character(durations.2)
      rownames(Inter.Pred.R[[iT]])<-as.character(durations.2)
    }
  }
  
  # ----Plotting curves by each return period in just a figure-----
  if (grepl("3", Plot)) {
    
    if (SAVE) {
      if (file.exists(paste(".", "FIGURES", Station, M.fit, Type, sep = "/"))) {
        path.fig <- paste(".", "FIGURES", Station, M.fit, Type, sep = "/")
      } else {
        dir.create(paste(".", "FIGURES", Station, M.fit, Type, sep = "/"), recursive = TRUE)
        path.fig <- paste(".", "FIGURES", Station, M.fit, Type, sep = "/")
      }
      custom <- resoPLOT(reso = Resolution)
      grDevices::png(filename = paste(path.fig, "/", name[Strategy], "_IDF.png", sep = ""),
          width = custom[2], height = custom[4], pointsize = 10, res = custom[1], bg = "transparent")
    }
    
    graphics::par(mar = c(3.5, 3.2, 1.5, 2) + 0.1)
    graphics::par(mgp = c(2.2, 0.2, 0))
    psym <- seq(1, nTp) # Symbols that represent different return periods
    xtick <- c(5, 10, 15, 20, 30, 60, 120, 360) # set axis labels and location of the gridlines
    ymax <- max(idf)
    # Intensity vs duration for the first return period
    graphics::plot(durations.2, idf[, 1], xaxt = "n", yaxt = "n", type = "n", pch = psym[1], log = logaxe,
         xlim = c(4, 6*60), ylim = c(1, ymax),xlab = "Duration [min]",
         ylab = "", main = paste("IDF curves - Data: ", name[estr], "\n Station: ",
                                 Station, sep = ""), cex.main = 0.7, font = 1)
    
    graphics::abline(v = xtick, h = graphics::axTicks(1), col = "gray55", lwd = 0.6, lty = 3)
    
    for (iT in 1:nTp) {
      # Plot I vs D for the others return period
      graphics::points(durations.2, idf[, iT], pch = psym[iT], col = grDevices::rainbow(nTp)[iT], cex = 0.6)
      # Add lines of the regression models fitted (IDF)
      graphics::lines(durations.2, yfit[,iT], lty = psym[iT], lwd = 0.7, col = "gray72")
    }
    
    magicaxis::magaxis(2, ylab = "Intensity [mm/hr]", las = 2, cex.axis = 0.8)
    graphics::axis(1, at = xtick, labels = xtick, cex.axis = 0.8)
    graphics::legend("topright", bg = scales::alpha("white", alpha = 0.2), pch = -1, lty = psym, legend = rep("", nTp), title = "Ret.Periods [Year]",
           title.adj = 0.7, cex = 0.5, col = "gray72")
    graphics::legend("topright", bg = NULL, bty = "n",pch = psym, lty = -1, legend = as.character(Tp), title = "",
           cex = 0.5,col = grDevices::rainbow(nTp))
    
    if (SAVE) {
      grDevices::dev.off()
    }
  }
  
  # ----Figuras independientes IDF por duracion----
  
  for (k in 1:length(Tp)) {
    if (Intervals){
      LI.IC <- Inter.Conf.R[[k]][ ,2]
      LS.IC <- Inter.Conf.R[[k]][ ,3]
      LI.PR <- Inter.Pred.R[[k]][ ,2]
      LS.PR <- Inter.Pred.R[[k]][ ,3]
      PR.media <- stats::predict(Modelos[[k]])
    } else {
      Inter.Conf.R <- NULL
      Inter.Pred.R <- NULL
      LI.IC <- LS.IC <- LI.PR <- LS.PR <- NA
      PR.media <- stats::predict(Modelos[[k]])
    }
    
    if (grepl("4",Plot)) {
      
      if (SAVE) {
        if(file.exists(paste(".", "FIGURES", Station, M.fit, Type, sep = "/"))){
          path.fig <- paste(".", "FIGURES", Station, M.fit, Type, sep = "/")
        }else{
          dir.create(paste(".", "FIGURES", Station, M.fit, Type, sep = "/"),recursive = TRUE)
          path.fig <- paste(".", "FIGURES", Station, M.fit, Type, sep = "/")
        }
        
        custom  <-  resoPLOT(reso = Resolution)
        grDevices::png(filename =paste(path.fig, "/", name[Strategy], "_IDF_I-CP_Periodo-R", Tp[k],
                            ".png", sep = ""), width = custom[2], height = custom[4],
            pointsize = 10, res = custom[1], bg = "transparent")
      }
      
      limyR <- c(min(idf[,k], LI.PR, LI.IC, na.rm = T),max(idf[,k], LS.PR, LS.IC, na.rm = T))
      
      graphics::par(mar=c(3.5, 3.2, 2.5, 2) + 0.1)
      graphics::par(mgp=c(2.2, 0.2, 0))
      graphics::plot(0, ylim = limyR, xlim = c(min(durations.2), max(durations.2)), type = "n", axes = FALSE, xlab = "", ylab = "",bty = "n")
      graphics::abline(v = durations.2, h = graphics::axTicks(2), col = "gray45", lty = 3,lwd = 0.5)
      magicaxis::magaxis(2, las = 2, cex.axis = 0.8)
      magicaxis::magaxis(1, cex.axis = 0.8)
      graphics::par(new=TRUE)
      investr::plotFit(Modelos[[k]], interval = "both", col.conf = scales::alpha("cyan", alpha = 0.2),
                       col.pred = scales::alpha("gray70",alpha=0.2), col.fit = "red", axes = FALSE,
                       shade = TRUE, xlab = "Duration [min]", ylab = "Intensity [mm/h]",
                       lwd.conf = 0.01, lwd.pred = 0.01, pch = 20, col = scales::alpha("white", alpha = 0.5),cex=0.9,
                       main = paste("IDF curve for a return period of", Tp[k], "years", sep = " "),
                       cex.main = 0.9, ylim = limyR, xaxt = "n", yaxt = "n")
      graphics::par(new=TRUE)
      investr::plotFit(Modelos[[k]], interval = "both", col.conf = scales::alpha("cyan", alpha = 0.7),
                       col.pred = scales::alpha("gray70", alpha = 0.7), col.fit = NULL, xaxt = "n", yaxt = "n",
                       lty.conf = 2, lty.pred = 4, lwd.conf = 1, lwd.pred = 1,
                       xlab = "", ylab = "", pch = "", bty = "n", ylim = limyR)
      graphics::points(durations.2, PR.media, pch = 20, col = scales::alpha("blue", alpha = 0.5))
      graphics::legend("topright", c("Prediction","Observed","Conf. Int. 95 %","Pred. Int 95 %"),
             col = c("red", scales::alpha("blue", alpha = 0.5), scales::alpha("cyan", alpha=0.2), scales::alpha("gray70", alpha = 0.2)),
             lty = c(1,-1, -1, -1), pt.bg = c(NULL, NULL, scales::alpha("cyan",alpha=0.7), scales::alpha("gray70", alpha = 0.7)),
             pch = c(-1, 20, 22, 22), bg = scales::alpha("white", alpha = 0.3), pt.cex = 1.4, cex = 0.7, box.col = scales::alpha("white",alpha = 0.1))
      graphics::box()
      if (SAVE) {
        grDevices::dev.off()
      }
    }
  }
  colnames(yfit) <- as.character(Tp)
  rownames(yfit) <- as.character(durations.2)
  rownames(M.coeficientes) <- as.character(Tp)
  rownames(fit.model) <- as.character(Tp)
  
  return(list(Predict = yfit,
              Coefficients = M.coeficientes,
              test.fit.reg = fit.model,
              Prediction.Int = Inter.Pred.R,
              Confidence.Int = Inter.Conf.R,
              Modols = Modelos)
  )
}
