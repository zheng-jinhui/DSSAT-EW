# General utilities for DSSAT-EW.

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

read_dssat_ew_config <- function(config_file = "config/dssat_ew_config.yml") {
  yaml::read_yaml(config_file)
}

ensure_dir <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE)
  invisible(path)
}

safe_divide <- function(numerator, denominator, eps = 1e-12) {
  numerator / ifelse(abs(denominator) < eps, NA_real_, denominator)
}

bounded_response <- function(x, lambda, eps = 1e-12) {
  # Smooth symmetric truncation used in DSSAT-EW:
  #   r_bounded = lambda * tanh(r_raw / lambda)
  # It preserves the sign, is approximately linear near zero, and approaches
  # +/- lambda asymptotically. NA predictions remain NA.
  if (is.null(lambda) || !is.finite(lambda) || abs(lambda) < eps) {
    stop("lambda must be a finite positive scalar.", call. = FALSE)
  }
  lambda * tanh(x / lambda)
}

training_data_fingerprint <- function(df, columns = names(df)) {
  # A base-R MD5 fingerprint makes a released fitted object traceable to the
  # exact training table without redistributing restricted observations.
  columns <- sort(intersect(columns, names(df)))
  canonical <- df[, columns, drop = FALSE]
  canonical <- canonical[do.call(order, lapply(canonical, function(x) as.character(x))), , drop = FALSE]
  row.names(canonical) <- NULL
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(canonical, tmp, version = 3)
  unname(tools::md5sum(tmp))
}

z_score <- function(x) {
  s <- stats::sd(x, na.rm = TRUE)
  if (!is.finite(s) || s == 0) return(rep(0, length(x)))
  (x - mean(x, na.rm = TRUE)) / s
}

minmax01 <- function(x) {
  lo <- min(x, na.rm = TRUE)
  hi <- max(x, na.rm = TRUE)
  if (!is.finite(lo) || !is.finite(hi) || hi == lo) return(rep(0, length(x)))
  (x - lo) / (hi - lo)
}

rmse <- function(obs, pred) {
  ok <- is.finite(obs) & is.finite(pred)
  sqrt(mean((obs[ok] - pred[ok])^2))
}

mae <- function(obs, pred) {
  ok <- is.finite(obs) & is.finite(pred)
  mean(abs(obs[ok] - pred[ok]))
}

r2_score <- function(obs, pred) {
  ok <- is.finite(obs) & is.finite(pred)
  if (sum(ok) < 3) return(NA_real_)
  denom <- sum((obs[ok] - mean(obs[ok]))^2)
  if (denom == 0) return(NA_real_)
  1 - sum((obs[ok] - pred[ok])^2) / denom
}

metric_table <- function(obs, pred, target = "target") {
  ok <- is.finite(obs) & is.finite(pred)
  dplyr::tibble(
    target = target,
    n = sum(ok),
    RMSE = rmse(obs, pred),
    MAE = mae(obs, pred),
    R2 = r2_score(obs, pred),
    bias = mean(pred[ok] - obs[ok])
  )
}

weighted_relative_difference <- function(base, counterfactual, weight) {
  num <- sum((base - counterfactual) * weight, na.rm = TRUE)
  den <- sum(base * weight, na.rm = TRUE)
  100 * safe_divide(num, den)
}

source_dssat_ew_R <- function(root = ".") {
  files <- c(
    "R/packages.R",
    "R/utils.R",
    "R/schema.R",
    "R/climate_thresholds.R",
    "R/phenology_exposure.R",
    "R/dssat_bridge.R",
    "R/residual_learning.R",
    "R/dssat_ew_predict.R",
    "R/counterfactual_attribution.R",
    "R/uncertainty.R"
  )
  invisible(lapply(file.path(root, files), source))
}
