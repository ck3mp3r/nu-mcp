# Tests for sync.nu - git helpers and JSONL functions
# TDD: Write tests first, then implement

use std/assert
use test_helpers.nu *

# Helper to create temp sync directory
def create-temp-sync-dir [] {
  let temp_dir = (mktemp -d)
  mkdir ($temp_dir | path join "sync")
  $temp_dir
}

# =============================================================================
# Git Helper Tests
# =============================================================================

export def "test is-git-repo returns true for git directory" [] {
  use ../sync.nu is-git-repo

  # Create temp directory with git init
  let temp_dir = (mktemp -d)
  cd $temp_dir
  ^git init --quiet

  let result = is-git-repo $temp_dir

  # Cleanup
  cd -
  rm -rf $temp_dir

  assert $result "Should return true for git repo"
}

export def "test is-git-repo returns false for non-git directory" [] {
  use ../sync.nu is-git-repo

  # Create temp directory without git
  let temp_dir = (mktemp -d)

  let result = is-git-repo $temp_dir

  # Cleanup
  rm -rf $temp_dir

  assert (not $result) "Should return false for non-git directory"
}

export def "test git-status-clean returns true for clean repo" [] {
  use ../sync.nu git-status-clean

  # Create temp git repo
  let temp_dir = (mktemp -d)
  cd $temp_dir
  ^git init --quiet
  ^git config user.email "test@test.com"
  ^git config user.name "Test"

  # Create initial commit so we have a clean state
  "initial" | save test.txt
  ^git add test.txt
  ^git commit -m "initial" --quiet

  let result = git-status-clean $temp_dir

  # Cleanup
  cd -
  rm -rf $temp_dir

  assert $result "Should return true for clean repo"
}

export def "test git-status-clean returns false for dirty repo" [] {
  use ../sync.nu git-status-clean

  # Create temp git repo with uncommitted changes
  let temp_dir = (mktemp -d)
  cd $temp_dir
  ^git init --quiet
  ^git config user.email "test@test.com"
  ^git config user.name "Test"

  # Create initial commit
  "initial" | save test.txt
  ^git add test.txt
  ^git commit -m "initial" --quiet

  # Make uncommitted changes
  "modified" | save -f test.txt

  let result = git-status-clean $temp_dir

  # Cleanup
  cd -
  rm -rf $temp_dir

  assert (not $result) "Should return false for dirty repo"
}

# =============================================================================
# JSONL Helper Tests
# =============================================================================

export def "test to-jsonl converts list to jsonl string" [] {
  use ../sync.nu to-jsonl

  let data = [
    {id: "abc123" name: "First"}
    {id: "def456" name: "Second"}
  ]

  let result = $data | to-jsonl
  let lines = $result | lines

  assert (($lines | length) == 2) "Should have 2 lines"
  assert (($lines | first | from json | get id) == "abc123") "First line should have correct id"
  assert (($lines | last | from json | get id) == "def456") "Second line should have correct id"
}

export def "test from-jsonl converts jsonl string to list" [] {
  use ../sync.nu from-jsonl

  let jsonl = "{\"id\":\"abc123\",\"name\":\"First\"}\n{\"id\":\"def456\",\"name\":\"Second\"}"

  let result = $jsonl | from-jsonl

  assert (($result | length) == 2) "Should have 2 records"
  assert (($result | first | get id) == "abc123") "First record should have correct id"
  assert (($result | last | get id) == "def456") "Second record should have correct id"
}

export def "test from-jsonl handles empty string" [] {
  use ../sync.nu from-jsonl

  let result = "" | from-jsonl

  assert (($result | length) == 0) "Should return empty list for empty string"
}

export def "test to-jsonl handles empty list" [] {
  use ../sync.nu to-jsonl

  let result = [] | to-jsonl

  assert ($result == "") "Should return empty string for empty list"
}

# =============================================================================
# Sync File Read/Write Tests
# =============================================================================

