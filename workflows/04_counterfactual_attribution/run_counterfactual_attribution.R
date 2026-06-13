# Counterfactual attribution of climate-extreme impacts.

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

thresholds <- calc_extreme_thresholds(
  inputs$weather_daily,
  baseline_years = unlist(cfg$extremes$baseline_years),
  heat_prob = cfg$extremes$heat_prob,
  cold_prob = cfg$extremes$cold_prob,
  precip_prob = cfg$extremes$precip_prob
)

inputs_cf <- prepare_counterfactual_weather_inputs(inputs, cfg, thresholds)

prediction <- run_dssat_ew_prediction(
  inputs = inputs_cf,
  cfg = cfg,
  model_bundle = model_bundle,
  thresholds = thresholds
)

contrib <- compute_all_counterfactual_contributions(
  predictions = prediction$corrected_outputs,
  harvested_area = inputs$harvested_area,
  targets = cfg$columns$target_variables,
  treatments = setdiff(unlist(cfg$extremes$treatments), "baseline"),
  group_cols = unlist(cfg$attribution$group_cols),
  area_col = cfg$attribution$area_weight_col
)

readr::write_csv(prediction$corrected_outputs, file.path(cfg$paths$result_dir, "counterfactual_dssat_ew_outputs.csv"))
readr::write_csv(contrib, file.path(cfg$paths$result_dir, "counterfactual_contributions.csv"))

message("Completed DSSAT-EW counterfactual attribution.")
