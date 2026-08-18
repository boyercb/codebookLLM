# codebookLLM

Compact, machine-parseable code books for data frames, designed to be pasted
into a large language model prompt so the model can write correct code against a
dataset **without ever seeing row-level data**.

Human-facing codebook packages optimise for readability. `codebookLLM` optimises
for a model that is about to write `dplyr`, `ggplot2` or modelling code: one
line per variable, explicit role tags, and a short list of gotchas (numbers
stored as text, unused factor levels, candidate primary keys, duplicate rows).

## Installation

```r
# install.packages("pak")
pak::pak("codebookLLM")
```

## Usage

```r
library(codebookLLM)

df <- data.frame(
  patient_mrn = sprintf("M%05d", 1:20),
  age = rep(c(55, 61, 70, 48), 5),
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
```

Other formats and detail levels:

```r
llm_codebook(df, format = "yaml")                    # terse, prompt-friendly
llm_codebook(df, format = "json")
llm_codebook(df, detail = "structure")               # types and missingness only
llm_codebook(df, detail = "full")                    # exact numeric summaries
llm_codebook(df, file = "codebook.md")               # write to disk
llm_codebook(df, labels = c(age = "Age at surgery")) # attach descriptions
```

## Disclosure control

- `detail = "safe"` (default): numeric variables are reported as a range and
  median rounded to three significant digits, dates to month precision, and
  distinct values are listed only for low-cardinality discrete variables
  (`max_levels`).
- `detail = "structure"`: no values at all - classes, missingness and
  cardinality only.
- `detail = "full"`: exact numeric summaries and date ranges. Use only when
  minimum and maximum values are not themselves disclosive.
- Columns whose names suggest direct identifiers (MRN, SSN, DOB, name, address,
  phone, email, ZIP, account, `*_id`, ...) have their values withheld at every
  detail level. Tune with `phi_extra` and `no_redact`.

The identifier heuristic is a convenience, not a guarantee. Review the generated
code book before sharing it, and follow your institution's policy on what may be
sent to an external model.

## License

MIT