export def "test write-sync-files creates jsonl files" [] {
  use ../sync.nu write-sync-files

  let temp_dir = create-temp-sync-dir
  let sync_dir = ($temp_dir | path join "sync")

  let data = {
    repos: [{id: "repo1234" remote: "git@github.com:test/repo" path: "/path" created_at: "2025-01-01"}]
    lists: [{id: "list1234" repo_id: "repo1234" name: "Test" description: "Desc" tags: "tag1" notes: null external_ref: null created_at: "2025-01-01" updated_at: "2025-01-01"}]
    tasks: [{id: "task1234" list_id: "list1234" content: "Task" priority: 3 status: "todo" parent_id: null created_at: "2025-01-01" updated_at: "2025-01-01" started_at: null completed_at: null}]
    notes: [{id: "note1234" repo_id: "repo1234" title: "Note" content: "Content" tags: "" note_type: "manual" created_at: "2025-01-01" updated_at: "2025-01-01"}]
  }

  write-sync-files $sync_dir $data

  # Verify files exist
  assert (($sync_dir | path join "repos.jsonl") | path exists) "repos.jsonl should exist"
  assert (($sync_dir | path join "lists.jsonl") | path exists) "lists.jsonl should exist"
  assert (($sync_dir | path join "tasks.jsonl") | path exists) "tasks.jsonl should exist"
  assert (($sync_dir | path join "notes.jsonl") | path exists) "notes.jsonl should exist"

  # Cleanup
  rm -rf $temp_dir
}

export def "test read-sync-files reads jsonl files" [] {
  use ../sync.nu [ write-sync-files read-sync-files ]

  let temp_dir = create-temp-sync-dir
  let sync_dir = ($temp_dir | path join "sync")

  let data = {
    repos: [{id: "repo1234" remote: "git@github.com:test/repo" path: "/path" created_at: "2025-01-01"}]
    lists: [{id: "list1234" repo_id: "repo1234" name: "Test" description: "Desc" tags: "tag1" notes: null external_ref: null created_at: "2025-01-01" updated_at: "2025-01-01"}]
    tasks: [{id: "task1234" list_id: "list1234" content: "Task" priority: 3 status: "todo" parent_id: null created_at: "2025-01-01" updated_at: "2025-01-01" started_at: null completed_at: null}]
    notes: [{id: "note1234" repo_id: "repo1234" title: "Note" content: "Content" tags: "" note_type: "manual" created_at: "2025-01-01" updated_at: "2025-01-01"}]
  }

  write-sync-files $sync_dir $data
  let result = read-sync-files $sync_dir

  assert (($result.repos | length) == 1) "Should read 1 repo"
  assert (($result.lists | length) == 1) "Should read 1 list"
  assert (($result.tasks | length) == 1) "Should read 1 task"
  assert (($result.notes | length) == 1) "Should read 1 note"
  assert (($result.repos | first | get id) == "repo1234") "Should have correct repo id"

  # Cleanup
  rm -rf $temp_dir
}

export def "test read-sync-files returns empty when no files" [] {
  use ../sync.nu read-sync-files

  let temp_dir = create-temp-sync-dir
  let sync_dir = ($temp_dir | path join "sync")

  let result = read-sync-files $sync_dir

  assert (($result.repos | length) == 0) "Should return empty repos"
  assert (($result.lists | length) == 0) "Should return empty lists"
  assert (($result.tasks | length) == 0) "Should return empty tasks"
  assert (($result.notes | length) == 0) "Should return empty notes"

  # Cleanup
  rm -rf $temp_dir
}

export def "test get-sync-dir returns correct path" [] {
  use ../sync.nu get-sync-dir

  let result = get-sync-dir

  assert ($result | str ends-with "c5t/sync") "Should end with c5t/sync"
}

# =============================================================================
# sync-export Tests  
# =============================================================================

export def --env "test export-db-to-sync writes all data to jsonl" [] {
  use nu-mock *
  use wrappers.nu *
  use ../sync.nu [ export-db-to-sync read-sync-files ]
  use ../storage.nu [ init-database upsert-repo upsert-list upsert-task upsert-note ]

  mock reset

  # Set up temp database and sync dir
  let temp_dir = (mktemp -d)
  let sync_dir = ($temp_dir | path join "sync")
  mkdir $sync_dir

  $env.XDG_DATA_HOME = $temp_dir
  init-database

  # Create temp git repo directory (but don't init git - just mkdir)
  let git_dir = ($temp_dir | path join "git-repo")
  mkdir $git_dir
  mkdir ($git_dir | path join ".git") # Fake .git directory

  # Mock git remote for upsert-repo to get remote URL
  mock register git {
    args: ['-C' $git_dir 'remote' 'get-url' 'origin']
    returns: "git@github.com:test/repo.git"
  }

  let repo = upsert-repo $git_dir
  let list = upsert-list "Test List" "Description" $repo.repo_id
  let task = upsert-task $list.id "Test Task"
  let note = upsert-note "Test Note" "Content" $repo.repo_id

  # Export to sync files
  export-db-to-sync $sync_dir

  # Verify sync files
  let data = read-sync-files $sync_dir

  assert (($data.repos | length) >= 1) "Should have at least 1 repo"
  assert (($data.lists | length) >= 1) "Should have at least 1 list"
  assert (($data.tasks | length) >= 1) "Should have at least 1 task"
  assert (($data.notes | length) >= 1) "Should have at least 1 note"

  # Cleanup
  rm -rf $temp_dir
  mock verify
}

