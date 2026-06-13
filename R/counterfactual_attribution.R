# Counterfactual climate-extreme attribution for DSSAT-EW outputs.

prepare_counterfactual_weather_inputs <- function(inputs, cfg, thresholds = NULL) {
  if (is.null(thresholds)) {
    thresholds <- calc_extreme_thresholds(
      inputs$weather_daily,
      baseline_years = unlist(cfg$extremes$baseline_years),
      heat_prob = cfg$extremes$heat_prob,
      cold_prob = cfg$extremes$cold_prob,
      precip_prob = cfg$extremes$precip_prob
    )
  }

  inputs$weather_daily <- build_counterfactual_weather_set(
    weather_daily = inputs$weather_daily,
    thresholds = thresholds,
    treatments = unlist(cfg$extremes$treatments)
  )
  inputs
}

compute_counterfactual_contribution <- function(predictions,
                                                harvested_area,
                                                target,
                                                treatment,
                                                group_cols = c("crop", "ssp", "esm", "year"),
                                                area_col = "harvested_area") {
  value_col <- paste0(target, "_dssat_ew")
  assert_columns(predictions, c("grid_id", "crop", "treatment", value_col), "predictions")
  assert_columns(harvested_area, c("grid_id", "crop", area_col), "harvested_area")

  base <- predictions %>%
    dplyr::filter(treatment == "baseline") %>%
    dplyr::select(dplyr::all_of(unique(c("grid_id", group_cols, value_col))))
  names(base)[names(base) == value_col] <- "base_value"

  cf <- predictions %>%
    dplyr::filter(treatment == !!treatment) %>%
    dplyr::select(dplyr::all_of(unique(c("grid_id", group_cols, value_col))))
  names(cf)[names(cf) == value_col] <- "cf_value"

  join_cols <- intersect(c("grid_id", group_cols), names(base))

  base %>%
    dplyr::left_join(cf, by = join_cols) %>%
    dplyr::left_join(harvested_area, by = c("grid_id", "crop")) %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) %>%
    dplyr::summarise(
      target = target,
      treatment = treatment,
      contribution_percent = weighted_relative_difference(base_value, cf_value, .data[[area_col]]),
      baseline_weighted_mean = stats::weighted.mean(base_value, .data[[area_col]], na.rm = TRUE),
      counterfactual_weighted_mean = stats::weighted.mean(cf_value, .data[[area_col]], na.rm = TRUE),
      .groups = "drop"
    )
}

compute_all_counterfactual_contributions <- function(predictions,
                                                     harvested_area,
                                                     targets,
                                                     treatments = c("no_heat", "no_cold", "no_precip", "no_all"),
                                                     group_cols = c("crop", "ssp", "esm", "year"),
                                                     area_col = "harvested_area") {
  tidyr::crossing(target = targets, treatment = treatments) %>%
    purrr::pmap_dfr(function(target, treatment) {
      compute_counterfactual_contribution(
        predictions = predictions,
        harvested_area = harvested_area,
        target = target,
        treatment = treatment,
        group_cols = group_cols,
        area_col = area_col
      )
    })
}
