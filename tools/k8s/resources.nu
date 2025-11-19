# Kubernetes MCP Tool - Resource Operations
# Implementations for kube_get, kube_describe

use utils.nu *

# kube_get - Get or list Kubernetes resources
export def kubectl-get [
  params: record
] {
  # Extract parameters
  let resource_type = $params.resourceType
  let name = $params.name? | default ""
  let namespace = $params.namespace? | default ""
  let all_namespaces = $params.allNamespaces? | default false
  let output = $params.output? | default "json"
  let label_selector = $params.labelSelector? | default ""
  let field_selector = $params.fieldSelector? | default ""
  let sort_by = $params.sortBy? | default ""
  let context = $params.context? | default ""
  let delegate = $params.delegate? | default false

  # Build kubectl arguments
  mut args = ["get" $resource_type]

  # Add name if specified
  if $name != "" {
    $args = ($args | append $name)
  }

  # Add label selector
  if $label_selector != "" {
    $args = ($args | append ["--selector" $label_selector])
  }

  # Add field selector
  if $field_selector != "" {
    $args = ($args | append ["--field-selector" $field_selector])
  }

  # Add sort-by
  if $sort_by != "" {
    $args = ($args | append ["--sort-by" $sort_by])
  }

  # If delegating, return the command string
  if $delegate {
    return (
      {
        args: $args
        namespace: $namespace
        context: $context
        output: $output
        all_namespaces: $all_namespaces
      } | build-kubectl-command
    )
  }

  # Execute kubectl command
  let result = {
    args: $args
    namespace: $namespace
    context: $context
    output: $output
    all_namespaces: $all_namespaces
  } | run-kubectl

  # Check for errors
  if ($result | describe | str contains "record") and ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
  }

  # Mask secrets if this is a secret resource
  let masked_result = if $resource_type == "secrets" or $resource_type == "secret" {
    mask-secrets $result
  } else {
    $result
  }

  # Summarize list operations to reduce payload size
  let is_list_operation = ($name == "")

  # Return early if not a list operation or not JSON
  if not ($is_list_operation and ($output == "json")) {
    return (format-tool-response $masked_result)
  }

  # Return early if not a record
  if not ($masked_result | describe | str contains "record") {
    return (format-tool-response $masked_result)
  }

  # Check if this is a Kubernetes list with items
  let kind = ($masked_result | get kind? | default "")
  let has_items = ($masked_result | get items? | default null) != null

  # Return early if not a list kind
  if not (($kind | str ends-with "List") and $has_items) {
    return (format-tool-response $masked_result)
  }

  # Summarize events
  if $resource_type == "events" {
    try {
      let items_list = ($masked_result | get items)
      if ($items_list | describe | str contains "list") {
        let formatted_events = (
          $items_list | each {|event|
            {
              type: ($event | get type? | default "")
              reason: ($event | get reason? | default "")
              message: ($event | get message? | default "")
              involvedObject: {
                kind: ($event | get involvedObject.kind? | default "")
                name: ($event | get involvedObject.name? | default "")
                namespace: ($event | get involvedObject.namespace? | default "")
              }
              firstTimestamp: ($event | get firstTimestamp? | default "")
              lastTimestamp: ($event | get lastTimestamp? | default "")
              count: ($event | get count? | default 0)
            }
          }
        )
        return (format-tool-response {events: $formatted_events})
      }
    } catch {
      return (
        format-tool-response {
          error: "EventSummarizationFailed"
          message: "Failed to process events"
          isError: true
        } --error true
      )
    }
  }

  # Summarize other resources
  try {
    let items_list = ($masked_result | get items)
    if ($items_list | describe | str contains "list") {
      let items = (
        $items_list | each {|item|
          try {
            {
              name: ($item | get metadata.name? | default "")
              namespace: ($item | get metadata.namespace? | default "")
              kind: ($item | get kind? | default $resource_type)
              status: (get-resource-status $item)
              createdAt: ($item | get metadata.creationTimestamp? | default "")
            }
          } catch {
            {
              name: "unknown"
              namespace: ""
              kind: $resource_type
              status: "Error"
              createdAt: ""
              error: "Failed to parse item"
            }
          }
        }
      )
      return (format-tool-response {items: $items})
    }
  } catch {
    return (
      format-tool-response {
        error: "ResourceSummarizationFailed"
        message: "Failed to process resources"
        isError: true
      } --error true
    )
  }

  # Fallback if summarization logic doesn't match
  format-tool-response $masked_result
}

