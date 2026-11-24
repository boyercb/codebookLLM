# PHI-safe, LLM-oriented code book for a data frame

Summarises the *structure* of a data frame - variable names, classes,
roles, missingness, cardinality, factor levels and the shape of numeric
variables - in a compact, machine-parseable form intended to be pasted
into a large language model prompt. No row-level data is emitted, and
columns whose names suggest direct identifiers have their values
withheld.

## Usage

``` r
llm_codebook(
  data,
  name = deparse(substitute(data)),
  format = c("markdown", "yaml", "json"),
  detail = c("safe", "structure", "full"),
  max_levels = 12L,
  phi_extra = NULL,
  no_redact = character(0),
  labels = NULL,
  file = NULL
)
```

## Arguments

- data:

  A data frame, tibble or data.table.

- name:

  Dataset name to print. Defaults to the deparsed `data` argument.

- format:

  Output format: `"markdown"` (default), `"yaml"` or `"json"`.

- detail:

  Level of value detail: `"safe"` (default), `"structure"` or `"full"`.
  See Disclosure control.

- max_levels:

  Maximum number of distinct values listed for a discrete variable.
  Above this, only the count is reported.

- phi_extra:

  Character vector of extra regular-expression alternatives treated as
  identifier-like column names.

- no_redact:

  Character vector of column names exempt from the identifier-name
  heuristic.

- labels:

  Optional named character vector of variable descriptions, added to
  each variable's notes.

- file:

  Optional path. When supplied, the code book is written there and
  returned invisibly.

## Value

A length-one character vector of class `llm_codebook`. Returned
invisibly when `file` is supplied.

## Details

Each variable is tagged with a `role`, which tells a code-writing model
how the column is most likely to be used:

- `id`:

  unique and complete discrete column; a candidate row key

- `binary`:

  logical, or exactly two distinct observed values

- `categorical`:

  factor with more than two levels

- `numeric`:

  numeric / integer

- `date`:

  `Date` or `POSIXct`

- `text`:

  character that is not obviously categorical

- `constant`:

  a single observed value

- `empty`:

  no observed values

## Disclosure control

`detail = "safe"` (the default) reports numeric variables as a range and
median rounded to three significant digits and dates to month precision,
and lists distinct values only for low-cardinality discrete variables.
`detail = "structure"` omits values entirely. `detail = "full"` reports
exact numeric summaries and exact date ranges and should only be used
when minimum and maximum values are not themselves disclosive.
Name-based identifier redaction is applied at every detail level. The
heuristic is a convenience, not a guarantee: review the output before
sharing it.

## Integer64 columns

[`bit64::integer64`](https://bit64.r-lib.org/reference/bit64-package.html)
columns, commonly imported from Parquet, are converted to double
precision only for numeric summaries. The input data and reported column
classes are unchanged. Integers outside the exactly representable range
of doubles (approximately +/-2^53) may lose precision, even with
`detail = "full"`; the conversion emits a warning in that case.

## Examples

``` r
df <- data.frame(
  patient_mrn = sprintf("M%05d", 1:20),
  age = c(rep(c(55, 61, 70, 48), 5)),
  sex = factor(rep(c("F", "M"), 10)),
  visit_date = as.Date("2020-01-01") + 1:20
)
llm_codebook(df)
#> # Codebook: df
#> 
#> - rows: 20
#> - columns: 4
#> - class: data.frame
#> - complete rows: 20 (100.0%)
#> - detail level: safe (row-level data withheld)
#> 
#> ## Variables
#> 
#> | variable | class | role | n_missing | %missing | n_distinct | values / summary | notes |
#> |---|---|---|---:|---:|---:|---|---|
#> | `patient_mrn` | character | id | 0 | 0 | 20 | <unique identifier: values withheld> | flagged as possible direct identifier |
#> | `age` | numeric | numeric | 0 | 0 | 4 | ~range=[48, 70] ~median=58 | only 4 distinct values; may be categorical |
#> | `sex` | factor | binary | 0 | 0 | 2 | ["F", "M"] |  |
#> | `visit_date` | Date | date | 0 | 0 | 20 | range=[2020-01, 2020-01] | unique in every row |
#> 
#> ## Dataset notes
#> 
#> - candidate row identifier(s): patient_mrn
#> - values shown are aggregate metadata only; no row-level data is included
#> - columns whose names suggest direct identifiers have their values redacted
llm_codebook(df, format = "yaml", detail = "structure")
#> dataset: "df"
#> rows: 20
#> columns: 4
#> class: "data.frame"
#> complete_rows: 20
#> detail: "structure"
#> variables:
#>   - name: "patient_mrn"
#>     class: "character"
#>     role: "id"
#>     n_missing: 0
#>     pct_missing: 0
#>     n_distinct: 20
#>     values: null
#>     notes:
#>       - "flagged as possible direct identifier"
#>   - name: "age"
#>     class: "numeric"
#>     role: "numeric"
#>     n_missing: 0
#>     pct_missing: 0
#>     n_distinct: 4
#>     values: null
#>     notes:
#>       - "only 4 distinct values; may be categorical"
#>   - name: "sex"
#>     class: "factor"
#>     role: "binary"
#>     n_missing: 0
#>     pct_missing: 0
#>     n_distinct: 2
#>     values: null
#>   - name: "visit_date"
#>     class: "Date"
#>     role: "date"
#>     n_missing: 0
#>     pct_missing: 0
#>     n_distinct: 20
#>     values: null
#>     notes:
#>       - "unique in every row"
#> dataset_notes:
#>   - "candidate row identifier(s): patient_mrn"
#>   - "values shown are aggregate metadata only; no row-level data is included"
#>   - "columns whose names suggest direct identifiers have their values redacted"
```
