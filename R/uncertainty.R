# Uncertainty helper functions for DSSAT-EW ensembles.

summarise_ensemble <- function(df,
                               value_col,
                               group_cols,
                               ensemble_col = "ensemble_id") {
  assert_columns(df, c(group_cols, ensemble_col, value_col), "ensemble_df")

  df %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) %>%
    dplyr::summarise(
      n_ensemble = dplyr::n_distinct(.data[[ensemble_col]]),
      ensemble_mean = mean(.data[[value_col]], na.rm = TRUE),
      ensemble_sd = stats::sd(.data[[value_col]], na.rm = TRUE),
      ensemble_var = stats::var(.data[[value_col]], na.rm = TRUE),
      q05 = stats::quantile(.data[[value_col]], 0.05, na.rm = TRUE),
      q50 = stats::quantile(.data[[value_col]], 0.50, na.rm = TRUE),
      q95 = stats::quantile(.data[[value_col]], 0.95, na.rm = TRUE),
      .groups = "drop"
    )
}

decompose_prediction_uncertainty <- function(ensemble_summary,
                                             reference_df,
                                             group_cols,
                                             reference_col,
                                             mean_col = "ensemble_mean",
                                             variance_col = "ensemble_var") {
  assert_columns(ensemble_summary, c(group_cols, mean_col, variance_col), "ensemble_summary")
  assert_columns(reference_df, c(group_cols, reference_col), "reference_df")

  ensemble_summary %>%
    dplyr::left_join(reference_df, by = group_cols) %>%
    dplyr::mutate(
      squared_bias = (.data[[mean_col]] - .data[[reference_col]])^2,
      model_variance = .data[[variance_col]],
      msep = squared_bias + model_variance,
      bias_fraction = safe_divide(squared_bias, msep),
      variance_fraction = safe_divide(model_variance, msep)
    )
}

partition_variance_by_source <- function(df,
                                         value_col,
                                         group_cols,
                                         source_col = "uncertainty_source") {
  assert_columns(df, c(group_cols, source_col, value_col), "uncertainty_df")

  source_var <- df %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(c(group_cols, source_col)))) %>%
    dplyr::summarise(source_variance = stats::var(.data[[value_col]], na.rm = TRUE), .groups = "drop")

  total_var <- df %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) %>%
    dplyr::summarise(total_variance = stats::var(.data[[value_col]], na.rm = TRUE), .groups = "drop")

  source_var %>%
    dplyr::left_join(total_var, by = group_cols) %>%
    dplyr::mutate(variance_fraction = safe_divide(source_variance, total_variance))
}

