# Random Forest residual learning for DSSAT-EW.

resolve_predictor_cols <- function(cfg, feature_table) {
  predictors <- unlist(cfg$predictors, use.names = FALSE)
  predictors <- unique(predictors)
  present <- intersect(predictors, names(feature_table))
  missing <- setdiff(predictors, names(feature_table))
  if (length(missing) > 0) {
    warning("Predictor columns not found and will be skipped: ", paste(missing, collapse = ", "))
  }
  present
}

fit_rf_residual_model <- function(train_df,
                                  predictor_cols,
                                  response_col = "residual",
                                  ntree = 500,
                                  mtry = NULL,
                                  nodesize = 5,
                                  seed = 123) {
  assert_columns(train_df, c(predictor_cols, response_col), "train_df")
  if (length(predictor_cols) == 0) stop("No predictor columns available.", call. = FALSE)
  if (nrow(train_df) < 5) stop("Too few training rows for Random Forest residual correction.", call. = FALSE)

  set.seed(seed)
  if (is.null(mtry)) {
    mtry <- max(1, floor(sqrt(length(predictor_cols))))
  }

  form <- stats::as.formula(paste(response_col, "~", paste(predictor_cols, collapse = " + ")))
  randomForest::randomForest(
    formula = form,
    data = train_df,
    ntree = ntree,
    mtry = mtry,
    nodesize = nodesize,
    importance = TRUE,
    na.action = stats::na.omit
  )
}

predict_residual <- function(model, newdata) {
  as.numeric(stats::predict(model, newdata = newdata))
}

estimate_lambda <- function(residuals, prob = 0.95) {
  lambda <- stats::quantile(abs(residuals), prob, na.rm = TRUE, names = FALSE)
  if (!is.finite(lambda) || lambda == 0) lambda <- max(abs(residuals), na.rm = TRUE)
  if (!is.finite(lambda) || lambda == 0) lambda <- 0
  lambda
}

fit_target_residual_model <- function(feature_table,
                                      observations,
                                      target,
                                      predictor_cols,
                                      cfg,
                                      id_cols = c("grid_id", "year", "crop")) {
  residual_df <- make_target_residuals(feature_table, observations, target, id_cols)
  complete_rows <- stats::complete.cases(residual_df[, c(predictor_cols, "residual"), drop = FALSE])
  training_df <- residual_df[complete_rows, , drop = FALSE]
  if (nrow(training_df) < 5) {
    stop(
      "Too few complete training rows for ", target, ": ", nrow(training_df),
      " of ", nrow(residual_df), ". Check missing predictor values and target-specific predictors.",
      call. = FALSE
    )
  }
  model <- fit_rf_residual_model(
    train_df = training_df,
    predictor_cols = predictor_cols,
    ntree = cfg$residual_model$ntree,
    mtry = cfg$residual_model$mtry,
    nodesize = cfg$residual_model$nodesize,
    seed = cfg$residual_model$seed
  )

  list(
    object_class = "dssat_ew_residual_model",
    object_version = "1.0",
    target = target,
    model = model,
    predictor_cols = predictor_cols,
    lambda = estimate_lambda(training_df$residual, cfg$residual_model$lambda_quantile),
    truncation = list(
      function_name = "bounded_response",
      formula = "lambda * tanh(raw_residual / lambda)",
      lambda_quantile = cfg$residual_model$lambda_quantile
    ),
    training = list(
      rows_available = nrow(residual_df),
      rows_complete = nrow(training_df),
      data_md5 = training_data_fingerprint(
        training_df,
        unique(c(id_cols, predictor_cols, "observed", "dssat", "residual"))
      ),
      ntree = cfg$residual_model$ntree,
      mtry = model$mtry,
      nodesize = cfg$residual_model$nodesize,
      seed = cfg$residual_model$seed,
      fitted_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
      r_version = R.version.string,
      randomForest_version = as.character(utils::packageVersion("randomForest"))
    )
  )
}

fit_all_residual_models <- function(feature_table,
                                    observations,
                                    cfg,
                                    targets = cfg$columns$target_variables,
                                    id_cols = c("grid_id", "year", "crop")) {
  predictor_cols <- resolve_predictor_cols(cfg, feature_table)

  models <- purrr::map(
    targets,
    ~ fit_target_residual_model(
      feature_table = feature_table,
      observations = observations,
      target = .x,
      predictor_cols = predictor_cols,
      cfg = cfg,
      id_cols = id_cols
    )
  )
  names(models) <- targets
  models
}

