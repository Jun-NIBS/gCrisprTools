##' @title Normalize sample abundance estimates by a spline fit to the nontargeting controls
##' @description This function normalizes Crispr gRNA abundance estimates by fiting a smoothed spline to the nontargeting gRNAs within each sample
##' and then equalizing these curves across the experiment. Specifically, the algorithm ranks the gRNA abundance estimates within each sample and 
##' uses a smoothed spline to determine a relationship between the ranks of nontargeting guides and their abundance estimates. It then removes the
##' spline trend from each sample, centering each experiment around the global median abundance; these values are returned as normalized counts in 
##' the '\code{exprs}' slot of the input eset. 
##' @param eset An ExpressionSet object containing, at minimum, count data accessible by \code{exprs}. 
##' @param annotation An annotation dataframe indicating the nontargeting controls in the geneID column. 
##' @param geneSymb The \code{geneSymbol} identifier in \code{annotation} that corresponds to nontargeting gRNAs. If absent, \code{ct.gRNARankByReplicate} will
##' attempt to infer nontargeting guides by searching for \code{"no_gid"} or \code{NA} in the appropriate columns.  
##' @param lib.size An optional vector of voom-appropriate library size adjustment factors, usually calculated with \code{\link[edgeR]{calcNormFactors}} 
##' and transformed to reflect the appropriate library size. These adjustment factors are interpreted as the total library sizes for each sample, 
##' and if absent will be extrapolated from the columnwise count sums of the \code{exprs} slot of the \code{eset}.
##' @return A normalized \code{eset}.
##' @author Russell Bainer
##' @examples data('es')
##' data('ann')
##' 
##' #Build the sample key and library sizes for visualization
##' library(Biobase)
##' sk <- (relevel(as.factor(pData(es)$TREATMENT_NAME), "ControlReference"))
##' names(sk) <- row.names(pData(es))
##' ls <- colSums(exprs(es))
##' 
##' es.norm <- ct.normalizeSpline(es, ann, 'NoTarget', lib.size = ls)
##' ct.gRNARankByReplicate(es, sk, lib.size = ls)
##' ct.gRNARankByReplicate(es.norm, sk, lib.size = ls)
##' @export

ct.normalizeSpline <- function(eset, annotation, geneSymb = NULL, lib.size = NULL){
  
  if(class(eset) != "ExpressionSet"){stop(paste(deparse(substitute(eset)), "is not an ExpressionSet."))}
  
  #Check the annotation and find the NTC rows
  if(!is.data.frame(annotation)){
    stop("An annotation dataframe must be supplied if controls is TRUE.")
  }
  annotation <- invisible(ct.prepareAnnotation(annotation, eset, throw.error = FALSE))  
  
  if(!is.null(geneSymb)){   
    if(geneSymb %in% annotation$geneSymbol){
      ntc <- row.names(annotation)[annotation$geneSymbol %in% geneSymb]      
      } else {
          stop(paste(deparse(substitute(geneSymb)),"is not present in the geneSymbol column of the annotation file."))
          }
    } else if("NoTarget" %in% annotation$geneSymbol){
      message('Using gRNAs targeting "NoTarget"')  
      ntc <- row.names(annotation)[annotation$geneSymbol %in% "NoTarget"]      
      } else { 
        stop("I can't tell which guides are nontargeting. Please specify a geneSymbol that you would like for me to use.")
        }
  
  
  #log the data and fit curves to the NTCs. 
  counts <- exprs(eset)
  
  if (is.null(lib.size)){
    lib.size <- colSums(counts)
  } 
  
  e.dat <- t(log2(t(counts + 0.5)/(lib.size + 1) * 1e+06))
  ntcVals <- e.dat[ntc,]
  
  samRanks <- apply(e.dat, 2, rank)
  ntcRanks <- samRanks[ntc,]
 
  fits <- lapply(colnames(e.dat), function(x){smooth.spline(ntcRanks[,x], y = ntcVals[,x])})
  corrections <- lapply(fits, function(x){predict(fits[[1]], 1:nrow(e.dat))})
  names(fits) <- colnames(e.dat)
  #Subtract out the appropriate values
  corrected <- vapply(colnames(e.dat), 
                      function(x){(e.dat[,x] - predict(fits[[x]], samRanks[,x])[[2]]) + median(e.dat)}, 
                      numeric(nrow(e.dat)) 
                      )
  #colnames(corrected) <- names(fits)
  corrected <- 2^corrected
  corrected <- round(t(t(corrected) * ((lib.size + 1) / 1e+06)) - 0.5)
  
  #update and return the eset
  exprs(eset)<- corrected
  return(eset)
}


