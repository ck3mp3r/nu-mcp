# c5t (Context) Tool for nu-mcp - Context/memory management across sessions

# Import helper modules
use storage.nu *
use formatters.nu *
use utils.nu *
use sync.nu *

def main [] {
  help main
}

def "main list-tools" [] {
  init-database | ignore

  # Auto-refresh from sync on startup (silent - errors are ignored)
  try { sync-refresh | ignore } catch { }

  [
    {
      name: "upsert_task_list"
      description: "Create or update a task list. Omit list_id to create new, provide list_id to update. Supports name, description, tags, and progress notes. Repository must be registered first with upsert_repo."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "string"
            description: "ID of list to update (omit to create new)"
          }
          repo_id: {
            type: "string"
            description: "Repository ID to create list in (optional, defaults to current directory's repo)"
          }
          name: {
            type: "string"
            description: "Name of the task list (required for new lists)"
          }
          description: {
            type: "string"
            description: "Brief description of what this list is for (optional)"
          }
          tags: {
            type: "array"
            items: {type: "string"}
            description: "Tags to organize the list (optional)"
          }
          notes: {
            type: "string"
            description: "Progress notes, decisions, or context for this list (markdown supported)"
          }
          external_ref: {
            type: "string"
            description: "External reference ID such as Jira ticket or GitHub issue (e.g., 'PROJ-123', 'GH-456') (optional)"
          }
        }
      }
    }
    {
      name: "list_task_lists"
      description: "list_task_lists returns tabular data that MUST be displayed directly to the user in your response - never summarize or omit this output."
      input_schema: {
        type: "object"
        properties: {
          tags: {
            type: "array"
            items: {type: "string"}
            description: "Filter lists by tags - shows lists with ANY of these tags (optional)"
          }
          repo_id: {
            type: "string"
            description: "Repository ID to list from (optional, defaults to current directory's repo)"
          }
          all_repos: {
            type: "boolean"
            description: "If true, show lists from all repositories instead of just current directory (optional, default: false)"
          }
        }
      }
    }
    {
      name: "upsert_task"
      description: "Create or update a task. Omit task_id to create new, provide task_id to update. Can set content, priority, status in one call. Auto-timestamps on status changes. Use parent_id to create subtasks."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "string"
            description: "ID of the task list"
          }
          task_id: {
            type: "string"
            description: "ID of task to update (omit to create new)"
          }
          parent_id: {
            type: "string"
            description: "ID of parent task (optional, for creating subtasks)"
          }
          content: {
            type: "string"
            description: "Description of the task (required for new tasks)"
          }
          priority: {
            type: "integer"
            description: "Priority level (1-5, where 1 is highest priority) (optional)"
            minimum: 1
            maximum: 5
          }
          status: {
            type: "string"
            description: "Status (defaults to 'backlog' for new tasks)"
            enum: ["backlog" "todo" "in_progress" "review" "done" "cancelled"]
          }
        }
        required: ["list_id"]
      }
    }

    {
      name: "complete_task"
      description: "Mark task as complete (status='done'). Sets completed_at timestamp."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "string"
            description: "ID of the task list containing the task"
          }
          task_id: {
            type: "string"
            description: "ID of the task to complete"
          }
        }
        required: ["list_id" "task_id"]
      }
    }
    {
      name: "delete_task"
      description: "Remove a task from a list permanently."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "string"
            description: "ID of the task list containing the task"
          }
          task_id: {
            type: "string"
            description: "ID of the task to delete"
          }
        }
        required: ["list_id" "task_id"]
      }
    }

    {
      name: "delete_task_list"
      description: "Remove a task list. Use force=true to delete list with tasks, otherwise fails if list has tasks."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "string"
            description: "ID of the task list to delete"
          }
          force: {
            type: "boolean"
            description: "If true, delete list even if it has tasks (default: false)"
          }
        }
        required: ["list_id"]
      }
    }
    {
      name: "delete_note"
      description: "Remove a note permanently by ID."
      input_schema: {
        type: "object"
        properties: {
          note_id: {
            type: "string"
            description: "ID of the note to delete"
          }
        }
        required: ["note_id"]
      }
    }

    {
      name: "move_task"
      description: "Move a task from one list to another."
      input_schema: {
        type: "object"
        properties: {
          source_list_id: {
            type: "string"
            description: "ID of the list containing the task"
          }
          task_id: {
            type: "string"
            description: "ID of the task to move"
          }
          target_list_id: {
            type: "string"
            description: "ID of the list to move the task to"
          }
        }
        required: ["source_list_id" "task_id" "target_list_id"]
      }
    }

    {
      name: "get_task_list"
      description: "get_task_list returns list metadata that MUST be displayed directly to the user in your response - never summarize or omit this output."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "string"
            description: "ID of the task list"
          }
        }
        required: ["list_id"]
      }
    }
    {
      name: "export_data"
      description: "Export all c5t data (lists, tasks, notes) as JSON backup file. Saves to ~/.local/share/c5t/backups/ by default."
      input_schema: {
        type: "object"
        properties: {
          filename: {
            type: "string"
            description: "Custom backup filename (optional, defaults to backup-{timestamp}.json)"
          }
        }
      }
    }
    {
      name: "import_data"
      description: "Import c5t data from JSON backup file. Replaces all existing data. Use list_backups to see available files."
      input_schema: {
        type: "object"
        properties: {
          filename: {
            type: "string"
            description: "Backup filename (e.g., 'backup-20251215-120000.json')"
          }
        }
        required: ["filename"]
      }
    }
    {
      name: "list_backups"
      description: "list_backups returns backup file list that MUST be displayed directly to the user in your response - never summarize or omit this output."
      input_schema: {
        type: "object"
        properties: {}
      }
    }
    {
      name: "list_tasks"
      description: "DISPLAY OUTPUT TO USER. View tasks grouped by status. Default shows all. Filter to specific status. Use parent_id to list subtasks of a specific task."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "string"
            description: "ID of the task list"
          }
          status: {
            type: "array"
            items: {
              type: "string"
              enum: ["backlog" "todo" "in_progress" "review" "done" "cancelled"]
            }
            description: "Filter to specific statuses. Examples: ['done'], ['backlog', 'todo'], ['in_progress', 'review']"
          }
          parent_id: {
            type: "string"
            description: "Filter to subtasks of a specific parent task. When provided, only subtasks of this parent are returned."
          }
        }
        required: ["list_id"]
      }
    }

    {
      name: "upsert_note"
      description: "Create or update a note. Provide note_id to update existing, omit to create new. Repository must be registered first with upsert_repo. Tip: Use tag 'session' for context across compactions."
      input_schema: {
        type: "object"
        properties: {
          note_id: {
            type: "string"
            description: "ID of note to update (omit to create new)"
          }
          repo_id: {
            type: "string"
            description: "Repository ID to create note in (optional, defaults to current directory's repo)"
          }
          title: {
            type: "string"
            description: "Title of the note (required for new notes)"
          }
          content: {
            type: "string"
            description: "Markdown-formatted content (required for new notes)"
          }
          tags: {
            type: "array"
            items: {type: "string"}
            description: "Tags to organize the note (optional)"
          }
        }
      }
    }
    {
      name: "list_notes"
      description: "list_notes returns tabular data that MUST be displayed directly to the user in your response - never summarize or omit this output."
      input_schema: {
        type: "object"
        properties: {
          tags: {
            type: "array"
            items: {type: "string"}
            description: "Filter notes by tags - shows notes with ANY of these tags (optional)"
          }
          note_type: {
            type: "string"
            description: "Filter by note type: 'manual' (user-created notes), 'archived_todo' (completed task lists) (optional)"
            enum: ["manual" "archived_todo"]
          }
          limit: {
            type: "integer"
            description: "Maximum number of notes to return (optional, default: all)"
            minimum: 1
          }
          repo_id: {
            type: "string"
            description: "Repository ID to list notes from (optional, defaults to current directory's repo)"
          }
          all_repos: {
            type: "boolean"
            description: "If true, show notes from all repositories instead of just current directory (optional, default: false)"
          }
        }
      }
    }
    {
      name: "get_note"
      description: "get_note returns note content that MUST be displayed directly to the user in your response - never summarize or omit this output."
      input_schema: {
        type: "object"
        properties: {
          note_id: {
            type: "string"
            description: "ID of the note to retrieve (from list_notes or search results)"
          }
        }
        required: ["note_id"]
      }
    }
    {
      name: "search"
      description: "search returns tabular results that MUST be displayed directly to the user in your response - never summarize or omit this output."
      input_schema: {
        type: "object"
        properties: {
          query: {
            type: "string"
            description: "FTS5 search query. Simple: 'keyword'. Boolean: 'term1 AND term2', 'term1 OR term2'. Exclude: 'NOT term'. Phrase: '\"exact phrase\"'. Prefix: 'term*'. Combine: 'api AND (error OR bug) NOT deprecated'"
          }
          tags: {
            type: "array"
            items: {type: "string"}
            description: "Filter results by tags - shows notes with ANY of these tags (optional)"
          }
          limit: {
            type: "integer"
            description: "Maximum number of results to return (default: 10)"
            minimum: 1
            default: 10
          }
          repo_id: {
            type: "string"
            description: "Repository ID to search in (optional, defaults to current directory's repo)"
          }
          all_repos: {
            type: "boolean"
            description: "If true, search notes from all repositories instead of just current directory (optional, default: false)"
          }
        }
        required: ["query"]
      }
    }
    {
      name: "get_summary"
      description: "DISPLAY OUTPUT TO USER. Quick status overview of active work across lists."
      input_schema: {
        type: "object"
        properties: {
          repo_id: {
            type: "string"
            description: "Repository ID to get summary for (optional, defaults to current directory's repo)"
          }
          all_repos: {
            type: "boolean"
            description: "If true, show summary from all repositories instead of just current directory (optional, default: false)"
          }
        }
      }
    }
    {
      name: "list_repos"
      description: "list_repos returns tabular data that MUST be displayed directly to the user in your response - never summarize or omit this output."
      input_schema: {
        type: "object"
        properties: {}
      }
    }
    {
      name: "upsert_repo"
      description: "Register or update a git repository. REQUIRED before creating lists or notes. Detects git remote and registers the repo for c5t tracking. Call this first when working in a new repository. If no path provided, uses current working directory."
      input_schema: {
        type: "object"
        properties: {
          path: {
            type: "string"
            description: "Path to the git repository (optional, defaults to current working directory). Can be relative or absolute."
          }
        }
      }
    }
    {
      name: "sync_init"
      description: "Initialize sync by setting up a git repository in the sync directory. Must be called once before using sync_export. Optionally set a remote URL for pushing."
      input_schema: {
        type: "object"
        properties: {
          remote_url: {
            type: "string"
            description: "Git remote URL to add as 'origin' (e.g., 'git@github.com:user/c5t-sync.git'). Optional - can be added later manually."
          }
        }
      }
    }
    {
      name: "sync_refresh"
      description: "Pull latest sync data from remote and import into local database. Use this to get changes made on other machines. Performs: git pull -> import JSONL files."
      input_schema: {
        type: "object"
        properties: {}
      }
    }
    {
      name: "sync_export"
      description: "Export local database to sync files and push to remote. Use this to share changes with other machines. Performs: git pull -> export to JSONL -> git commit -> git push."
      input_schema: {
        type: "object"
        properties: {
          message: {
            type: "string"
            description: "Custom commit message (optional, defaults to auto-generated message with timestamp)"
          }
        }
      }
    }
    {
      name: "sync_status"
      description: "Show sync status including: whether sync is configured, git status, and diff between local DB and sync files."
      input_schema: {
        type: "object"
        properties: {}
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
    "upsert_task_list" => {
      # Required positional params - validate at MCP level
      let name = if "name" in $parsed_args { $parsed_args.name } else { "" }
      let description = if "description" in $parsed_args { $parsed_args.description } else { "" }

      # Resolve repo_id - use provided or get from CWD
      let repo_id = if "repo_id" in $parsed_args and $parsed_args.repo_id != null {
        $parsed_args.repo_id
      } else {
        let repo_result = get-current-repo-id
        if not $repo_result.success {
          return $repo_result.error
        }
        $repo_result.repo_id
      }

      # Optional flag params
      let list_id = if "list_id" in $parsed_args { $parsed_args.list_id } else { null }
      let tags = if "tags" in $parsed_args { $parsed_args.tags } else { null }
      let notes = if "notes" in $parsed_args { $parsed_args.notes } else { null }
      let external_ref = if "external_ref" in $parsed_args { $parsed_args.external_ref } else { null }

      let result = upsert-list $name $description $repo_id --list-id $list_id --tags $tags --notes $notes --external-ref $external_ref

      if not $result.success {
        return $result.error
      }

      if $result.created {
        format-list-created $result
      } else {
        $"✓ Task list updated
  ID: ($result.list.id)
  Name: ($result.list.name)"
      }
    }

    "list_task_lists" => {
      let tag_filter = if "tags" in $parsed_args { $parsed_args.tags } else { null }
      let all_repos = if "all_repos" in $parsed_args { $parsed_args.all_repos } else { false }
      let repo_id = if "repo_id" in $parsed_args { $parsed_args.repo_id } else { null }

      let result = if $all_repos {
        get-task-lists --status "active" --all-repos
      } else if $repo_id != null {
        get-task-lists --status "active" --repo-id $repo_id
      } else {
        get-task-lists --status "active"
      }

      if not $result.success {
        return $result.error
      }

      # Apply tag filter if provided
      let filtered = if $tag_filter != null and ($tag_filter | is-not-empty) {
        $result.lists | where {|list|
          let list_tags = $list.tags
          $tag_filter | any {|tag| $tag in $list_tags }
        }
      } else {
        $result.lists
      }

      format-active-lists $filtered
    }

    "upsert_task" => {
      # Required positional params - validate at MCP level
      if "list_id" not-in $parsed_args {
        return "Error: Missing required field: 'list_id'"
      }
      let list_id = $parsed_args.list_id

      # Content is required for create, but for update we might want to keep existing
      # For hybrid pattern, content is always required positional
      let content = if "content" in $parsed_args { $parsed_args.content } else { "" }

      # Optional flag params with defaults
      let task_id = if "task_id" in $parsed_args { $parsed_args.task_id } else { null }
      let priority = if "priority" in $parsed_args { $parsed_args.priority } else { 3 }
      let status = if "status" in $parsed_args { $parsed_args.status } else { "backlog" }
      let parent_id = if "parent_id" in $parsed_args { $parsed_args.parent_id } else { null }

      # Validate priority
      let priority_validation = validate-priority $priority
      if not $priority_validation.valid {
        return $priority_validation.error
      }

      # Validate status
      let status_validation = validate-status $status
      if not $status_validation.valid {
        return $status_validation.error
      }

      let result = upsert-task $list_id $content --task-id $task_id --priority $priority --status $status --parent-id $parent_id

      if not $result.success {
        return $result.error
      }

      if $result.created {
        format-task-created $result
      } else {
        $"✓ Task updated
  ID: ($result.task.id)
  Content: ($result.task.content)"
      }
    }

    "complete_task" => {
      let validation = validate-task-update-input $parsed_args
      if not $validation.valid {
        return $validation.error
      }

      let list_id = $parsed_args.list_id
      let task_id = $parsed_args.task_id

      # Check if task exists
      if not (task-exists $list_id $task_id) {
        return $"Error: Task not found: ($task_id)"
      }

      let result = complete-task $list_id $task_id

      if not $result.success {
        return $result.error
      }

      format-task-completed $task_id
    }

    "delete_task" => {
      let validation = validate-task-update-input $parsed_args
      if not $validation.valid {
        return $validation.error
      }

      let list_id = $parsed_args.list_id
      let task_id = $parsed_args.task_id

      let result = delete-task $list_id $task_id

      if not $result.success {
        return $result.error
      }

      $"✓ Task deleted \(ID: ($task_id)\)"
    }

    "delete_task_list" => {
      if "list_id" not-in $parsed_args {
        return "Error: Missing required field: 'list_id'"
      }

      let list_id = $parsed_args.list_id
      let force = if "force" in $parsed_args { $parsed_args.force } else { false }

      let result = delete-list $list_id $force

      if not $result.success {
        return $result.error
      }

      if $force {
        $"✓ Task list and all tasks deleted \(ID: ($list_id)\)"
      } else {
        $"✓ Task list deleted \(ID: ($list_id)\)"
      }
    }

    "delete_note" => {
      if "note_id" not-in $parsed_args {
        return "Error: Missing required field: 'note_id'"
      }

      let note_id = $parsed_args.note_id

      let result = delete-note $note_id

      if not $result.success {
        return $result.error
      }

      $"✓ Note deleted \(ID: ($note_id)\)"
    }

    "move_task" => {
      if "source_list_id" not-in $parsed_args {
        return "Error: Missing required field: 'source_list_id'"
      }

      if "task_id" not-in $parsed_args {
        return "Error: Missing required field: 'task_id'"
      }

      if "target_list_id" not-in $parsed_args {
        return "Error: Missing required field: 'target_list_id'"
      }

      let source_list_id = $parsed_args.source_list_id
      let task_id = $parsed_args.task_id
      let target_list_id = $parsed_args.target_list_id

      let result = move-task $source_list_id $task_id $target_list_id

      if not $result.success {
        return $result.error
      }

      $"✓ Task moved \(ID: ($task_id)\)
  From list: ($source_list_id)
  To list: ($target_list_id)"
    }

    "get_task_list" => {
      if "list_id" not-in $parsed_args {
        return "Error: Missing required field: 'list_id'"
      }

      let list_id = $parsed_args.list_id

      let result = get-list $list_id

      if not $result.success {
        return $result.error
      }

      format-list-detail $result.list
    }

    "export_data" => {
      let result = export-data

      if not $result.success {
        return $result.error
      }

      # Generate filename
      let timestamp = date now | format date "%Y%m%d-%H%M%S"
      let filename = if "filename" in $parsed_args and $parsed_args.filename != null {
        $parsed_args.filename
      } else {
        $"backup-($timestamp).json"
      }

      # Ensure backup directory exists
      let backup_dir = $"(get-xdg-data-path)/backups"
      if not ($backup_dir | path exists) {
        mkdir $backup_dir
      }

      # Write backup file
      let filepath = $"($backup_dir)/($filename)"
      $result.data | to json --indent 2 | save -f $filepath

      $"✓ Backup saved to ($filepath)
  Repos: ($result.data.repos | length)
  Lists: ($result.data.lists | length)
  Tasks: ($result.data.tasks | length)
  Notes: ($result.data.notes | length)"
    }

    "import_data" => {
      if "filename" not-in $parsed_args {
        return "Error: Missing required field: 'filename'"
      }

      let filename = $parsed_args.filename

      # Build filepath
      let backup_dir = $"(get-xdg-data-path)/backups"
      let filepath = $"($backup_dir)/($filename)"

      # Check if file exists
      if not ($filepath | path exists) {
        return $"Error: Backup file not found: ($filepath)

Use list_backups to see available backup files."
      }

      # Read and parse the backup file
      let data = try {
        open $filepath
      } catch {
        return $"Error: Failed to read backup file: ($filepath)"
      }

      let result = import-data $data

      if not $result.success {
        return $result.error
      }

      $"✓ Data restored from ($filepath)
  Repos: ($result.imported.repos)
  Lists: ($result.imported.lists)
  Tasks: ($result.imported.tasks)
  Notes: ($result.imported.notes)"
    }

    "list_backups" => {
      let backup_dir = $"(get-xdg-data-path)/backups"

      if not ($backup_dir | path exists) {
        return "No backup directory found. Run export_data first to create a backup."
      }

      let backups = glob $"($backup_dir)/*.json" | sort -r

      if ($backups | is-empty) {
        return "No backup files found."
      }

      let backup_info = $backups | each {|file|
          let stat = ls $file | first
          {
            filename: ($file | path basename)
            size: $stat.size
            modified: $stat.modified
          }
        }

      let lines = ["Available backups:" ""]
      let file_lines = $backup_info | each {|b|
          $"  ($b.filename) \(($b.size), ($b.modified)\)"
        }

      [...$lines ...$file_lines "" "Use import_data with filename to restore."] | str join (char newline)
    }

    "list_tasks" => {
      if "list_id" not-in $parsed_args {
        return "Error: Missing required field: 'list_id'"
      }

      let list_id = $parsed_args.list_id
      let status_filter = if "status" in $parsed_args { $parsed_args.status } else { null }
      let parent_id = if "parent_id" in $parsed_args { $parsed_args.parent_id } else { null }

      # Validate each status if array provided
      if $status_filter != null {
        for status in $status_filter {
          let status_validation = validate-status $status
          if not $status_validation.valid {
            return $status_validation.error
          }
        }
      }

      # If parent_id provided, get subtasks instead
      if $parent_id != null {
        let result = get-subtasks $list_id $parent_id
        if not $result.success {
          return $result.error
        }
        if ($result.tasks | is-empty) {
          return $"No subtasks found for parent task ($parent_id)."
        }
        return (format-subtasks-list $parent_id $result.tasks)
      }

      let result = get-list-with-tasks $list_id $status_filter

      if not $result.success {
        return $result.error
      }

      format-tasks-table $result.list $result.tasks
    }

    "upsert_note" => {
      # Required positional params
      let title = if "title" in $parsed_args { $parsed_args.title } else { "" }
      let content = if "content" in $parsed_args { $parsed_args.content } else { "" }

      # Resolve repo_id - use provided or get from CWD
      let repo_id = if "repo_id" in $parsed_args and $parsed_args.repo_id != null {
        $parsed_args.repo_id
      } else {
        let repo_result = get-current-repo-id
        if not $repo_result.success {
          return $repo_result.error
        }
        $repo_result.repo_id
      }

      # Optional flag params
      let note_id = if "note_id" in $parsed_args { $parsed_args.note_id } else { null }
      let tags = if "tags" in $parsed_args { $parsed_args.tags } else { null }

      let result = upsert-note $title $content $repo_id --note-id $note_id --tags $tags

      if not $result.success {
        return $result.error
      }

      if $result.created {
        format-note-created-manual $result
      } else {
        $"✓ Note updated
  ID: ($result.note.id)
  Title: ($result.note.title)"
      }
    }

    "list_notes" => {
      let tag_filter = if "tags" in $parsed_args { $parsed_args.tags } else { null }
      let note_type = if "note_type" in $parsed_args { $parsed_args.note_type } else { null }
      let limit = if "limit" in $parsed_args { $parsed_args.limit } else { null }
      let all_repos = if "all_repos" in $parsed_args { $parsed_args.all_repos } else { false }
      let repo_id = if "repo_id" in $parsed_args { $parsed_args.repo_id } else { null }

      let result = if $all_repos {
        get-notes $tag_filter $note_type $limit --all-repos
      } else if $repo_id != null {
        get-notes $tag_filter $note_type $limit --repo-id $repo_id
      } else {
        get-notes $tag_filter $note_type $limit
      }

      if not $result.success {
        return $result.error
      }

      format-notes-list-detailed $result.notes
    }

    "get_note" => {
      if "note_id" not-in $parsed_args {
        return "Error: Missing required field: 'note_id'"
      }

      let note_id = $parsed_args.note_id

      let result = get-note $note_id

      if not $result.success {
        return $result.error
      }

      format-note-detail $result.note
    }

    "search" => {
      if "query" not-in $parsed_args {
        return "Error: Missing required field: 'query'"
      }

      let query = $parsed_args.query
      let tag_filter = if "tags" in $parsed_args { $parsed_args.tags } else { [] }
      let limit = if "limit" in $parsed_args { $parsed_args.limit } else { 10 }
      let all_repos = if "all_repos" in $parsed_args { $parsed_args.all_repos } else { false }
      let repo_id = if "repo_id" in $parsed_args { $parsed_args.repo_id } else { null }

      let result = if $all_repos {
        search-notes $query --limit $limit --tags $tag_filter --all-repos
      } else if $repo_id != null {
        search-notes $query --limit $limit --tags $tag_filter --repo-id $repo_id
      } else {
        search-notes $query --limit $limit --tags $tag_filter
      }

      if not $result.success {
        return $result.error
      }

      format-search-results $result.notes
    }

    "get_summary" => {
      let all_repos = if "all_repos" in $parsed_args { $parsed_args.all_repos } else { false }
      let repo_id = if "repo_id" in $parsed_args { $parsed_args.repo_id } else { null }

      let result = if $all_repos {
        get-summary --all-repos
      } else if $repo_id != null {
        get-summary --repo-id $repo_id
      } else {
        get-summary
      }

      if not $result.success {
        return $result.error
      }

      format-summary $result.summary
    }

    "list_repos" => {
      let result = list-repos

      if not $result.success {
        return $result.error
      }

      format-repos-list $result.repos
    }

    "upsert_repo" => {
      let path = if "path" in $parsed_args { $parsed_args.path } else { null }

      let result = upsert-repo $path

      if not $result.success {
        return $result.error
      }

      if $result.created {
        $"✓ Repository registered
  ID: ($result.repo_id)
  Remote: ($result.remote)
  Path: ($result.path)"
      } else {
        $"✓ Repository updated
  ID: ($result.repo_id)
  Remote: ($result.remote)
  Path: ($result.path)"
      }
    }

    "sync_init" => {
      let remote_url = if "remote_url" in $parsed_args { $parsed_args.remote_url } else { null }
      let result = sync-init $remote_url

      if not $result.success {
        return $result.error
      }

      $result.message
    }

    "sync_refresh" => {
      let result = sync-refresh

      if not $result.success {
        return $result.error
      }

      $result.message
    }

    "sync_export" => {
      let message = if "message" in $parsed_args { $parsed_args.message } else { null }
      let result = sync-export $message

      if not $result.success {
        return $result.error
      }

      $result.message
    }

    "sync_status" => {
      let result = sync-status

      if not $result.success {
        return $result.error
      }

      $result.message
    }

    _ => {
      error make {msg: $"Unknown tool: ($tool_name)"}
    }
  }
}
