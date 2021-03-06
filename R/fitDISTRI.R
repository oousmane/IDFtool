#' @name 
#' fitDISTRI
#' 
#' @title 
#' Fit distribution functions by L-moments, probability weighted moments, maximum 
#' likelihood and moments
#' 
#' @description 
#' This function allows to fit several distribution functions to observed data
#' by means of the methods L-moments, probability weighted moments, maximum 
#' likelihood and moments. It also assesses the goodness of fit test with different 
#' statistics (see \code{\link{goodFIT}}).
#'
#' @param Intensity a numeric vector with intensity [mm/h] values of different
#' years for a specific time duration (\emph{e.g.} 5, 15, 120 minutes, \emph{etc}.).
#' @param Type a character specifying the name of the distribution function that will 
#' be employed: exponencial, gamma, gev, gumbel, log.normal3, normal, pearson, log.pearson3 and 
#' wakeby (see \code{\link{selecDIST}}).
#' @param Plot a number (1) to determine if it will be plotted density curves 
#' both empirical as modeled (\emph{pdf}). a number (2) to determine if it will be 
#' plotted curves between return \code{Periods} and intensity computed by \emph{pdf} fitted. 
#' Or use both numbers to get these graphs. If any other number is used, graphs 
#' will not appear.
#' @param M.fit a character specifying the name of fit method employed on pdf, just three 
#' options are available: L-moments (\emph{Lmoments}), Probability-Weighted Moments (\emph{PWD}), 
#' Maximum Likelihood (\emph{MLE}) (see \code{\link{MLEZ}}) and Moments (\emph{MME}) (see \code{\link{MME_DIST}}). 
#' @param Periods a numeric vector with return periods.
#' @param Dura a character specifying a time duration of the \code{Intensity}, (e.g. 30 min). 
#' This parameter is used to save results.
#' @param Station a character specifying a name or number of pluviographic station where data were 
#' measured. It is used to save results.  
#' @param CI a logical value specifying whether confidence interval should be 
#' cumputed to \emph{pdf} fitted by means \code{\link{bootstrapCI}} function.
#' @param iter an integer representing number of resamples to conduct when 
#' confidence interval will be computed (see \code{\link{bootstrapCI}}). Use it only if 
#' CI is equal to TRUE.
#' @param goodtest a logical value specifying whether goodness-fit tests should be 
#' cumputed to \emph{pdf} fitted by means of \code{\link{goodFIT}} function.
#' @param Resolution a number to determine resolution that the plot function will used to save graphs. 
#' It has two options: 300 and 600 ppi. See \code{\link{resoPLOT}}.
#' @param SAVE a logical value. TRUE will save \code{Plot}, FALSE will just show it.  
#'
#' @return A list with the fitted distribution and the parameters:
#' 
#'  \itemize{
#'    \item \code{Parameters} a list with type of distribution fitted and values of its parameters
#'    \item \code{Int.pdf} a numeric vector of intensities values per each return \code{Periods} compute by \emph{pdf} fitted. 
#'    \item \code{Conf.Inter} a matrix with lower and upper limits of confidence 
#'    interval for \emph{pdf} fitted and computed for each return \code{Periods}.
#'    \item \code{goodness.fit} a data frame with statistics values of goodness of fit tests and its respective p-value, 
#'    moreover information criteria are evaluated (see \code{\link{goodFIT}}) 
#'    \item \code{Info.PDF} a vector with details about fit method and distribution function employed. 
#'  }
#' @author David Zamora <dazamoraa@unal.edu.co> 
#' Water Resources Engineering Research Group - GIREH
#'   
#' @export
#'
#' @examples
#' 
#' # Meteorology station in the Farfan Airport in Tulua, Colombia.
#' data(inten)
#' fit.pdf <- fitDISTRI(Intensity =inten[15:35,2], Type ="Gumbel", Plot = 12, M.fit = "LMOMENTS",
#'                      Periods =c(2,3,5,10,25,50,100), Dura ="5 min", Station ="2610", CI = TRUE,
#'                      iter =100, goodtest = TRUE,Resolution = 300, SAVE = FALSE)
#' 
fitDISTRI <- function(Intensity, Type ="Gumbel", Plot = 2, M.fit = "MLE",
                      Periods, Dura, Station, CI = FALSE, iter ,
                      goodtest = FALSE, Resolution = 300, SAVE = FALSE){
  
  # ----Fix variables----
  M.fit <- tolower(M.fit)
  Type <- tolower(Type)
  Tp <- Periods
  DR <- colnames(Intensity)
  Plot <- as.character(Plot)
  
  # ----Fit distribution----
  if(Type=="log.pearson3"){
    Intensity<-log10(Intensity)
  }
  
  distribution<-selecDIST(Type = Type)
  FR<-lmomco::T2prob(Tp)
  
  if(M.fit=="lmoments"){
    LMOM <- lmomco::lmoms(Intensity)
    if(LMOM$ratios[3] < 0 & distribution == "ln3"){
      LMOM$ratios[3] <- -LMOM$ratios[3]
    }
    Parameters <- lmomco::lmom2par(LMOM, type = distribution)
    INT <- lmomco::par2qua(FR,Parameters)
  }else if(M.fit == "pwd"){
    PMP <- lmomco::pwm(Intensity)
    Parameters<-lmomco::lmom2par(lmomco::pwm2lmom(PMP),type = distribution)
    INT <- lmomco::par2qua(FR,Parameters)
  }else if(M.fit == "mle"){
    Parameters <- MLEZ(Intensity, type = Type)
    INT <- lmomco::par2qua(FR,Parameters)
  }else if(M.fit == "mme"){
    
    if(Type == "log.pearson3"){
      Intensity <- 10^Intensity
    }
    Parameters <- MME_DIST(Intensity, Type = Type)
    
    if (is.null(Parameters)){
      INT <- NULL
    } else {
      INT <- lmomco::par2qua(FR,Parameters) 
    }
    
  }else{
    stop("Error on selecction fit model")
  }
  
  if(Type=="log.pearson3" & M.fit != "mme"){
    INT <- 10^INT
    Intensity <- 10^Intensity
  } else if (Type=="log.pearson3" & M.fit == "mme") {
    INT <- 10^INT
  } else {
    
  }
  
  if(is.null(INT)){
    
  } else {
    names(INT) <- as.character(Tp)
  }
  
  # ----Computed goodness-fit tests-----
  
  test.fit <- NULL
  if(is.null(INT)){
    test.fit <- rep(NA,8)
  } else {
    if (goodtest) {
      test.fit <- goodFIT(Station = Station, Type = Type, Intensity = Intensity, Parameters = Parameters,
                          M.fit = M.fit,Dura = Dura, Plot = Plot,  Resolution = Resolution ,SAVE = SAVE)
    }
  }
  # ---- Computed confidence interval----
  CI.result <- NULL
  if (CI) {
    Ttick <- c(1.001, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 25, 30, 40, 50, 60, 70, 80, 90, 100, 150)
    FR.plot <- lmomco::T2prob(Ttick)
    CI.result <- bootstrapCI(Intensity = Intensity, Parameters = Parameters, Type = Type,
                             Rsample = iter, Return.P = FR.plot, Conf.Inter = 0.95)
  }
  # ----Plot Frecuency versus Intesity----
  if (grepl("2", Plot) & CI) {
    
    if (SAVE) {
      if(file.exists(paste(".", "FIGURES", Station, M.fit, Type, sep = "/"))){
        path.fig <- paste(".", "FIGURES", Station, M.fit, Type, sep = "/")
      }else{
        dir.create(paste(".", "FIGURES", Station, M.fit, Type, sep = "/"), recursive = TRUE)
        path.fig <- paste(".", "FIGURES", Station, M.fit, Type, sep = "/")
      }
      
      custom <- resoPLOT(reso = Resolution)
      grDevices::png(filename = paste(path.fig, "/IvsF", "_", Type, "_", M.fit, "_", Dura, ".png", sep = ""),
                     width = custom[2], height = custom[4], pointsize = 10, res = custom[1], bg = "transparent")
    }
    
    lim.max <- max(CI.result$Conf.Inter[ ,3], na.rm = T)
    lim.min <- min(CI.result$Conf.Inter[ ,2], na.rm = T)
    lim.vert <- c(lim.min, lim.max)
    
    graphics::par(mar = c(4.1, 3.5, 2.2, 2) + 0.1)
    graphics::par(mgp = c(2.2, 0.2, 0))
    graphics::plot(Ttick,lmomco::par2qua(FR.plot,Parameters),type = "n",
                   main = paste("Intensity vs Frequency ", Type, "-", M.fit, "\n", Station, sep = ""),
                   ylim = lim.vert, xaxt = "n", yaxt = "n", bty = "n", xlab = "Return periods [year]",
                   ylab = "Intensity [mm/h]", cex.lab = 1, cex.main = 0.9,log = "yx")
    
    graphics::abline(v = graphics::axTicks(1), h = graphics::axTicks(2), col = "gray80", lty = 3)
    graphics::polygon(c(Ttick, rev(Ttick)), c(CI.result$Conf.Inter[ ,2], rev(CI.result$Conf.Inter[ ,3])),
                      col = scales::alpha("gray75", alpha = 0.2), border = scales::alpha("gray75", alpha = 0.2))
    graphics::lines(Ttick, CI.result$Conf.Inter[ ,2], lty = 2, lwd = 0.7, col = "gray68")
    graphics::lines(Ttick, CI.result$Conf.Inter[ ,3], lty = 2, lwd = 0.7, col = "gray68")
    if(Type=="log.pearson3"){
      graphics::lines(Ttick, 10^lmomco::par2qua(FR.plot,Parameters), lty = 4, lwd = 1.1, col = "red")
    } else {
      graphics::lines(Ttick, lmomco::par2qua(FR.plot,Parameters), lty = 4, lwd = 1.1, col = "red")
    }
    if(Type=="log.pearson3"){
      NEP.obs <- lmomco::par2cdf(log10(Intensity), Parameters)
      Tp.obs <- lmomco::prob2T(NEP.obs)
    } else {
      NEP.obs <- lmomco::par2cdf(Intensity, Parameters)
      Tp.obs <- lmomco::prob2T(NEP.obs)
    }
    graphics::points(Tp.obs, Intensity, pch = 21, bg = "blue", col = "blue",cex = 0.8)
    
    graphics::legend("bottomright", c("CI 95 %", "Fit pdf", "Observed"), col = c("gray68", "red", "blue"),
                     pt.bg = c(scales::alpha("gray75", alpha = 0.2), NA ,"blue"), pch = c(22,-1,21),
                     lty = c(-1, 4, -1), lwd = 1, bty = "n", border = NULL, cex = 0.7, pt.cex = 1.1,
                     title = paste("Duration\n", Dura, sep = ""), title.col = "magenta")
    
    magicaxis::magaxis(1, labels = FALSE, col = "gray56")
    graphics::axis(1, graphics::axTicks(1), graphics::axTicks(1), tick = FALSE, line = -0.05,cex.axis = 0.9)
    magicaxis::magaxis(2, las = 2, col = "gray56")
    #axis(2,axTicks(2),axTicks(2), lwd.ticks = 0.5, tck = 0.02, las = 2, cex.axis = 0.9)
    graphics::box(col = "gray56", lwd = 0.7)
    
    if (SAVE) {
      grDevices::dev.off()
    }
  }
  
  return(list(Parameters = Parameters,
              Int.pdf = INT,
              Conf.Inter = CI.result,
              goodness.fit = test.fit,
              Info.PDF = c(Type, M.fit))
  )
}
