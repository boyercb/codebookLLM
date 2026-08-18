make_df <- function() {
  set.seed(42)
  data.frame(
    patient_mrn = sprintf("M%05d", 1:20),
    age = c(NA, rep(c(55, 61, 70, 48, 66), 3), 52, 59, 63, 71),
    sex = factor(rep(c("F", "M"), 10)),
    grade = factor(rep(c("I", "II", "III", "I"), 5),
                   levels = c("I", "II", "III", "IV"), ordered = TRUE),
    died = rep(c(TRUE, FALSE), 10),
    visit_date = as.Date("2020-01-01") + 1:20,
    lab_text = as.character(seq(1.5, 21, by = 1)),
    site = "CCF",
    stringsAsFactors = FALSE
  )
}

test_that("output is a single string of class llm_codebook", {
  cb <- llm_codebook(make_df())
  expect_s3_class(cb, "llm_codebook")
  expect_length(cb, 1L)
  expect_match(cb, "# Codebook", fixed = TRUE)
})

test_that("no row-level values leak for identifier-named columns", {
  df <- make_df()
  cb <- as.character(llm_codebook(df))
  expect_false(grepl(df$patient_mrn[1], cb, fixed = TRUE))
  expect_match(cb, "values withheld")
})

test_that("detail = 'structure' emits no values at all", {
  cb <- as.character(llm_codebook(make_df(), detail = "structure"))
  expect_false(grepl("CCF", cb, fixed = TRUE))
  expect_false(grepl("range=", cb, fixed = TRUE))
})

test_that("safe detail rounds numeric summaries and dates", {
  df <- data.frame(x = c(1.23456, 987.6543, 55.5))
  cb <- as.character(llm_codebook(df, detail = "safe"))
  expect_match(cb, "~range=", fixed = TRUE)
  expect_false(grepl("987.6543", cb, fixed = TRUE))

  cb_full <- as.character(llm_codebook(df, detail = "full"))
  expect_match(cb_full, "987.6543", fixed = TRUE)
})

test_that("roles are assigned as expected", {
  cb <- as.character(llm_codebook(make_df(), format = "yaml"))
  expect_match(cb, 'name: "sex"\n    class: "factor"\n    role: "binary"')
  expect_match(cb, 'name: "grade"\n(.|\n)*role: "categorical"')
  expect_match(cb, 'name: "site"\n(.|\n)*role: "constant"')
  expect_match(cb, 'name: "visit_date"\n(.|\n)*role: "date"')
  expect_match(cb, 'name: "patient_mrn"\n(.|\n)*role: "id"')
})

test_that("gotcha notes are flagged", {
  cb <- as.character(llm_codebook(make_df()))
  expect_match(cb, "numeric values stored as character", fixed = TRUE)
  expect_match(cb, "has unused factor levels", fixed = TRUE)
  expect_match(cb, "ordered factor", fixed = TRUE)
})

test_that("max_levels suppresses long value lists", {
  df <- data.frame(g = rep(letters[1:20], 2), stringsAsFactors = FALSE)
  cb <- as.character(llm_codebook(df, max_levels = 5))
  expect_false(grepl('"q"', cb, fixed = TRUE))
  expect_match(cb, "distinct values, not listed", fixed = TRUE)
})

test_that("no_redact and phi_extra adjust the identifier heuristic", {
  df <- data.frame(patient_group = factor(c("a", "b", "a", "b")),
                   ward = factor(c("n", "s", "n", "s")))
  expect_match(as.character(llm_codebook(df)), "redacted")
  expect_false(grepl("redacted: possible identifier",
                     as.character(llm_codebook(df, no_redact = "patient_group")),
                     fixed = TRUE))
  expect_match(as.character(llm_codebook(df, no_redact = "patient_group",
                                         phi_extra = "ward")),
               "redacted")
})

test_that("labels are attached to notes", {
  cb <- as.character(llm_codebook(make_df(), labels = c(age = "Age at surgery, years")))
  expect_match(cb, "label: Age at surgery, years", fixed = TRUE)
})

test_that("all formats are produced and file writing works", {
  df <- make_df()
  expect_match(as.character(llm_codebook(df, format = "json")), '"variables"', fixed = TRUE)
  expect_match(as.character(llm_codebook(df, format = "yaml")), "variables:", fixed = TRUE)

  path <- withr::local_tempfile(fileext = ".md")
  out <- llm_codebook(df, file = path)
  expect_true(file.exists(path))
  expect_identical(paste(readLines(path), collapse = "\n"), as.character(out))
})

test_that("edge cases do not error", {
  expect_error(llm_codebook(1:10), "data.frame")
  expect_s3_class(llm_codebook(data.frame()), "llm_codebook")
  expect_match(as.character(llm_codebook(data.frame(x = c(NA, NA)))), "entirely missing")
  dup <- data.frame(a = c(1, 1), b = c(2, 2))
  expect_match(as.character(llm_codebook(dup)), "duplicated row")
})
