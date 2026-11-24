#' Column-name pattern for likely direct identifiers
#'
#' Alternation regex matched (case-insensitively) against column names. Columns
#' whose names match have their values withheld from the code book. Loosely
#' follows the 18 HIPAA direct identifiers.
#'
#' @keywords internal
#' @noRd
cb_phi_pattern <- paste(
  "mrn", "medrec", "ssn", "social", "dob", "birth", "name",
  "addr", "street", "city", "zip", "postal", "phone", "fax", "email",
  "account", "acct", "license", "certificate", "vin", "device", "url", "\\bip\\b",
  "biometric", "photo", "patient", "subject", "\\bid\\b", "_id", "id_",
  sep = "|"
)

#' @keywords internal
#' @noRd
cb_is_phi_name <- function(nm, extra = NULL) {
  pat <- if (length(extra)) paste(c(cb_phi_pattern, extra), collapse = "|") else cb_phi_pattern
  grepl(pat, tolower(nm))
}

#' @keywords internal
#' @noRd
cb_class <- function(x) paste(class(x), collapse = "/")

#' @keywords internal
#' @noRd
cb_looks_numeric <- function(x) {
  v <- x[!is.na(x) & nzchar(trimws(x))]
  if (!length(v)) return(FALSE)
  v <- utils::head(v, 1000L)
  all(!is.na(suppressWarnings(as.numeric(v))))
}

#' @keywords internal
#' @noRd
cb_looks_date <- function(x) {
  v <- x[!is.na(x) & nzchar(trimws(x))]
  if (!length(v)) return(FALSE)
  v <- utils::head(v, 1000L)
  all(grepl("^\\d{4}-\\d{2}-\\d{2}", v)) ||
    all(grepl("^\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}$", v))
}

#' @keywords internal
#' @noRd
cb_role <- function(x, n_distinct, n_nonmiss) {
  if (n_nonmiss == 0L) return("empty")
  if (n_distinct <= 1L) return("constant")
  if (inherits(x, c("Date", "POSIXct", "POSIXt"))) return("date")
  if (is.logical(x)) return("binary")
  if (n_distinct == 2L) return("binary")
  if (is.factor(x)) return("categorical")
  if (is.numeric(x)) return("numeric")
  if (is.character(x)) return("text")
  "other"
}

#' @keywords internal
#' @noRd
cb_num_summary <- function(x, detail) {
  v <- x[is.finite(x)]
  if (!length(v)) return(NA_character_)
  if (inherits(v, "integer64")) v <- as.double(v)
  q <- stats::quantile(v, c(0, .25, .5, .75, 1), names = FALSE, type = 7)
  if (identical(detail, "full")) {
    sprintf("min=%s q25=%s median=%s q75=%s max=%s mean=%s sd=%s",
            format(q[1]), format(q[2]), format(q[3]), format(q[4]), format(q[5]),
            format(signif(mean(v), 4)), format(signif(stats::sd(v), 4)))
  } else {
    # rounded to 3 significant digits: shape without reproducible values
    sprintf("~range=[%s, %s] ~median=%s",
            format(signif(q[1], 3)), format(signif(q[5], 3)), format(signif(q[3], 3)))
  }
}

#' @keywords internal
#' @noRd
cb_date_summary <- function(x, detail) {
  v <- x[!is.na(x)]
  if (!length(v)) return(NA_character_)
  fmt <- if (identical(detail, "full")) "%Y-%m-%d" else "%Y-%m"
  sprintf("range=[%s, %s]", format(min(v), fmt), format(max(v), fmt))
}

#' @keywords internal
#' @noRd
cb_levels <- function(x, max_levels, redacted) {
  if (redacted) return("<redacted: possible identifier>")
  lv <- if (is.factor(x)) levels(x) else sort(unique(x[!is.na(x)]))
  if (!length(lv)) return(NA_character_)
  if (length(lv) > max_levels) {
    return(sprintf("<%d distinct values, not listed>", length(lv)))
  }
  paste0("[", paste(sprintf('"%s"', as.character(lv)), collapse = ", "), "]")
}

#' Profile a single column
#'
#' @return A list with `name`, `class`, `role`, `n_missing`, `pct_missing`,
#'   `n_distinct`, `values` and `note`.
#' @keywords internal
#' @noRd
cb_profile_col <- function(x, nm, n, detail, max_levels, phi_extra, no_redact) {
  n_miss <- sum(is.na(x))
  n_nonmiss <- n - n_miss
  n_distinct <- length(unique(x[!is.na(x)]))
  redacted <- !(nm %in% no_redact) && cb_is_phi_name(nm, phi_extra)
  role <- cb_role(x, n_distinct, n_nonmiss)

  unique_per_row <- role != "empty" && n_distinct == n && n_miss == 0L && n > 1L
  if (unique_per_row && (is.character(x) || is.factor(x) || is.integer(x))) role <- "id"

  out <- list(
    name = nm,
    class = cb_class(x),
    role = role,
    n_missing = n_miss,
    pct_missing = if (n) round(100 * n_miss / n, 1) else NA_real_,
    n_distinct = n_distinct,
    values = NA_character_,
    note = character(0)
  )

  if (!identical(detail, "structure") && role != "empty") {
    out$values <- switch(
      role,
      id = "<unique identifier: values withheld>",
      date = if (redacted) "<redacted: possible identifier>" else cb_date_summary(x, detail),
      numeric = if (redacted) "<redacted: possible identifier>" else cb_num_summary(x, detail),
      binary = cb_levels(x, max_levels, redacted),
      constant = cb_levels(x, max_levels, redacted),
      categorical = cb_levels(x, max_levels, redacted),
      text = cb_levels(x, max_levels, redacted),
      NA_character_
    )
  }

  # gotchas a code-writing model would otherwise trip on
  if (is.character(x) && cb_looks_numeric(x)) {
    out$note <- c(out$note, "numeric values stored as character")
  }
  if (is.character(x) && cb_looks_date(x)) {
    out$note <- c(out$note, "dates stored as character")
  }
  if (is.factor(x) && length(setdiff(levels(x), unique(as.character(x))))) {
    out$note <- c(out$note, "has unused factor levels")
  }
  if (is.factor(x) && is.ordered(x)) {
    out$note <- c(out$note, "ordered factor")
  }
  if (role == "numeric" && n_distinct <= 10L) {
    out$note <- c(out$note, sprintf("only %d distinct values; may be categorical", n_distinct))
  }
  if (unique_per_row && out$role != "id") {
    out$note <- c(out$note, "unique in every row")
  }
  if (n_miss == n && n > 0L) {
    out$note <- c(out$note, "entirely missing")
  }
  if (redacted) {
    out$note <- c(out$note, "flagged as possible direct identifier")
  }
  out
}
