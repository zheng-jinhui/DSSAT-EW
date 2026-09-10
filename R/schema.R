# Input schemas and validation helpers.

dssat_ew_schema <- list(
  weather_daily = c(
    "grid_id", "year", "date", "crop", "esm", "ssp", "tmax", "tmin", "precip",
    "srad"
  ),
  phenology_windows = c(
    "grid_id", "year", "crop", "stage", "stage_group", "start_date", "end_date"
  ),
  dssat_outputs = c(
    "grid_id", "year", "crop", "esm", "ssp", "treatment", "yield_dssat",
    "n2o_dssat", "ch4_dssat", "lai_dssat", "soil_moisture_dssat",
    "soil_n_dssat"
  ),
  observations = c(
    "obs_id", "grid_id", "year", "crop", "yield_obs", "n2o_obs", "ch4_obs"
  ),
  climate_background = c(
    "grid_id", "year", "crop", "esm", "ssp", "mean_tmax", "mean_tmin",
    "total_precip", "mean_srad"
  ),
  harvested_area = c("grid_id", "crop", "harvested_area")
)

assert_columns <- function(df, required, table_name = deparse(substitute(df))) {
  missing_cols <- setdiff(required, names(df))
  if (length(missing_cols) > 0) {
    stop(
      table_name,
      " is missing required columns: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(df)
}

validate_dssat_ew_table <- function(df, schema_name) {
  if (!schema_name %in% names(dssat_ew_schema)) {
    stop("Unknown schema: ", schema_name, call. = FALSE)
  }
  assert_columns(df, dssat_ew_schema[[schema_name]], schema_name)
}

check_unique_keys <- function(df, keys, table_name = deparse(substitute(df))) {
  dup <- df %>%
    dplyr::count(dplyr::across(dplyr::all_of(keys)), name = "n") %>%
    dplyr::filter(n > 1)

  if (nrow(dup) > 0) {
    stop(table_name, " has duplicate key rows for: ", paste(keys, collapse = ", "), call. = FALSE)
  }
  invisible(df)
}

validate_dssat_ew_inputs <- function(inputs) {
  purrr::iwalk(inputs, function(x, nm) {
    if (nm %in% names(dssat_ew_schema)) validate_dssat_ew_table(x, nm)
  })
  invisible(inputs)
}

read_dssat_ew_inputs <- function(cfg) {
  list(
    weather_daily = readr::read_csv(cfg$paths$weather_daily, show_col_types = FALSE),
    phenology_windows = readr::read_csv(cfg$paths$phenology_windows, show_col_types = FALSE),
    dssat_outputs = readr::read_csv(cfg$paths$dssat_outputs, show_col_types = FALSE),
    observations = readr::read_csv(cfg$paths$observations, show_col_types = FALSE),
    climate_background = readr::read_csv(cfg$paths$climate_background, show_col_types = FALSE),
    harvested_area = readr::read_csv(cfg$paths$harvested_area, show_col_types = FALSE)
  ) %>%
    validate_dssat_ew_inputs()
}

coerce_input_dates <- function(inputs) {
  inputs$weather_daily$date <- as.Date(inputs$weather_daily$date)
  inputs$phenology_windows$start_date <- as.Date(inputs$phenology_windows$start_date)
  inputs$phenology_windows$end_date <- as.Date(inputs$phenology_windows$end_date)
  inputs
}
