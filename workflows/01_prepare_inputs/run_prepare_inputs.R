# Prepare DSSAT-EW inputs and counterfactual weather treatments.

source("R/packages.R")
load_dssat_ew_packages()
source("R/utils.R")
source_dssat_ew_R(".")

cfg <- read_dssat_ew_config("config/dssat_ew_config.yml")
ensure_dir(cfg$paths$result_dir)

inputs <- read_dssat_ew_inputs(cfg) %>%
  coerce_input_dates()

thresholds <- calc_extreme_thresholds(
  weather_daily = inputs$weather_daily,
  baseline_years = unlist(cfg$extremes$baseline_years),
  heat_prob = cfg$extremes$heat_prob,
  cold_prob = cfg$extremes$cold_prob,
  precip_prob = cfg$extremes$precip_prob
)

counterfactual_weather <- build_counterfactual_weather_set(
  weather_daily = inputs$weather_daily,
  thresholds = thresholds,
  treatments = unlist(cfg$extremes$treatments)
)

readr::write_csv(thresholds, file.path(cfg$paths$result_dir, "dssat_ew_thresholds.csv"))
readr::write_csv(counterfactual_weather, file.path(cfg$paths$result_dir, "counterfactual_weather.csv"))

message("Prepared DSSAT-EW thresholds and counterfactual weather treatments.")
