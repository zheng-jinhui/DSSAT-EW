# Historical thresholds and counterfactual no-extreme weather treatments.

calc_extreme_thresholds <- function(weather_daily,
                                    baseline_years,
                                    heat_prob = 0.90,
                                    cold_prob = 0.10,
                                    precip_prob = 0.95,
                                    group_cols = c("grid_id", "crop")) {
  assert_columns(weather_daily, c(group_cols, "year", "tmax", "tmin", "precip"), "weather_daily")

  weather_daily %>%
    dplyr::filter(year %in% baseline_years) %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) %>%
    dplyr::summarise(
      tmax_p90 = stats::quantile(tmax, heat_prob, na.rm = TRUE),
      tmin_p10 = stats::quantile(tmin, cold_prob, na.rm = TRUE),
      precip_p95 = stats::quantile(precip, precip_prob, na.rm = TRUE),
      sd_tmax = stats::sd(tmax, na.rm = TRUE),
      sd_tmin = stats::sd(tmin, na.rm = TRUE),
      sd_precip = stats::sd(precip, na.rm = TRUE),
      .groups = "drop"
    )
}

attach_extreme_thresholds <- function(weather_daily,
                                      thresholds,
                                      group_cols = c("grid_id", "crop")) {
  threshold_cols <- c("tmax_p90", "tmin_p10", "precip_p95", "sd_tmax", "sd_tmin", "sd_precip")
  if (all(threshold_cols %in% names(weather_daily))) {
    return(weather_daily)
  }

  weather_daily <- weather_daily %>%
    dplyr::select(-dplyr::any_of(threshold_cols))

  weather_daily %>%
    dplyr::left_join(thresholds, by = group_cols)
}

flag_extreme_days <- function(weather_with_thresholds) {
  assert_columns(
    weather_with_thresholds,
    c("tmax", "tmin", "precip", "tmax_p90", "tmin_p10", "precip_p95"),
    "weather_with_thresholds"
  )

  weather_with_thresholds %>%
    dplyr::mutate(
      heat_event = is.finite(tmax) & is.finite(tmax_p90) & tmax > tmax_p90,
      cold_event = is.finite(tmin) & is.finite(tmin_p10) & tmin < tmin_p10,
      precip_event = is.finite(precip) & is.finite(precip_p95) & precip > precip_p95,
      heat_intensity = pmax(tmax - tmax_p90, 0) / pmax(sd_tmax, 1e-12),
      cold_intensity = pmax(tmin_p10 - tmin, 0) / pmax(sd_tmin, 1e-12),
      precip_intensity = pmax(precip - precip_p95, 0) / pmax(sd_precip, 1e-12)
    )
}

make_counterfactual_weather <- function(weather_with_thresholds,
                                        treatment = c("baseline", "no_heat", "no_cold", "no_precip", "no_all")) {
  treatment <- match.arg(treatment)

  out <- weather_with_thresholds
  if (treatment %in% c("no_heat", "no_all")) {
    out$tmax <- pmin(out$tmax, out$tmax_p90)
  }
  if (treatment %in% c("no_cold", "no_all")) {
    out$tmin <- pmax(out$tmin, out$tmin_p10)
  }
  if (treatment %in% c("no_precip", "no_all")) {
    out$precip <- pmin(out$precip, out$precip_p95)
  }

  out$treatment <- treatment
  out
}

build_counterfactual_weather_set <- function(weather_daily,
                                             thresholds,
                                             treatments = c("baseline", "no_heat", "no_cold", "no_precip", "no_all"),
                                             group_cols = c("grid_id", "crop")) {
  weather_with_thresholds <- attach_extreme_thresholds(weather_daily, thresholds, group_cols)
  purrr::map_dfr(treatments, ~ make_counterfactual_weather(weather_with_thresholds, .x))
}
