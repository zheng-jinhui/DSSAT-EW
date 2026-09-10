# Train and validate Random Forest residual models for DSSAT-EW.

source("R/packages.R")
load_dssat_ew_packages()
source("R/utils.R")
source_dssat_ew_R(".")

cfg <- read_dssat_ew_config("config/dssat_ew_config.yml")
ensure_dir(cfg$paths$model_dir)
ensure_dir(cfg$paths$result_dir)

inputs <- read_dssat_ew_inputs(cfg) %>%
  coerce_input_dates()

features <- build_dssat_ew_features(
  weather_daily = inputs$weather_daily,
  phenology_windows = inputs$phenology_windows,
  dssat_outputs = inputs$dssat_outputs,
  climate_background = inputs$climate_background,
  cfg = cfg
)

validation <- validate_all_residual_models(
  feature_table = features$feature_table,
  observations = inputs$observations,
  cfg = cfg
)

models <- fit_all_residual_models(
  feature_table = features$feature_table,
  observations = inputs$observations,
  cfg = cfg
)

save_residual_model_bundle(models, cfg$paths$model_dir)

readr::write_csv(validation$metrics, file.path(cfg$paths$result_dir, "loocv_metrics.csv"))
readr::write_csv(validation$predictions, file.path(cfg$paths$result_dir, "loocv_predictions.csv"))
readr::write_csv(features$stage_exposure, file.path(cfg$paths$result_dir, "stage_exposure.csv"))
readr::write_csv(features$exposure_features, file.path(cfg$paths$result_dir, "seasonal_exposure_features.csv"))

message("Trained DSSAT-EW RF residual models and wrote validation diagnostics.")