# kube_describe - Describe a Kubernetes resource
export def kubectl-describe [
  params: record
] {
  # Extract parameters
  let resource_type = $params.resourceType
  let name = $params.name
  let namespace = $params.namespace? | default ""
  let all_namespaces = $params.allNamespaces? | default false
  let context = $params.context? | default ""
  let delegate = $params.delegate? | default false

  # Build kubectl arguments
  let args = ["describe" $resource_type $name]

  # If delegating, return the command string
  if $delegate {
    return (
      {
        args: $args
        namespace: $namespace
        context: $context
        output: "text"
        all_namespaces: $all_namespaces
      } | build-kubectl-command
    )
  }

  # Execute kubectl command (describe outputs text, not JSON)
  let result = {
    args: $args
    namespace: $namespace
    context: $context
    output: "text"
    all_namespaces: $all_namespaces
  } | run-kubectl

  # Check for errors
  if ($result | describe | str contains "record") and ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
  }

  # Format response
  format-tool-response {
    resourceType: $resource_type
    name: $name
    namespace: (if $namespace != "" { $namespace } else { get-default-namespace })
    description: $result
  }
}
# kube_apply - Apply YAML manifest
export def kubectl-apply [
  params: record
] {
  # Extract parameters
  let manifest = $params.manifest? | default ""
  let filename = $params.filename? | default ""
  let namespace = $params.namespace? | default ""
  let dry_run = $params.dryRun? | default false
  let force = $params.force? | default false
  let context = $params.context? | default ""

  # Validate that either manifest or filename is provided
  if $manifest == "" and $filename == "" {
    return (
      format-tool-response {
        error: "MissingParameter"
        message: "Either manifest or filename must be provided"
        isError: true
      } --error true
    )
  }

  # Build kubectl arguments
  mut args = ["apply"]

  # Add filename or use stdin for manifest
  if $filename != "" {
    $args = ($args | append ["-f" $filename])
  } else {
    $args = ($args | append ["-f" "-"]) # stdin
  }

  # Add dry-run if specified
  if $dry_run {
    $args = ($args | append "--dry-run=client")
  }

  # Add force if specified
  if $force {
    $args = ($args | append "--force")
  }

  let delegate = $params.delegate? | default false

  # If delegating, return the command string
  if $delegate {
    return (
      if $manifest != "" {
        {
          args: $args
          stdin: $manifest
          namespace: $namespace
          context: $context
          output: "json"
        } | build-kubectl-command
      } else {
        {
          args: $args
          namespace: $namespace
          context: $context
          output: "json"
        } | build-kubectl-command
      }
    )
  }

  # Execute kubectl command
  let result = if $manifest != "" {
    {
      args: $args
      stdin: $manifest
      namespace: $namespace
      context: $context
      output: "json"
    } | run-kubectl
  } else {
    {
      args: $args
      namespace: $namespace
      context: $context
      output: "json"
    } | run-kubectl
  }

  # Check for errors
  if ($result | describe | str contains "record") and ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
  }

  # Format response
  format-tool-response {
    operation: "apply"
    result: $result
  }
}

# kube_create - Create Kubernetes resources
export def kubectl-create [
  params: record
] {
  # Extract parameters
  let manifest = $params.manifest? | default ""
  let filename = $params.filename? | default ""
  let namespace = $params.namespace? | default ""
  let dry_run = $params.dryRun? | default false
  let validate = $params.validate? | default true
  let context = $params.context? | default ""
  let delegate = $params.delegate? | default false

  # Validate that either manifest or filename is provided
  if $manifest == "" and $filename == "" {
    return (
      format-tool-response {
        error: "MissingParameter"
        message: "Either manifest or filename must be provided"
        isError: true
      } --error true
    )
  }

  # Build kubectl arguments
  mut args = ["create"]

  # Add filename or use stdin for manifest
  if $filename != "" {
    $args = ($args | append ["-f" $filename])
  } else {
    $args = ($args | append ["-f" "-"]) # stdin
  }

  # Add dry-run if specified
  if $dry_run {
    $args = ($args | append "--dry-run=client")
  }

  # Add validate flag
  if not $validate {
    $args = ($args | append "--validate=false")
  }

  # If delegating, return the command string
  if $delegate {
    return (
      if $manifest != "" {
        {
          args: $args
          stdin: $manifest
          namespace: $namespace
          context: $context
          output: "json"
        } | build-kubectl-command
      } else {
        {
          args: $args
          namespace: $namespace
          context: $context
          output: "json"
        } | build-kubectl-command
      }
    )
  }

  # Execute kubectl command
  let result = if $manifest != "" {
    {
      args: $args
      stdin: $manifest
      namespace: $namespace
      context: $context
      output: "json"
    } | run-kubectl
  } else {
    {
      args: $args
      namespace: $namespace
      context: $context
      output: "json"
    } | run-kubectl
  }

  # Check for errors
  if ($result | describe | str contains "record") and ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
  }

  # Format response
  format-tool-response {
    operation: "create"
    result: $result
  }
}

