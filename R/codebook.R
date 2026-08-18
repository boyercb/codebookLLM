#' PHI-safe, LLM-oriented code book for a data frame
#'
#' Summarises the *structure* of a data frame - variable names, classes, roles,
#' missingness, cardinality, factor levels and the shape of numeric variables -
#' in a compact, machine-parseable form intended to be pasted into a large
#' language model prompt. No row-level data is emitted, and columns whose names
#' suggest direct identifiers have their values withheld.
#'
#' Each variable is tagged with a `role`, which tells a code-writing model how
#' the column is most likely to be used:
#'
#' \describe{
#'   \item{`id`}{unique and complete discrete column; a candidate row key}
#'   \item{`binary`}{logical, or exactly two distinct observed values}
#'   \item{`categorical`}{factor with more than two levels}
#'   \item{`numeric`}{numeric / integer}
#'   \item{`date`}{`Date` or `POSIXct`}
#'   \item{`text`}{character that is not obviously categorical}
#'   \item{`constant`}{a single observed value}
#'   \item{`empty`}{no observed values}
#' }
#'
#' @section Disclosure control:
#' `detail = "safe"` (the default) reports numeric variables as a range and
#' median rounded to three significant digits and dates to month precision, and
#' lists distinct values only for low-cardinality discrete variables.
#' `detail = "structure"` omits values entirely. `detail = "full"` reports exact
#' numeric summaries and exact date ranges and should only be used when minimum
#' and maximum values are not themselves disclosive. Name-based identifier
#' redaction is applied at every detail level. The heuristic is a convenience,
#' not a guarantee: review the output before sharing it.
#'
#' @param data A data frame, tibble or data.table.
#' @param name Dataset name to print. Defaults to the deparsed `data` argument.
#' @param format Output format: `"markdown"` (default), `"yaml"` or `"json"`.
#' @param detail Level of value detail: `"safe"` (default), `"structure"` or
#'   `"full"`. See Disclosure control.
#' @param max_levels Maximum number of distinct values listed for a discrete
#'   variable. Above this, only the count is reported.
#' @param phi_extra Character vector of extra regular-expression alternatives
#'   treated as identifier-like column names.
#' @param no_redact Character vector of column names exempt from the
#'   identifier-name heuristic.
#' @param labels Optional named character vector of variable descriptions, added
#'   to each variable's notes.
#' @param file Optional path. When supplied, the code book is written there and
#'   returned invisibly.
#'
#' @return A length-one character vector of class `llm_codebook`. Returned
#'   invisibly when `file` is supplied.
#'
#' @examples
#' df <- data.frame(
#'   patient_mrn = sprintf("M%05d", 1:20),
#'   age = c(rep(c(55, 61, 70, 48), 5)),
#'   sex = factor(rep(c("F", "M"), 10)),
#'   visit_date = as.Date("2020-01-01") + 1:20
#' )
#' llm_codebook(df)
#' llm_codebook(df, format = "yaml", detail = "structure")
#'
#' @export
llm_codebook <- function(data,
                         name = deparse(substitute(data)),
                         format = c("markdown", "yaml", "json"),
                         detail = c("safe", "structure", "full"),
                         max_levels = 12L,
                         phi_extra = NULL,
                         no_redact = character(0),
                         labels = NULL,
                         file = NULL) {
  if (!is.data.frame(data)) stop("`data` must be a data.frame / tibble.")
  format <- match.arg(format)
  detail <- match.arg(detail)
  n <- nrow(data)

  cols <- lapply(names(data), function(nm) {
    cb_profile_col(data[[nm]], nm, n, detail, max_levels, phi_extra, no_redact)
  })

  if (!is.null(labels)) {
    cols <- lapply(cols, function(col) {
      if (col$name %in% names(labels) && !is.na(labels[[col$name]])) {
        col$note <- c(sprintf("label: %s", labels[[col$name]]), col$note)
      }
      col
    })
  }

  complete_rows <- sum(stats::complete.cases(data))
  keys <- vapply(cols, function(col) col$role == "id", logical(1))

  notes <- if (any(keys)) {
    sprintf("candidate row identifier(s): %s",
            paste(vapply(cols[keys], function(col) col$name, character(1)), collapse = ", "))
  } else {
    "no single column uniquely identifies a row"
  }
  dup <- if (n) sum(duplicated(data)) else 0L
  if (dup) notes <- c(notes, sprintf("%d duplicated row(s)", dup))
  if (complete_rows < n) {
    notes <- c(notes, sprintf("%d row(s) have at least one missing value", n - complete_rows))
  }
  notes <- c(
    notes,
    "values shown are aggregate metadata only; no row-level data is included",
    "columns whose names suggest direct identifiers have their values redacted"
  )

  meta <- list(name = name, nrow = n, ncol = ncol(data), class = cb_class(data),
               complete_rows = complete_rows, detail = detail)

  txt <- switch(format,
                markdown = cb_emit_markdown(meta, cols, notes),
                yaml = cb_emit_yaml(meta, cols, notes),
                json = cb_emit_json(meta, cols, notes))
  class(txt) <- c("llm_codebook", "character")

  if (!is.null(file)) {
    writeLines(as.character(txt), file)
    return(invisible(txt))
  }
  txt
}

#' Print a code book
#'
#' @param x An `llm_codebook` object.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.llm_codebook <- function(x, ...) {
  cat(as.character(x), "\n", sep = "")
  invisible(x)
}
