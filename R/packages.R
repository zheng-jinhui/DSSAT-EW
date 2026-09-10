# Package checks for DSSAT-EW.

dssat_ew_required_packages <- c(
  "dplyr",
  "tidyr",
  "purrr",
  "readr",
  "yaml",
  "randomForest",
  "digest",
  "rlang"
)

load_dssat_ew_packages <- function(pkgs = dssat_ew_required_packages) {
  missing_pkgs <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing_pkgs) > 0) {
    stop(
      "Missing required R packages: ",
      paste(missing_pkgs, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(lapply(pkgs, library, character.only = TRUE))
}