# kube_patch - Update resource fields
export def kubectl-patch [
  params: record
] {
  # Extract parameters
  let resource_type = $params.resourceType
  let name = $params.name
  let namespace = $params.namespace? | default ""
  let patch_type = $params.patchType? | default "strategic"
  let patch_data = $params.patchData? | default null
  let patch_file = $params.patchFile? | default ""
  let dry_run = $params.dryRun? | default false
  let context = $params.context? | default ""
  let delegate = $params.delegate? | default false

  # Validate that either patchData or patchFile is provided
  if $patch_data == null and $patch_file == "" {
    return (
      format-tool-response {
        error: "MissingParameter"
        message: "Either patchData or patchFile must be provided"
        isError: true
      } --error true
    )
  }

  # Build kubectl arguments
  mut args = ["patch" $resource_type $name]

  # Add patch type
  let patch_type_flag = match $patch_type {
    "strategic" => "--type=strategic"
    "merge" => "--type=merge"
    "json" => "--type=json"
    _ => "--type=strategic"
  }
  $args = ($args | append $patch_type_flag)

  # Add patch data
  if $patch_data != null {
    let patch_json = ($patch_data | to json --raw)
    $args = ($args | append ["--patch" $patch_json])
  } else {
    $args = ($args | append ["--patch-file" $patch_file])
  }

  # Add dry-run if specified
  if $dry_run {
    $args = ($args | append "--dry-run=client")
  }

  # If delegating, return the command string
  if $delegate {
    return (
      {
        args: $args
        namespace: $namespace
        context: $context
        output: "json"
      } | build-kubectl-command
    )
  }

  # Execute kubectl command
  let result = {
    args: $args
    namespace: $namespace
    context: $context
    output: "json"
  } | run-kubectl

  # Check for errors
  if ($result | describe | str contains "record") and ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
  }

  # Format response
  format-tool-response {
    operation: "patch"
    resourceType: $resource_type
    name: $name
    result: $result
  }
}

# Delete Kubernetes resources
export def kubectl-delete [
  params: record
] {
  # Extract parameters
  let resource_type = $params.resourceType? | default ""
  let name = $params.name? | default ""
  let namespace = $params.namespace? | default (get-default-namespace)
  let label_selector = $params.labelSelector? | default ""
  let manifest = $params.manifest? | default ""
  let filename = $params.filename? | default ""
  let all_namespaces = $params.allNamespaces? | default false
  let force = $params.force? | default false
  let grace_period = $params.gracePeriodSeconds? | default null
  let context = $params.context? | default ""
  let delegate = $params.delegate? | default false

  # Validate input - need at least one way to identify resources
  if ($resource_type == "") and ($manifest == "") and ($filename == "") {
    return (
      format-tool-response {
        error: "InvalidInput"
        message: "Either resourceType, manifest, or filename must be provided"
        isError: true
      } --error true
    )
  }

  # If resourceType is provided, need either name or labelSelector
  if ($resource_type != "") and ($name == "") and ($label_selector == "") {
    return (
      format-tool-response {
        error: "InvalidInput"
        message: "When using resourceType, either name or labelSelector must be provided"
        isError: true
      } --error true
    )
  }

  # Build kubectl delete command
  mut args = ["delete"]

  # Handle deleting from manifest or file
  if ($manifest != "") {
    # Create temporary file for the manifest
    let temp_file = $"/tmp/delete-manifest-(date now | format date '%s').yaml"
    $manifest | save -f $temp_file
    $args = ($args | append ["-f" $temp_file])

    # If delegating, return the command string
    if $delegate {
      let cmd = {
        args: $args
        namespace: $namespace
        context: $context
        output: "text"
      } | build-kubectl-command
      # Clean up temp file
      rm -f $temp_file
      return $cmd
    }

    # Execute the command
    let result = {
      args: $args
      namespace: $namespace
      context: $context
      output: "text"
    } | run-kubectl

    # Clean up temp file
    rm -f $temp_file

    # Check for errors
    if ($result | describe | str contains "record") and ($result | get isError? | default false) {
      return (format-tool-response $result --error true)
    }

    return (
      format-tool-response {
        operation: "delete"
        source: "manifest"
        result: $result
      }
    )
  } else if ($filename != "") {
    $args = ($args | append ["-f" $filename])
  } else {
    # Handle deleting by resource type and name/selector
    $args = ($args | append $resource_type)

    if ($name != "") {
      $args = ($args | append $name)
    }

    if ($label_selector != "") {
      $args = ($args | append ["-l" $label_selector])
    }
  }

  # Add namespace flags
  if $all_namespaces {
    $args = ($args | append "--all-namespaces")
  } else if (not (is-non-namespaced-resource $resource_type)) {
    # Namespace will be added by run-kubectl
  }

  # Add force flag if requested
  if $force {
    $args = ($args | append "--force")
  }

  # Add grace period if specified
  if ($grace_period != null) {
    $args = ($args | append $"--grace-period=($grace_period)")
  }

  # If delegating, return the command string
  if $delegate {
    return (
      {
        args: $args
        namespace: $namespace
        context: $context
        output: "text"
      } | build-kubectl-command
    )
  }

  # Execute kubectl command
  let result = {
    args: $args
    namespace: $namespace
    context: $context
    output: "text"
  } | run-kubectl

  # Check for errors
  if ($result | describe | str contains "record") and ($result | get isError? | default false) {
    # Check if it's a "not found" error
    let error_msg = $result.message? | default ""
    if ($error_msg | str contains "not found") {
      return (
        format-tool-response {
          error: "ResourceNotFound"
          status: "not_found"
          message: "Resource not found"
          isError: true
        } --error true
      )
    }
    return (format-tool-response $result --error true)
  }

  # Format response
  format-tool-response {
    operation: "delete"
    resourceType: $resource_type
    name: $name
    namespace: $namespace
    result: $result
  }
}