# =============================================================================
# sync-import Tests
# =============================================================================

export def "test import-sync-to-db imports new records" [] {
  with-test-db {
    use ../sync.nu [ import-sync-to-db write-sync-files get-sync-dir ]
    use ../storage.nu [ init-database list-repos get-task-lists get-notes ]

    # Set up sync dir in test environment
    let sync_dir = ($env.XDG_DATA_HOME | path join "c5t" "sync")
    mkdir $sync_dir

    init-database

    # Create sync files with test data
    let data = {
      repos: [{id: "testrepo" remote: "github:test/repo" path: "/test/path" created_at: "2025-01-01T00:00:00Z"}]
      lists: [{id: "testlist" repo_id: "testrepo" name: "Imported List" description: "Imported" tags: "" notes: null status: "active" external_ref: null created_at: "2025-01-01T00:00:00Z" updated_at: "2025-01-01T00:00:00Z" archived_at: null}]
      tasks: [{id: "testtask" list_id: "testlist" content: "Imported Task" priority: 3 status: "todo" parent_id: null created_at: "2025-01-01T00:00:00Z" started_at: null completed_at: null}]
      notes: [{id: "testnote" repo_id: "testrepo" title: "Imported Note" content: "Content" tags: "" note_type: "manual" created_at: "2025-01-01T00:00:00Z" updated_at: "2025-01-01T00:00:00Z"}]
    }

    write-sync-files $sync_dir $data

    # Import sync files
    import-sync-to-db $sync_dir

    # Verify data was imported
    let repos_result = list-repos
    let lists_result = get-task-lists --status "all" --all-repos
    let notes_result = get-notes --all-repos

    assert (($repos_result.repos | where id == "testrepo" | length) == 1) "Should have imported repo"
    assert (($lists_result.lists | where id == "testlist" | length) == 1) "Should have imported list"
    assert (($notes_result.notes | where id == "testnote" | length) == 1) "Should have imported note"
  }
}

export def --env "test import-sync-to-db updates existing with newer timestamp" [] {
  use nu-mock *
  use wrappers.nu *
  use ../sync.nu [ import-sync-to-db write-sync-files ]
  use ../storage.nu [ init-database upsert-repo upsert-list get-list ]

  mock reset

  # Set up temp database and sync dir
  let temp_dir = (mktemp -d)
  let sync_dir = ($temp_dir | path join "sync")
  mkdir $sync_dir

  $env.XDG_DATA_HOME = $temp_dir
  init-database

  # Create temp git repo directory (but don't init git - just mkdir)
  let git_dir = ($temp_dir | path join "git-repo")
  mkdir $git_dir
  mkdir ($git_dir | path join ".git") # Fake .git directory

  # Mock git remote for upsert-repo to get remote URL
  mock register git {
    args: ['-C' $git_dir 'remote' 'get-url' 'origin']
    returns: "git@github.com:test/repo.git"
  }

  # Create existing data with old timestamp
  let repo = upsert-repo $git_dir
  let list = upsert-list "Old Name" "Old Desc" $repo.repo_id

  # Create sync files with newer data (future timestamp)
  let data = {
    repos: [{id: $repo.repo_id remote: $repo.remote path: $repo.path created_at: "2025-01-01T00:00:00Z"}]
    lists: [{id: $list.id repo_id: $repo.repo_id name: "New Name" description: "New Desc" tags: "" notes: null status: "active" external_ref: null created_at: "2025-01-01T00:00:00Z" updated_at: "2099-01-01T00:00:00Z" archived_at: null}]
    tasks: []
    notes: []
  }

  write-sync-files $sync_dir $data

  # Import sync files
  import-sync-to-db $sync_dir

  # Verify data was updated
  let list_result = get-list $list.id

  assert ($list_result.list.name == "New Name") "Should have updated name"
  assert ($list_result.list.description == "New Desc") "Should have updated description"

  # Cleanup
  rm -rf $temp_dir
  mock verify
}

# =============================================================================
# sync-init Tests
# =============================================================================

