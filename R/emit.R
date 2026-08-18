#' @keywords internal
#' @noRd
cb_esc_md <- function(x) gsub("|", "\\|", x, fixed = TRUE)

#' @keywords internal
#' @noRd
cb_emit_markdown <- function(meta, cols, notes) {
  hdr <- c(
    sprintf("# Codebook: %s", meta$name),
    "",
    sprintf("- rows: %d", meta$nrow),
    sprintf("- columns: %d", meta$ncol),
    sprintf("- class: %s", meta$class),
    sprintf("- complete rows: %d (%.1f%%)", meta$complete_rows,
            if (meta$nrow) 100 * meta$complete_rows / meta$nrow else NA_real_),
    sprintf("- detail level: %s (row-level data withheld)", meta$detail),
    "",
    "## Variables",
    "",
    "| variable | class | role | n_missing | %missing | n_distinct | values / summary | notes |",
    "|---|---|---|---:|---:|---:|---|---|"
  )
  rows <- vapply(cols, function(col) sprintf(
    "| `%s` | %s | %s | %d | %s | %d | %s | %s |",
    col$name, col$class, col$role, col$n_missing,
    if (is.na(col$pct_missing)) "" else format(col$pct_missing),
    col$n_distinct,
    cb_esc_md(if (is.na(col$values)) "" else col$values),
    cb_esc_md(paste(col$note, collapse = "; "))
  ), character(1))
  body <- c(hdr, rows)
  if (length(notes)) body <- c(body, "", "## Dataset notes", "", paste0("- ", notes))
  paste(body, collapse = "\n")
}

#' @keywords internal
#' @noRd
cb_yaml_scalar <- function(x) {
  if (is.na(x)) return("null")
  if (is.numeric(x)) return(format(x))
  sprintf('"%s"', gsub('"', '\\\\"', x))
}

#' @keywords internal
#' @noRd
cb_emit_yaml <- function(meta, cols, notes) {
  out <- c(
    sprintf("dataset: %s", cb_yaml_scalar(meta$name)),
    sprintf("rows: %d", meta$nrow),
    sprintf("columns: %d", meta$ncol),
    sprintf("class: %s", cb_yaml_scalar(meta$class)),
    sprintf("complete_rows: %d", meta$complete_rows),
    sprintf("detail: %s", cb_yaml_scalar(meta$detail)),
    "variables:"
  )
  for (col in cols) {
    out <- c(
      out,
      sprintf("  - name: %s", cb_yaml_scalar(col$name)),
      sprintf("    class: %s", cb_yaml_scalar(col$class)),
      sprintf("    role: %s", cb_yaml_scalar(col$role)),
      sprintf("    n_missing: %d", col$n_missing),
      sprintf("    pct_missing: %s", cb_yaml_scalar(col$pct_missing)),
      sprintf("    n_distinct: %d", col$n_distinct),
      sprintf("    values: %s", cb_yaml_scalar(col$values))
    )
    if (length(col$note)) {
      out <- c(out, "    notes:",
               paste0("      - ", vapply(col$note, cb_yaml_scalar, character(1))))
    }
  }
  if (length(notes)) {
    out <- c(out, "dataset_notes:",
             paste0("  - ", vapply(notes, cb_yaml_scalar, character(1))))
  }
  paste(out, collapse = "\n")
}

#' @keywords internal
#' @noRd
cb_json_scalar <- function(x) {
  if (is.na(x)) return("null")
  if (is.numeric(x)) return(format(x, scientific = FALSE, trim = TRUE))
  sprintf('"%s"', gsub('"', '\\\\"', gsub("\\\\", "\\\\\\\\", x)))
}

#' @keywords internal
#' @noRd
cb_emit_json <- function(meta, cols, notes) {
  var_json <- vapply(cols, function(col) paste0(
    "    {",
    paste(sprintf(
      '"%s": %s',
      c("name", "class", "role", "n_missing", "pct_missing", "n_distinct", "values"),
      vapply(
        list(col$name, col$class, col$role, col$n_missing,
             col$pct_missing, col$n_distinct, col$values),
        cb_json_scalar, character(1)
      )
    ), collapse = ", "),
    sprintf(', "notes": [%s]',
            paste(vapply(col$note, cb_json_scalar, character(1)), collapse = ", ")),
    "}"
  ), character(1))

  paste0(
    "{\n",
    sprintf('  "dataset": %s,\n', cb_json_scalar(meta$name)),
    sprintf('  "rows": %d,\n  "columns": %d,\n', meta$nrow, meta$ncol),
    sprintf('  "class": %s,\n', cb_json_scalar(meta$class)),
    sprintf('  "complete_rows": %d,\n', meta$complete_rows),
    sprintf('  "detail": %s,\n', cb_json_scalar(meta$detail)),
    '  "variables": [\n', paste(var_json, collapse = ",\n"), "\n  ],\n",
    sprintf('  "dataset_notes": [%s]\n',
            paste(vapply(notes, cb_json_scalar, character(1)), collapse = ", ")),
    "}"
  )
}
