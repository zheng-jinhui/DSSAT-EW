# DSSAT-EW feature construction and prediction.

build_dssat_ew_features <- function(weather_daily,
                                    phenology_windows,
                                    dssat_outputs,
                                    climate_background,
                                    cfg,
                                    thresholds = NULL) {
  if (is.null(thresholds)) {
    thresholds <- calc_extreme_thresholds(
      weather_daily = weather_daily,
      baseline_years = unlist(cfg$extremes$baseline_years),
      heat_prob = cfg$extremes$heat_prob,
      cold_prob = cfg$extremes$cold_prob,
      precip_prob = cfg$extremes$precip_prob
    )
  }

  exposure <- build_exposure_features(
    weather_daily = weather_daily,
    phenology_windows = phenology_windows,
    thresholds = thresholds
  )

  feature_table <- assemble_feature_table(
    dssat_outputs = standardize_dssat_outputs(dssat_outputs),
    exposure_features = exposure$exposure_features,
    climate_background = climate_background
  )

  list(
    thresholds = thresholds,
    stage_exposure = exposure$stage_exposure,
    exposure_features = exposure$exposure_features,
    feature_table = feature_table
  )
}

apply_dssat_ew_models <- function(feature_table,
                                  model_bundle,
                                  targets = names(model_bundle)) {
  out <- feature_table

  for (target in targets) {
    model_obj <- model_bundle[[target]]
    raw_col <- paste0(target, "_residual_raw")
    bounded_col <- paste0(target, "_residual_bounded")
    dssat_col <- paste0(target, "_dssat")
    ew_col <- paste0(target, "_dssat_ew")

    assert_columns(out, c(dssat_col, model_obj$predictor_cols), "feature_table")
    raw_residual <- predict_residual(model_obj$model, out)
    bounded_residual <- bounded_response(raw_residual, model_obj$lambda)

    out[[raw_col]] <- raw_residual
    out[[bounded_col]] <- bounded_residual
    out[[ew_col]] <- out[[dssat_col]] + bounded_residual
  }

  out
}

run_dssat_ew_prediction <- function(inputs,
                                    cfg,
                                    model_bundle,
                                    thresholds = NULL) {
  features <- build_dssat_ew_features(
    weather_daily = inputs$weather_daily,
    phenology_windows = inputs$phenology_windows,
    dssat_outputs = inputs$dssat_outputs,
    climate_background = inputs$climate_background,
    cfg = cfg,
    thresholds = thresholds
  )

  corrected <- apply_dssat_ew_models(
    feature_table = features$feature_table,
    model_bundle = model_bundle,
    targets = cfg$columns$target_variables
  )

  list(
    corrected_outputs = corrected,
    thresholds = features$thresholds,
    stage_exposure = features$stage_exposure,
    exposure_features = features$exposure_features
  )
}

