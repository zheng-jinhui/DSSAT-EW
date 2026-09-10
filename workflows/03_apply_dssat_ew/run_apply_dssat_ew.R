# Apply trained DSSAT-EW residual models to gridded DSSAT simulations.

source("R/packages.R")
load_dssat_ew_packages()
source("R/utils.R")
source_dssat_ew_R(".")

cfg <- read_dssat_ew_config("config/dssat_ew_config.yml")
ensure_dir(cfg$paths$result_dir)

inputs <- read_dssat_ew_inputs(cfg) %>%
  coerce_input_dates()

model_bundle <- load_residual_model_bundle(
  model_dir = cfg$paths$model_dir,
  targets = cfg$columns$target_variables
)

prediction <- run_dssat_ew_prediction(
  inputs = inputs,
  cfg = cfg,
  model_bundle = model_bundle
)

readr::write_csv(prediction$corrected_outputs, file.path(cfg$paths$result_dir, "dssat_ew_corrected_outputs.csv"))
readr::write_csv(prediction$stage_exposure, file.path(cfg$paths$result_dir, "dssat_ew_stage_exposure.csv"))
readr::write_csv(prediction$exposure_features, file.path(cfg$paths$result_dir, "dssat_ew_exposure_features.csv"))

message("Applied DSSAT-EW correction to DSSAT outputs.")
