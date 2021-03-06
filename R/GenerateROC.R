##' @title Generate a Receiver-Operator Characteristic (ROC) Curve from a CRISPR screen  
##' @description Given a set of targets of interest, this function generates a ROC curve and associated statistics from the results of 
##' a CRISPR screen. Specifically, it orders the elements targeted in the screen by the specified statistic, and then plots the cumulative
##' proportion of positive hits on the y-axis. The corresponding vextors and Area Under the Curve (AUC) statistic are returned as a list.
##' 
##' Note that ranking statistics in CRISPR screens are (usually) permutation-based, and so some granularity is expected. This 
##' function does a little extra work to ensure that hits are counted as soon as the requisite value of the ranking statistic is reached 
##' regardless of where the gene is located within the block of equally-significant genes. Functionally, this means that the drawn curve is
##' somewhat anticonservative in cases where the gene ranks are not well differentiated.  
##'
##' @param summaryDF A dataframe summarizing the results of the screen, returned by the function \code{\link{ct.generateResults}}. 
##' @param target.list A character vector containing the names of the targets to be tested. Only targets contained in the \code{geneID} 
##' column of the provided \code{summaryDF} are considered.
##' @param stat The statistic to use when ordering the genes. Must be one of \code{"enrich.p"}, \code{"deplete.p"}, \code{"enrich.fc"}, 
##' \code{"deplete.fc"}, \code{"enrich.rho"}, or \code{"deplete.rho"}. 
##' @param condense Logical indicating whether the returned x and y coordinates should be "condensed", returning only the points at which 
##' the detected proportion of \code{target.list} changes. If set to \code{FALSE}, the returned \code{x} and \code{y} vectors will explicitly
##' indicate the curve value at every position (useful for performing curve arithmetic downstream).   
##' @param plot.it Logical value indicating whether to plot the curves. 
##' @return A list containing the the x and y coordinates of the curve, and the AUC statistic.
##' @author Russell Bainer
##' @examples data('resultsDF')
##' data('essential.genes') #Note that this is an artificial example.
##' roc <- ct.ROC(resultsDF, essential.genes, 'enrich.p')
##' str(roc)
##' @export

ct.ROC <-
  function(summaryDF,
           target.list,
           stat = c("enrich.p", "deplete.p", "enrich.fc", "deplete.fc", "enrich.rho", "deplete.rho"),
           condense = TRUE, 
           plot.it = TRUE) {
    
  
  #Check the input: 
    if(!ct.resultCheck(summaryDF)){
      stop("Execution halted.")
    }

    #Convert to gene-level stats
    summaryDF <- summaryDF[!duplicated(summaryDF$geneID),]
    row.names(summaryDF) <- summaryDF$geneID
    
    if(!is.character(target.list)){
      warning("Supplied target.list is not a character vector. Coercing.")
      target.list <- as.character(target.list)
    }
    present <- intersect(target.list, summaryDF$geneID)
    if(length(present) != length(target.list)){
      if(length(present) < 1){
        stop("None of the genes in the input list are present in the geneSymbol column of the input data.frame.")
        }
      warning(paste(length(present), "of", length(target.list), "genes are present in the supplied results data.frame. Ignoring the remainder of the target.list."))
    }
    
    #Gather the values for the targets: 
    stat <- match.arg(stat)
    targvals <- switch(stat, 
         enrich.p = (summaryDF[(summaryDF$geneID %in% present),"Target-level Enrichment P"]), 
         deplete.p = (summaryDF[(summaryDF$geneID %in% present),"Target-level Depletion P"]), 
         enrich.fc = (-summaryDF[(summaryDF$geneID %in% present),"Median log2 Fold Change"]), 
         deplete.fc = (summaryDF[(summaryDF$geneID %in% present),"Median log2 Fold Change"]),
         enrich.rho = (summaryDF[(summaryDF$geneID %in% present),"Rho_enrich"]),
         deplete.rho = (summaryDF[(summaryDF$geneID %in% present),"Rho_deplete"])
    )   

    #Extract the appropriate stat for the curve 
    values <- switch(stat, 
        enrich.p = sort(summaryDF[,"Target-level Enrichment P"]), 
        deplete.p = sort(summaryDF[,"Target-level Depletion P"]), 
        enrich.fc = sort(-summaryDF[,"Median log2 Fold Change"]), 
        deplete.fc = sort(summaryDF[,"Median log2 Fold Change"]),
        enrich.rho = sort(summaryDF[,"Rho_enrich"]), 
        deplete.rho = sort(summaryDF[,"Rho_deplete"])
    )


    out <- list()
    out$specificity <- c(0, which(!duplicated(values)), length(values))
    out$sensitivity <- c(0, unlist(lapply(unique(values), function(x){sum(targvals <= x, na.rm = TRUE)/length(targvals)})), 1)
    
    #Calculate the AUC/Enrichment
    binWidth <- out$specificity[2:length(out$specificity)] - out$specificity[1:(length(out$specificity) - 1)]
    out$AUC <- sum(out$sensitivity[1:(length(out$specificity) - 1)] * binWidth)/length(values)
    
    enrich <- switch(stat, 
                  enrich.p = ct.targetSetEnrichment(summaryDF, target.list, enrich = TRUE),
                  deplete.p =  ct.targetSetEnrichment(summaryDF, target.list, enrich = FALSE),
                  enrich.fc =  ct.targetSetEnrichment(summaryDF, target.list, enrich = TRUE),
                  deplete.fc =  ct.targetSetEnrichment(summaryDF, target.list, enrich = FALSE)
    )
    out <- c(out, enrich)

    #Plot it?
    if(plot.it){
      plot(out$specificity, out$sensitivity, xlim = c(0, length(values)), ylim = c(0,1), 
           type = "l", ylab = "Sensitivity", xlab = "Specificity", 
           main = paste("AUC:", round(out$AUC, 3)), col = "blue", lwd = 3)
      abline(0, 1/length(values), lty = "dashed", col = "red")
      }
    
    if(!condense){
      out <- .rocXY(out)
    }
    
    return(out)
    }

 
.rocXY <- function(roc){
  elements <- 0:max(roc$specificity)
  y <- lapply(elements, function(value){
    pos <- length(roc$specificity[roc$specificity <= value])
    return(roc$sensitivity[pos])
  })
  
  return(list(x = elements, y = unlist(y), 
              AUC = roc$AUC, 
              targets = roc$targets, 
              P.values = roc$P.values, 
              Q.values = roc$Q.values))
}

  
  
  
  
  
  
  
  



