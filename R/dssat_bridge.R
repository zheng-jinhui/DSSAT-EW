# Helpers for DSSAT output standardization and greenhouse-gas conversion.

standardize_dssat_outputs <- function(dssat_outputs) {
  rename_map <- c(
    HWAM = "yield_dssat",
    N2OEM = "n2o_dssat",
    CH4EM = "ch4_dssat",
    LAIH = "lai_dssat",
    SWM = "soil_moisture_dssat",
    NIAM = "soil_n_dssat"
  )

  available <- intersect(names(rename_map), names(dssat_outputs))
  out <- dssat_outputs
  names(out)[match(available, names(out))] <- rename_map[available]
  out
}

convert_ch4_c_to_ch4 <- function(ch4_c_kg_ha) {
  ch4_c_kg_ha * 16 / 12
}

convert_n2o_n_to_n2o <- function(n2o_n_kg_ha) {
  n2o_n_kg_ha * 44 / 28
}

add_ghg_co2e <- function(df,
                         ch4_col = "ch4_dssat",
                         n2o_col = "n2o_dssat",
                         ch4_is_carbon = FALSE,
                         n2o_is_nitrogen = FALSE,
                         gwp_ch4 = 27,
                         gwp_n2o = 273,
                         out_col = "ghg_dssat_co2e") {
  ch4 <- df[[ch4_col]]
  n2o <- df[[n2o_col]]
  if (ch4_is_carbon) ch4 <- convert_ch4_c_to_ch4(ch4)
  if (n2o_is_nitrogen) n2o <- convert_n2o_n_to_n2o(n2o)

  df[[out_col]] <- ch4 * gwp_ch4 + n2o * gwp_n2o
  df
}

assemble_feature_table <- function(dssat_outputs,
                                   exposure_features,
                                   climate_background,
                                   id_cols = c("grid_id", "year", "crop", "esm", "ssp", "treatment")) {
  exposure_join_cols <- Reduce(intersect, list(id_cols, names(dssat_outputs), names(exposure_features)))
  climate_join_cols <- Reduce(intersect, list(id_cols, names(dssat_outputs), names(climate_background)))

  if (length(exposure_join_cols) == 0) {
    stop("No common identifier columns found between DSSAT outputs and exposure features.", call. = FALSE)
  }
  if (length(climate_join_cols) == 0) {
    stop("No common identifier columns found between DSSAT outputs and climate background.", call. = FALSE)
  }

  dssat_outputs %>%
    dplyr::left_join(exposure_features, by = exposure_join_cols) %>%
    dplyr::left_join(climate_background, by = climate_join_cols)
}

make_target_residuals <- function(feature_table,
                                  observations,
                                  target,
                                  id_cols = c("grid_id", "year", "crop")) {
  obs_col <- paste0(target, "_obs")
  dssat_col <- paste0(target, "_dssat")
  assert_columns(feature_table, c(id_cols, dssat_col), "feature_table")
  assert_columns(observations, c(id_cols, obs_col), "observations")

  feature_table %>%
    dplyr::left_join(observations, by = id_cols) %>%
    dplyr::mutate(
      target = target,
      observed = .data[[obs_col]],
      dssat = .data[[dssat_col]],
      residual = observed - dssat
    ) %>%
    dplyr::filter(is.finite(residual))
}
