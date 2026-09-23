///|
/// Backward checks the old schema against the new schema; forward checks the
/// reverse direction; full requires both directions to pass.
pub(all) enum CompatibilityPolicy {
  Backward
  Forward
  Full
} derive(Debug, Eq)

///|
/// Direction in which a schema pair was compared.
pub(all) enum CompatibilityDirection {
  BackwardDirection
  ForwardDirection
} derive(Debug, Eq)

///|
/// A schema-evolution finding with its source file and comparison direction.
pub(all) struct CompatibilityFinding {
  source : String
  direction : CompatibilityDirection
  change : SchemaChange
} derive(Debug, Eq)

///|
pub(all) enum CompatibilityFormat {
  Text
  JsonFormat
  Markdown
  GithubAnnotations
} derive(Debug, Eq)

///|
pub fn CompatibilityPolicy::name(self : CompatibilityPolicy) -> String {
  match self {
    Backward => "backward"
    Forward => "forward"
    Full => "full"
  }
}

///|
pub fn CompatibilityDirection::name(self : CompatibilityDirection) -> String {
  match self {
    BackwardDirection => "backward"
    ForwardDirection => "forward"
  }
}

///|
fn ChangeKind::name(self : ChangeKind) -> String {
  match self {
    Compatible => "compatible"
    Warning => "warning"
    Breaking => "breaking"
  }
}

///|
/// Applies an existing directional schema comparison in the selected policy.
/// Findings keep their original MTHC codes and are ordered backward first,
/// then forward. Suppression codes are exact matches (for example MTHC105).
pub fn compare_schemas_with_policy(
  before : Schema,
  after : Schema,
  policy : CompatibilityPolicy,
  source? : String = "",
  suppressed? : Array[String] = [],
) -> Array[CompatibilityFinding] {
  let findings : Array[CompatibilityFinding] = []
  if policy is Backward || policy is Full {
    for item in compare_schemas(before, after) {
      if !suppressed.contains(item.code) {
        findings.push({ source, direction: BackwardDirection, change: item, })
      }
    }
  }
  if policy is Forward || policy is Full {
    for item in compare_schemas(after, before) {
      if !suppressed.contains(item.code) {
        findings.push({ source, direction: ForwardDirection, change: item, })
      }
    }
  }
  findings
}

///|
pub fn has_blocking_compatibility_findings(
  findings : ArrayView[CompatibilityFinding],
) -> Bool {
  findings.any(item => item.change.kind is Breaking)
}

///|
fn json_quote(value : String) -> String {
  Json::string(value).stringify()
}

///|
fn markdown_cell(value : String) -> String {
  value
  .replace_all(old="|", new="\\|")
  .replace_all(old="\r", new=" ")
  .replace_all(old="\n", new=" ")
}

///|
fn annotation_escape(value : String) -> String {
  value
  .replace_all(old="%", new="%25")
  .replace_all(old="\r", new="%0D")
  .replace_all(old="\n", new="%0A")
}

///|
fn annotation_property(value : String) -> String {
  annotation_escape(value).replace_all(old=",", new="%2C")
}

///|
/// Renders deterministic machine or human output. Sources are logical schema
/// paths; GitHub annotations intentionally omit line numbers because findings
/// can describe a removed symbol that has no line in the new file.
pub fn render_compatibility_report(
  findings : ArrayView[CompatibilityFinding],
  policy : CompatibilityPolicy,
  format : CompatibilityFormat,
) -> String {
  let blocked = has_blocking_compatibility_findings(findings)
  match format {
    Text => {
      let lines : Array[String] = []
      for finding in findings {
        let prefix = if finding.source == "" {
          ""
        } else {
          "\{finding.source}: "
        }
        lines.push(
          "\{prefix}\{finding.direction.name()}: \{finding.change.to_text()}",
        )
      }
      lines.push(
        "\{policy.name()}: \{if blocked { "blocked" } else { "passed" }} (\{findings.length()} finding(s))",
      )
      lines.join("\n")
    }
    JsonFormat => {
      let entries : Array[String] = []
      for finding in findings {
        let item = finding.change
        entries.push(
          "{\"direction\":\{json_quote(finding.direction.name())},\"source\":\{json_quote(finding.source)},\"code\":\{json_quote(item.code)},\"kind\":\{json_quote(item.kind.name())},\"path\":\{json_quote(item.path)},\"message\":\{json_quote(item.message)}}",
        )
      }
      "{\"policy\":\{json_quote(policy.name())},\"blocked\":\{if blocked { "true" } else { "false" }},\"findings\":[\{entries.join(",")}]}"
    }
    Markdown => {
      let lines : Array[String] = [
        "## MoonThrift compatibility: \{policy.name()} \{if blocked { "blocked" } else { "passed" }}",
        "",
        "| Source | Direction | Severity | Rule | Symbol | Detail |",
        "| --- | --- | --- | --- | --- | --- |",
      ]
      for finding in findings {
        let item = finding.change
        lines.push(
          "| \{markdown_cell(finding.source)} | \{finding.direction.name()} | \{item.kind.name()} | \{item.code} | \{markdown_cell(item.path)} | \{markdown_cell(item.message)} |",
        )
      }
      if findings.is_empty() {
        lines.push("| — | — | — | — | — | No changes detected |")
      }
      lines.join("\n")
    }
    GithubAnnotations => {
      let lines : Array[String] = []
      for finding in findings {
        let item = finding.change
        let level = match item.kind {
          Breaking => "error"
          Warning => "warning"
          Compatible => "notice"
        }
        let file_property = if finding.source == "" {
          ""
        } else {
          "file=\{annotation_property(finding.source)},"
        }
        lines.push(
          "::\{level} \{file_property}title=\{item.code}::\{annotation_escape("\{finding.direction.name()} \{item.path}: \{item.message}")}",
        )
      }
      lines.join("\n")
    }
  }
}