export def --env "test sync-init creates git repo in sync dir" [] {
  use nu-mock *
  use wrappers.nu *
  use ../sync.nu [ sync-init get-sync-dir is-git-repo ]

  mock reset

  # Use temp sync dir
  let temp_dir = (mktemp -d)
  let sync_dir = ($temp_dir | path join "c5t" "sync")
  $env.XDG_DATA_HOME = $temp_dir

  # Mock git init
  mock register git {
    args: ['init' '--quiet']
    returns: ""
  }

  let result = sync-init null

  assert $result.success "sync-init should succeed"
  # Verify .git directory was created by sync-init
  assert (is-git-repo $sync_dir) "Sync dir should be a git repo"

  # Cleanup
  rm -rf $temp_dir
  mock verify
}

export def --env "test sync-init adds remote when provided" [] {
  use nu-mock *
  use wrappers.nu *
  use ../sync.nu [ sync-init get-sync-dir ]

  mock reset

  # Use temp sync dir
  let temp_dir = (mktemp -d)
  let sync_dir = ($temp_dir | path join "c5t" "sync")
  $env.XDG_DATA_HOME = $temp_dir

  # Mock git init
  mock register git {
    args: ['init' '--quiet']
    returns: ""
  }

  # Mock git remote add
  mock register git {
    args: ['remote' 'add' 'origin' 'git@github.com:user/c5t-sync.git']
    returns: ""
  }

  let result = sync-init "git@github.com:user/c5t-sync.git"

  assert $result.success "sync-init should succeed"
  assert ($result.message | str contains "git@github.com:user/c5t-sync.git") "Message should mention remote"

  # Cleanup
  rm -rf $temp_dir
  mock verify
}

export def --env "test sync-init returns error if already initialized" [] {
  use nu-mock *
  use wrappers.nu *
  use ../sync.nu [ sync-init get-sync-dir ]

  mock reset

  # Use temp sync dir
  let temp_dir = (mktemp -d)
  let sync_dir = ($temp_dir | path join "c5t" "sync")
  $env.XDG_DATA_HOME = $temp_dir

  # Mock git init for first call
  mock register git {
    args: ['init' '--quiet']
    returns: ""
  }

  # Initialize twice
  sync-init null
  let result = sync-init null

  assert (not $result.success) "Second init should fail"
  assert ($result.error | str contains "already initialized") "Error should mention already initialized"

  # Cleanup
  rm -rf $temp_dir
  mock verify
}

# =============================================================================
# sync-status Tests
# =============================================================================

export def "test sync-status shows not configured when no git repo" [] {
  use ../sync.nu [ sync-status ]

  # Use temp sync dir without git
  let temp_dir = (mktemp -d)
  $env.XDG_DATA_HOME = $temp_dir

  let result = sync-status

  assert $result.success "sync-status should succeed"
  assert ($result.message | str contains "not configured") "Should show not configured"

  # Cleanup
  rm -rf $temp_dir
}

export def --env "test sync-status shows configured status" [] {
  use nu-mock *
  use wrappers.nu *
  use ../sync.nu [ sync-init sync-status ]

  mock reset

  # Use temp sync dir
  let temp_dir = (mktemp -d)
  $env.XDG_DATA_HOME = $temp_dir

  # Mock git init
  mock register git {
    args: ['init' '--quiet']
    returns: ""
  }

  # Mock git remote add
  mock register git {
    args: ['remote' 'add' 'origin' 'git@github.com:user/repo.git']
    returns: ""
  }

  sync-init "git@github.com:user/repo.git"

  # Mock git remote -v for sync-status
  mock register git {
    args: ['remote' '-v']
    returns: "origin\tgit@github.com:user/repo.git (fetch)\norigin\tgit@github.com:user/repo.git (push)"
  }

  # Mock git status --short for sync-status
  mock register git {
    args: ['status' '--short']
    returns: ""
  }

  let result = sync-status

  assert $result.success "sync-status should succeed"
  assert ($result.message | str contains "configured") "Should show configured"
  assert ($result.message | str contains "origin") "Should show remote info"

  # Cleanup
  rm -rf $temp_dir
  mock verify
}

# =============================================================================
# sync-refresh Tests
# =============================================================================

export def "test sync-refresh skips when sync not configured" [] {
  use ../sync.nu [ sync-refresh ]

  # Use temp sync dir without git
  let temp_dir = (mktemp -d)
  $env.XDG_DATA_HOME = $temp_dir

  let result = sync-refresh

  assert $result.success "sync-refresh should succeed (skip)"
  assert ($result.message | str contains "not configured") "Should mention not configured"

  # Cleanup
  rm -rf $temp_dir
}

