# codebookLLM (development version)

* Added `llm_codebook()`, which summarises a data frame's structure as markdown,
  YAML or JSON without emitting row-level data.
* Value detail is controlled by `detail = c("safe", "structure", "full")`, and
  columns with identifier-like names are redacted at every detail level.
