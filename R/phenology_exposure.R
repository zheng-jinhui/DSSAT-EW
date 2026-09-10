# Phenology-dependent extreme-weather exposure metrics.

join_weather_to_phenology <- function(weather_daily,
                                      phenology_windows,
                                      join_cols = c("grid_id", "year", "crop")) {
  assert_columns(weather_daily, c(join_cols, "date"), "weather_daily")
  assert_columns(phenology_windows, c(join_cols, "stage", "stage_group", "start_date", "end_date"), "phenology_windows")

  phenology_windows %>%
    dplyr::left_join(weather_daily, by = join_cols, relationship = "many-to-many") %>%
    dplyr::filter(date >= start_date, date <= end_date)
}

calc_stage_exposure <- function(weather_daily,
                                phenology_windows,
                                thresholds,
                                group_cols = c("grid_id", "year", "crop", "esm", "ssp", "treatment")) {
  weather_flagged <- weather_daily %>%
    attach_extreme_thresholds(thresholds, group_cols = c("grid_id", "crop")) %>%
    flag_extreme_days()

  join_cols <- intersect(c("grid_id", "year", "crop", "esm", "ssp", "treatment"), names(weather_flagged))

  joined <- join_weather_to_phenology(
    weather_daily = weather_flagged,
    phenology_windows = phenology_windows,
    join_cols = intersect(join_cols, names(phenology_windows))
  )

  summary_cols <- intersect(group_cols, names(joined))

  joined %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(c(summary_cols, "stage", "stage_group")))) %>%
    dplyr::summarise(
      stage_days = dplyr::n(),
      heat_days = sum(heat_event, na.rm = TRUE),
      cold_days = sum(cold_event, na.rm = TRUE),
      precip_days = sum(precip_event, na.rm = TRUE),
      heat_frequency = heat_days / stage_days,
      cold_frequency = cold_days / stage_days,
      precip_frequency = precip_days / stage_days,
      heat_exposure = mean(heat_intensity, na.rm = TRUE),
      cold_exposure = mean(cold_intensity, na.rm = TRUE),
      precip_exposure = mean(precip_intensity, na.rm = TRUE),
      .groups = "drop"
    )
}

summarise_exposure_by_season <- function(stage_exposure,
                                         id_cols = c("grid_id", "year", "crop", "esm", "ssp", "treatment")) {
  summary_cols <- intersect(id_cols, names(stage_exposure))

  seasonal <- stage_exposure %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(summary_cols))) %>%
    dplyr::summarise(
      heat_exposure = stats::weighted.mean(heat_exposure, stage_days, na.rm = TRUE),
      cold_exposure = stats::weighted.mean(cold_exposure, stage_days, na.rm = TRUE),
      precip_exposure = stats::weighted.mean(precip_exposure, stage_days, na.rm = TRUE),
      heat_frequency = stats::weighted.mean(heat_frequency, stage_days, na.rm = TRUE),
      cold_frequency = stats::weighted.mean(cold_frequency, stage_days, na.rm = TRUE),
      precip_frequency = stats::weighted.mean(precip_frequency, stage_days, na.rm = TRUE),
      .groups = "drop"
    )

  stage_wide <- stage_exposure %>%
    dplyr::mutate(stage_group = ifelse(stage_group %in% c("early", "late"), stage_group, stage)) %>%
    dplyr::select(dplyr::all_of(summary_cols), stage_group, heat_exposure, cold_exposure, precip_exposure) %>%
    tidyr::pivot_wider(
      names_from = stage_group,
      values_from = c(heat_exposure, cold_exposure, precip_exposure),
      names_glue = "{.value}_{stage_group}"
    )

  seasonal %>%
    dplyr::left_join(stage_wide, by = summary_cols)
}

build_exposure_features <- function(weather_daily,
                                    phenology_windows,
                                    thresholds,
                                    id_cols = c("grid_id", "year", "crop", "esm", "ssp", "treatment")) {
  stage <- calc_stage_exposure(weather_daily, phenology_windows, thresholds, group_cols = id_cols)
  season <- summarise_exposure_by_season(stage, id_cols = id_cols)
  list(stage_exposure = stage, exposure_features = season)
}

