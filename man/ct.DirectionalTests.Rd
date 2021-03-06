% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/DirTest.R
\name{ct.DirectionalTests}
\alias{ct.DirectionalTests}
\title{Compute Directional P-values from eBayes Output}
\usage{
ct.DirectionalTests(fit, contrast.term = NULL)
}
\arguments{
\item{fit}{An object of class MArrayLM containing, at minimum, a \code{df.residual} slot containing the appropriate degres of freedom for each test, and a \code{t} slot containing t statistics.}

\item{contrast.term}{If a fit object with multiple coefficients is passed in, a string indiating the coefficient of interest.}
}
\value{
A matrix object with two numeric columns, indicating the p-values quantifying the evidence for enrichment and depletion of each feature in the relevant model contrast.
}
\description{
This function produces two sets of one-sided P-values derived from the moderated t-statistics produced by eBayes.
}
\examples{
data('fit')
ct.DirectionalTests(fit)
}
\author{
Russell Bainer
}
