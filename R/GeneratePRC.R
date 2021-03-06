##' @title Generate a Precision-Recall Curve from a CRISPR screen  
##' @description Given a set of targets of interest, this function generates a Precision Recall curve from the results of 
##' a CRISPR screen. Specifically, it orders the target elements in the screen by the specified statistic, and then plots the recall 
##' rate (proportion of true targets identified) against the precision (proportion of identified targets that are true targets). 
##' 
##' Note that ranking statistics in CRISPR screens are (usually) permutation-based, and so some granularity in the rankings is expected. This 
##' function does a little extra work to ensure that hits are counted as soon as the requisite value of the ranking statistic is reached 
##' regardless of where the gene is located within the block of equally-significant genes. Functionally, this means that the drawn curve is
##' somewhat anticonservative in cases where the gene ranks are not well differentiated.  
##'
##' @param summaryDF A dataframe summarizing the results of the screen, returned by the function \code{\link{ct.generateResults}}. 
##' @param target.list A character vector containing the names of the targets to be tested. Only targets contained in the \code{geneID} 
##' column of the provided \code{summaryDF} are considered.
##' @param stat The statistic to use when ordering the genes. Must be one of \code{"enrich.p"}, \code{"deplete.p"}, \code{"enrich.fc"}, 
##' or \code{"deplete.fc"}. 
##' @param plot.it Logical value indicating whether to plot the curves. 
##' @return A list containing the the x and y coordinates of the curve.
##' @author Russell Bainer
##' @examples data('resultsDF')
##' data('essential.genes') #Note that this is an artificial example.
##' pr <- ct.PRC(resultsDF, essential.genes, 'enrich.p')
##' str(pr)
##' @export

ct.PRC <-
  function(summaryDF,
           target.list,
           stat = c("enrich.p", "deplete.p", "enrich.fc", "deplete.fc", "enrich.rho", "deplete.rho"), 
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
    #Extract the appropriate stat. 
    values <- switch(stat, 
        enrich.p = sort(summaryDF[,"Target-level Enrichment P"]), 
        deplete.p = sort(summaryDF[,"Target-level Depletion P"]), 
        enrich.fc = sort(-summaryDF[,"Median log2 Fold Change"]), 
        deplete.fc = sort(summaryDF[,"Median log2 Fold Change"]),
        enrich.rho = sort(summaryDF[,"Rho_enrich"]), 
        deplete.rho = sort(summaryDF[,"Rho_deplete"])
    )

    out <- list()
    out$precision <- c(1, unlist(lapply(unique(values), function(x){sum(targvals <= x, na.rm = TRUE)/sum(values <= x, na.rm= TRUE)})), 0)
    out$recall <- c(0, unlist(lapply(unique(values), function(x){sum(targvals <= x, na.rm = TRUE)/length(targvals)})), 1)
    
    enrich <- switch(stat, 
                     enrich.p = ct.targetSetEnrichment(summaryDF, target.list, enrich = TRUE),
                     deplete.p =  ct.targetSetEnrichment(summaryDF, target.list, enrich = FALSE),
                     enrich.fc =  ct.targetSetEnrichment(summaryDF, target.list, enrich = TRUE),
                     deplete.fc =  ct.targetSetEnrichment(summaryDF, target.list, enrich = FALSE),
                     enrich.rho = ct.targetSetEnrichment(summaryDF, target.list, enrich = TRUE),
                     deplete.rho = ct.targetSetEnrichment(summaryDF, target.list, enrich = FALSE)
    )
    out <- c(out, enrich)
    
    #Plot it?
    if(plot.it){
      plot(out$recall, out$precision, xlim = c(0, 1), ylim = c(0,1), 
           type = "l", ylab = "Precision", xlab = "Recall", 
           main = paste("Precision and Recall of", deparse(substitute(target.list))), col = "blue", lwd = 3)
      }
    return(out)
    }


  
  
  
  
  
  
  
  