leave_one_out_residual_validation <- function(residual_df,
                                             predictor_cols,
                                             target,
                                             cfg) {
  residual_df <- residual_df[
    stats::complete.cases(residual_df[, c(predictor_cols, "residual"), drop = FALSE]),
    , drop = FALSE
  ]
  n <- nrow(residual_df)
  if (n < 5) stop("Too few rows for leave-one-out validation.", call. = FALSE)

  preds <- rep(NA_real_, n)
  for (i in seq_len(n)) {
    train_df <- residual_df[-i, , drop = FALSE]
    test_df <- residual_df[i, , drop = FALSE]
    model <- fit_rf_residual_model(
      train_df = train_df,
      predictor_cols = predictor_cols,
      ntree = cfg$residual_model$ntree,
      mtry = cfg$residual_model$mtry,
      nodesize = cfg$residual_model$nodesize,
      seed = cfg$residual_model$seed
    )
    lambda <- estimate_lambda(train_df$residual, cfg$residual_model$lambda_quantile)
    preds[i] <- bounded_response(predict_residual(model, test_df), lambda)
  }

  dssat_ew <- residual_df$dssat + preds
  dplyr::bind_cols(
    residual_df %>%
      dplyr::select(dplyr::any_of(c("obs_id", "grid_id", "year", "crop"))) %>%
      dplyr::mutate(
        target = target,
        observed = residual_df$observed,
        dssat = residual_df$dssat,
        residual_pred = preds,
        dssat_ew = dssat_ew
      )
  )
}

validate_all_residual_models <- function(feature_table,
                                         observations,
                                         cfg,
                                         targets = cfg$columns$target_variables,
                                         id_cols = c("grid_id", "year", "crop")) {
  predictor_cols <- resolve_predictor_cols(cfg, feature_table)

  validation <- purrr::map_dfr(targets, function(target) {
    residual_df <- make_target_residuals(feature_table, observations, target, id_cols)
    leave_one_out_residual_validation(residual_df, predictor_cols, target, cfg)
  })

  metrics <- validation %>%
    dplyr::group_by(target) %>%
    dplyr::group_modify(~ dplyr::bind_rows(
      metric_table(.x$observed, .x$dssat, paste0(.y$target, "_dssat")),
      metric_table(.x$observed, .x$dssat_ew, paste0(.y$target, "_dssat_ew"))
    )) %>%
    dplyr::ungroup()

  list(predictions = validation, metrics = metrics)
}

save_residual_model_bundle <- function(models, model_dir) {
  ensure_dir(model_dir)
  purrr::iwalk(models, function(model_obj, target) {
    saveRDS(model_obj, file.path(model_dir, paste0("dssat_ew_rf_", target, ".rds")))
  })
  files <- file.path(model_dir, paste0("dssat_ew_rf_", names(models), ".rds"))
  manifest <- dplyr::tibble(
    target = names(models),
    file = basename(files),
    sha256 = vapply(
      files,
      digest::digest,
      character(1),
      algo = "sha256",
      file = TRUE,
      serialize = FALSE
    ),
    checksum_algorithm = "SHA-256",
    object_version = vapply(models, `[[`, character(1), "object_version"),
    training_data_md5 = vapply(models, function(x) x$training$data_md5, character(1))
  )
  readr::write_csv(manifest, file.path(model_dir, "model_manifest.csv"))
  invisible(models)
}

load_residual_model_bundle <- function(model_dir, targets) {
  models <- purrr::map(targets, function(target) {
    path <- file.path(model_dir, paste0("dssat_ew_rf_", target, ".rds"))
    if (!file.exists(path)) stop("Missing trained model object: ", path, call. = FALSE)
    object <- readRDS(path)
    required <- c("target", "model", "predictor_cols", "lambda", "truncation", "training")
    missing <- setdiff(required, names(object))
    if (length(missing)) stop("Invalid model object ", path, "; missing: ", paste(missing, collapse = ", "), call. = FALSE)
    object
  })
  names(models) <- targets
  models
}