export def --env "test sync-refresh imports data from sync files" [] {
  use nu-mock *
  use wrappers.nu *
  use ../sync.nu [ sync-init sync-refresh write-sync-files get-sync-dir ]
  use ../storage.nu [ init-database list-repos ]

  mock reset

  # Set up temp environment
  let temp_dir = (mktemp -d)
  let sync_dir = ($temp_dir | path join "c5t" "sync")
  let db_path = ($temp_dir | path join "c5t" "test.db")
  $env.XDG_DATA_HOME = $temp_dir
  $env.C5T_DB_PATH = $db_path

  init-database

  # Mock git init for sync-init
  mock register git {
    args: ['init' '--quiet']
    returns: ""
  }

  # Initialize sync
  sync-init null

  # Write sync data directly (simulating a pull from remote)
  let data = {
    repos: [{id: "testrepo" remote: "github:test/repo" path: "/test/path" created_at: "2025-01-01T00:00:00Z"}]
    lists: []
    tasks: []
    notes: []
  }
  write-sync-files $sync_dir $data

  # Mock git status check (clean repo)
  mock register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  # Mock git pull (successful pull)
  mock register git {
    args: ['pull']
    returns: "Already up to date."
  }

  # Refresh should import the data
  let result = sync-refresh

  assert $result.success "sync-refresh should succeed"

  # Verify data was imported
  let repos = list-repos
  assert (($repos.repos | where id == "testrepo" | length) == 1) "Should have imported repo"

  # Cleanup
  rm -rf $temp_dir
  mock verify
}

# =============================================================================
# sync-export Tests
# =============================================================================

export def "test sync-export fails when sync not configured" [] {
  use ../sync.nu [ sync-export ]

  # Use temp sync dir without git
  let temp_dir = (mktemp -d)
  $env.XDG_DATA_HOME = $temp_dir

  let result = sync-export null

  assert (not $result.success) "sync-export should fail"
  assert ($result.error | str contains "not configured") "Should mention not configured"

  # Cleanup
  rm -rf $temp_dir
}

export def --env "test sync-export exports data and commits" [] {
  use nu-mock *
  use wrappers.nu *
  use ../sync.nu [ sync-init sync-export get-sync-dir read-sync-files ]
  use ../storage.nu [ init-database upsert-repo upsert-list ]

  mock reset

  # Set up temp environment
  let temp_dir = (mktemp -d)
  let sync_dir = ($temp_dir | path join "c5t" "sync")
  let db_path = ($temp_dir | path join "c5t" "test.db")
  $env.XDG_DATA_HOME = $temp_dir
  $env.C5T_DB_PATH = $db_path

  # Create temp git repo directory for upsert-repo (but don't init git - just mkdir)
  let git_dir = ($temp_dir | path join "git-repo")
  mkdir $git_dir
  mkdir ($git_dir | path join ".git") # Fake .git directory so is-git-repo check passes

  # Mock git remote for upsert-repo to get remote URL
  mock register git {
    args: ['remote' 'get-url' 'origin']
    returns: "git@github.com:test/repo.git"
  }

  init-database

  # Create some data
  let repo = upsert-repo $git_dir
  let list = upsert-list "Test List" "Description" $repo.repo_id

  # Mock git init for sync-init
  mock register git {
    args: ['init' '--quiet']
    returns: ""
  }

  # Initialize sync
  sync-init null

  # Mock git pull (for sync-export)
  mock register git {
    args: ['pull']
    returns: "Already up to date."
  }

  # Mock git add and status for commit
  mock register git {
    args: ['add' '-A']
    returns: ""
  }
  mock register git {
    args: ['status' '--porcelain']
    returns: "M repos.jsonl\nM lists.jsonl"
  }
  mock register git {
    args: ['commit' '-m' 'Test export' '--quiet']
    returns: ""
  }
  mock register git {
    args: ['remote']
    returns: ""
  }

  # Export (without remote, so push will be skipped)
  let result = sync-export "Test export"

  assert $result.success "sync-export should succeed"

  # Verify sync files were created
  let data = read-sync-files $sync_dir

  assert (($data.repos | length) >= 1) "Should have exported repos"
  assert (($data.lists | length) >= 1) "Should have exported lists"

  # Cleanup
  rm -rf $temp_dir
  mock verify
}
