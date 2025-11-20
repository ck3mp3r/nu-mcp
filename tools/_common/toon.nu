# TOON (Token-Oriented Object Notation) encoder for Nushell
# Based on official TOON specification v2.0: https://github.com/toon-format/spec
# Reduces token usage by 30-60% compared to JSON for LLM interactions

# Check if TOON encoding is enabled via MCP_TOON environment variable
export def is-toon-enabled [] {
  ($env.MCP_TOON? | default "false") == "true"
}

# Smart output: TOON if enabled, JSON otherwise
# Usage: $data | to-output
export def to-output [] {
  let input = $in

  if (is-toon-enabled) {
    $input | to toon
  } else {
    $input | to json --indent 2
  }
}

# Escape string value according to TOON spec (Section 7.1)
def escape-string [value: string] {
  $value
  | str replace --all '\\' '\\\\'
  | str replace --all '"' '\\"'
  | str replace --all (char newline) '\\n'
  | str replace --all (char cr) '\\r'
  | str replace --all (char tab) '\\t'
}

# Check if string needs quoting according to TOON spec (Section 7.2)
# Uses document delimiter (comma) for quoting decisions
def needs-quoting [value: string] {
  # Empty string
  if ($value | is-empty) {
    return true
  }

  # Leading or trailing whitespace
  let trimmed = ($value | str trim)
  if $trimmed != $value {
    return true
  }

  # Reserved literals (case-sensitive)
  if $value in ["true" "false" "null"] {
    return true
  }

  # Numeric-like patterns
  # Matches: -?\d+(?:\.\d+)?(?:e[+-]?\d+)?
  # Or leading-zero decimals: 0\d+
  if ($value =~ '^-?\d+(\.\d+)?([eE][+-]?\d+)?$') {
    return true
  }
  if ($value =~ '^0\d+$') {
    return true
  }

  # Structural characters
  if ($value | str contains ':') { return true }
  if ($value | str contains '"') { return true }
  if ($value | str contains '\\') { return true }
  if ($value | str contains '[') { return true }
  if ($value | str contains ']') { return true }
  if ($value | str contains '{') { return true }
  if ($value | str contains '}') { return true }

  # Control characters (newline, CR, tab)
  if ($value | str contains (char newline)) { return true }
  if ($value | str contains (char cr)) { return true }
  if ($value | str contains (char tab)) { return true }

  # Document delimiter (comma for now)
  if ($value | str contains ',') { return true }

  # Hyphen at start or standalone hyphen
  if $value == '-' { return true }
  if ($value | str starts-with '-') { return true }

  false
}

# Format primitive value according to TOON spec
def format-primitive [value: any] {
  let value_type = ($value | describe)

  match $value_type {
    "string" => {
      if (needs-quoting $value) {
        $'"(escape-string $value)"'
      } else {
        $value
      }
    }
    "bool" => {
      if $value { "true" } else { "false" }
    }
    "int" | "float" => {
      # Canonical number format (Section 2)
      # Nushell's default into string should be close enough
      # but we need to handle -0
      if $value == 0 {
        "0"
      } else {
        $value | into string
      }
    }
    "nothing" => {
      "null"
    }
    _ => {
      # Fallback to string representation
      $value | into string
    }
  }
}

# Check if a value is primitive
def is-primitive [value: any] {
  let t = ($value | describe)
  $t in ["string" "bool" "int" "float" "nothing"]
}

# Check if all values in a record are primitives
def are-all-values-primitive [record: record] {
  $record
  | values
  | all {|val| is-primitive $val }
}

# Format an item as a list item (with "- " prefix and proper indentation)
def format-list-item [item: any] {
  let item_toon = ($item | to toon)
  let lines = ($item_toon | lines)

  if ($lines | length) == 1 {
    # Single line item - simple
    $"  - ($lines | first)"
  } else {
    # Multi-line item - first line gets "- ", rest get "    " (4 spaces)
    let first_line = $"  - ($lines | first)"
    let rest_lines = ($lines | skip 1 | each {|line| $"    ($line)" })
    [$first_line] | append $rest_lines | str join (char newline)
  }
}

# Encode data to TOON format
export def "to toon" [] {
  let input = $in

  let input_type = ($input | describe)

  match $input_type {
    $type if ($type | str starts-with "table") => {
      # Check if table is uniform (all rows have same keys)
      let first_keys = $input | first | columns | sort
      let is_uniform = $input | all {|row|
        ($row | columns | sort) == $first_keys
      }

      if $is_uniform {
        # Additional check: all values must be primitives for tabular format
        let all_primitive = $input | all {|row|
          are-all-values-primitive $row
        }

        if $all_primitive {
          # Tabular format: [N]{fields}: row,row,row
          # NOTE: v2.0 removed the trailing comma in brackets
          let count = $input | length
          let fields = $first_keys | str join ','
          let header = $"[($count)]{($fields)}:"
          let rows = $input | each {|row|
            "  " + (
              $first_keys | each {|key|
                format-primitive ($row | get $key)
              } | str join ','
            )
          } | str join (char newline)
          $header + (char newline) + $rows
        } else {
          # Has nested structures - use list format
          $"[($input | length)]:" + (char newline) + (
            $input | each {|item|
              format-list-item $item
            } | str join (char newline)
          )
        }
      } else {
        # Non-uniform: list format
        $"[($input | length)]:" + (char newline) + (
          $input | each {|item|
            format-list-item $item
          } | str join (char newline)
        )
      }
    }
    $type if ($type | str starts-with "record") => {
      # Record -> key: value pairs
      $input
      | transpose key value
      | each {|row|
        # Check if value is primitive or needs recursion
        if (is-primitive $row.value) {
          let formatted_value = format-primitive $row.value
          $"($row.key): ($formatted_value)"
        } else {
          # Nested object or array - use key: on its own line
          let nested = ($row.value | to toon | lines | each {|line| "  " + $line } | str join (char newline))
          $"($row.key):" + (char newline) + $nested
        }
      }
      | str join (char newline)
    }
    $type if ($type | str starts-with "list") => {
      # Check if all elements are primitives
      let all_primitive = $input | all {|val| is-primitive $val }

      if $all_primitive {
        # List of primitives -> [N]: val,val,val
        let count = $input | length
        let values = $input | each {|v| format-primitive $v } | str join ','
        $"[($count)]: ($values)"
      } else {
        # Mixed/nested list - use expanded format
        $"[($input | length)]:" + (char newline) + (
          $input | each {|item|
            format-list-item $item
          } | str join (char newline)
        )
      }
    }
    _ => {
      # Primitive value
      format-primitive $input
    }
  }
}
