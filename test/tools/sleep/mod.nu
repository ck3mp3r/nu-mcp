# Sleep test tool for timeout testing

def main [] {
  help main
}

def "main list-tools" [] {
  [
    {
      name: "sleep_test"
      description: "Sleep for specified seconds (for timeout testing)"
      input_schema: {
        type: "object"
        properties: {
          seconds: {
            type: "integer"
            description: "Number of seconds to sleep"
            minimum: 1
          }
        }
        required: ["seconds"]
      }
    }
  ] | to json
}

def "main call-tool" [
  tool_name: string
  args: any = {}
] {
  let parsed_args = if ($args | describe) == "string" {
    $args | from json
  } else {
    $args
  }

  match $tool_name {
    "sleep_test" => {
      let seconds = $parsed_args | get seconds
      sleep ($seconds * 1sec)
      $"Slept for ($seconds) seconds"
    }
    _ => {
      error make {msg: $"Unknown tool: ($tool_name)"}
    }
  }
}