##' @title Normalize sample abundance estimates by the median values of nontargeting control guides
##' @description This function normalizes Crispr gRNA abundance estimates by equalizing the median 
##' abundances of the nontargeting gRNAs within each sample. The normalized values are returned as normalized counts in 
##' the '\code{exprs}' slot of the input eset. Note that this method may be unstable if the screening library contains 
##' relatively few nontargeting gRNAs. 
##' @param eset An ExpressionSet object containing, at minimum, count data accessible by \code{exprs}. 
##' @param annotation An annotation dataframe indicating the nontargeting controls in the geneID column. 
##' @param lib.size An optional vector of voom-appropriate library size adjustment factors, usually calculated with \code{\link[edgeR]{calcNormFactors}} 
##' and transformed to reflect the appropriate library size. These adjustment factors are interpreted as the total library sizes for each sample, 
##' and if absent will be extrapolated from the columnwise count sums of the \code{exprs} slot of the \code{eset}.
##' @param geneSymb The \code{geneSymbol} identifier in \code{annotation} that corresponds to nontargeting gRNAs. If absent, \code{ct.gRNARankByReplicate} will
##' attempt to infer nontargeting guides by searching for \code{"no_gid"} or \code{NA} in the appropriate columns via \code{ct.prepareAnnotation()}.  
##' @return A normalized \code{eset}. 
##' @author Russell Bainer
##' @examples data('es')
##' data('ann')
##' 
##' #Build the sample key and library sizes for visualization
##' library(Biobase)
##' sk <- ordered(relevel(as.factor(pData(es)$TREATMENT_NAME), "ControlReference"))
##' names(sk) <- row.names(pData(es))
##' ls <- colSums(exprs(es))
##' 
##' es.norm <- ct.normalizeNTC(es, ann, lib.size = ls, geneSymb = 'NoTarget')
##' 
##' ct.gRNARankByReplicate(es, sk, lib.size = ls)
##' ct.gRNARankByReplicate(es.norm, sk, lib.size = ls)
##' @export

ct.normalizeNTC <- function(eset, annotation, lib.size = NULL, geneSymb = NULL){
  
  if(class(eset) != "ExpressionSet"){stop(paste(deparse(substitute(eset)), "is not an ExpressionSet."))}
  
  #Check the annotation and find the NTC rows
  if(!is.data.frame(annotation)){
    stop("An annotation dataframe must be supplied to normalize to nontargeting controls.")
  }
  annotation <- invisible(ct.prepareAnnotation(annotation, eset))  
  
  if(!is.null(geneSymb)){   
    if(geneSymb %in% annotation$geneSymbol){
      ntc <- row.names(annotation)[annotation$geneSymbol %in% geneSymb]      
    } else {
      stop(paste(deparse(substitute(geneSymb)),"is not present in the geneSymbol column of the annotation file."))
    }
  } else if("NoTarget" %in% annotation$geneSymbol){
    message('Using gRNAs targeting "NoTarget"')  
    ntc <- row.names(annotation)[annotation$geneSymbol %in% "NoTarget"]      
  } else { 
    stop("I can't tell which guides are nontargeting. Please specify a geneSymbol that you would like for me to use.")
  }
  
  #Update the eset and return it.
  counts <- exprs(eset)
  
  if (is.null(lib.size)){
    lib.size <- colSums(counts)
  } 
  
  y <- t(log2(t(counts + 0.5)/(lib.size + 1) * 1e+06))
  ntcVals <- y[ntc,]
  cmed <- rowMedians(t(ntcVals), na.rm = TRUE)
  cmed <- (cmed - mean(cmed))
  
  y <- t(t(y)-cmed)
  y <- 2^y
  y <- round(t(t(y) * ((lib.size + 1) / 1e+06)) - 0.5)
  exprs(eset) <- y
  return(eset)
}







