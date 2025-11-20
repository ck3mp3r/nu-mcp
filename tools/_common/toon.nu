# TOON (Token-Oriented Object Notation) encoder for Nushell
# Based on official TOON specification: https://github.com/xaviviro/python-toon
# Reduces token usage by 30-60% compared to JSON for LLM interactions

# Encode data to TOON format
export def "to toon" [] {
  let input = $in

  match ($input | describe) {
    $type if ($type | str starts-with "table") => {
      # Check if table is uniform (all rows have same keys)
      let first_keys = $input | first | columns | sort
      let is_uniform = $input | all {|row|
        ($row | columns | sort) == $first_keys
      }

      if $is_uniform {
        # Tabular format: [N,]{fields}: row,row,row
        let count = $input | length
        let fields = $first_keys | str join ','
        let header = $"[($count),]{($fields)}:"
        let rows = $input | each {|row|
          "  " + (
            $first_keys | each {|key|
              $row | get $key | into string
            } | str join ','
          )
        } | str join (char newline)
        $header + (char newline) + $rows
      } else {
        # Non-uniform: list format
        $"[($input | length)]:" + (char newline) + (
          $input | each {|item|
            "  - " + ($item | to toon | lines | str join (char newline + "    "))
          } | str join (char newline)
        )
      }
    }
    "record" => {
      # Record -> key: value pairs
      $input
      | transpose key value
      | each {|row| $"($row.key): ($row.value | into string)" }
      | str join (char newline)
    }
    $type if ($type | str starts-with "list") => {
      # List of primitives -> [N]: val,val,val
      let count = $input | length
      $"[($count)]: " + ($input | each {|v| $v | into string } | str join ',')
    }
    _ => {
      # Primitive value
      $input | into string
    }
  }
}
