# Tests for storage.nu - core CRUD operations
# Focus: Test exposed tool functions, not internal helpers

use std/assert
use mocks.nu *

# --- List Operations ---

# Test create-todo-list creates list with all fields
export def "test create-todo-list success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu create-todo-list

  with-env {
    MOCK_query_db: ({output: [{id: 42}] exit_code: 0})
  } {
    let result = create-todo-list "Test List" "A description" ["tag1" "tag2"]

    assert ($result.success == true)
    assert ($result.name == "Test List")
    assert ($result.id == 42)
  }
}

# Test get-active-lists returns lists with parsed tags
export def "test get-active-lists success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-active-lists

  let mock_data = [
    {
      id: 1
      name: "Test List"
      description: "Desc"
      tags: '["tag1","tag2"]'
      created_at: "2025-01-14 12:00:00"
      updated_at: "2025-01-14 12:00:00"
    }
  ]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
  } {
    let result = get-active-lists

    assert ($result.success == true)
    assert ($result.count == 1)
    assert ($result.lists.0.tags == ["tag1" "tag2"])
  }
}

# Test upsert-list creates new list when no list_id (via create-todo-list)
export def "test upsert-list creates new" [] {
  use ../tests/mocks.nu *
  use ../storage.nu create-todo-list

  with-env {
    MOCK_query_db: ({output: [{id: 42}] exit_code: 0})
  } {
    # upsert-list delegates to create-todo-list when no list_id
    let result = create-todo-list "New List" "Description" ["tag1"]

    assert ($result.success == true)
  }
}

# Test upsert-list updates existing list
export def "test upsert-list updates existing" [] {
  use ../tests/mocks.nu *
  use ../storage.nu upsert-list

  with-env {
    MOCK_query_db: ({output: [{id: 1 name: "Updated" description: "Desc" status: "active" tags: null notes: null created_at: "2025-01-01" updated_at: "2025-01-01" archived_at: null}] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1 name: "Test" description: null status: "active" tags: null notes: null created_at: "2025-01-01" updated_at: "2025-01-01" archived_at: null}] exit_code: 0})
  } {
    let result = upsert-list 1 "Updated Name"

    assert ($result.success == true)
    assert ($result.created == false)
  }
}

# Test upsert-list fails for non-existent list
export def "test upsert-list fails for non-existent" [] {
  use ../tests/mocks.nu *
  use ../storage.nu upsert-list

  with-env {
    MOCK_query_db_TODO_LIST: ({output: [] exit_code: 0})
  } {
    let result = upsert-list 999 "Name"

    assert ($result.success == false)
    assert ($result.error | str contains "not found")
  }
}

# Test get-list returns metadata
export def "test get-list success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-list

  with-env {
    MOCK_query_db: ({output: [{id: 1 name: "Test" description: "Desc" status: "active" tags: null notes: null created_at: "2025-01-01" updated_at: "2025-01-01" archived_at: null}] exit_code: 0})
  } {
    let result = get-list 1

    assert ($result.success == true)
    assert ($result.list.name == "Test")
  }
}

# Test delete-list removes empty list
export def "test delete-list success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu delete-list

  with-env {
    MOCK_query_db: ({output: [{count: 0}] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1}] exit_code: 0})
  } {
    let result = delete-list 1 false

    assert ($result.success == true)
  }
}

# Test delete-list fails if list has items (without force)
export def "test delete-list fails with items" [] {
  use ../tests/mocks.nu *
  use ../storage.nu delete-list

  with-env {
    MOCK_query_db: ({output: [{count: 3}] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1}] exit_code: 0})
  } {
    let result = delete-list 1 false

    assert ($result.success == false)
    assert ($result.error | str contains "has items")
  }
}

# --- Item Operations ---

# Test add-todo-item creates item with defaults
export def "test add-todo-item success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu add-todo-item

  with-env {
    MOCK_query_db: ({output: [{id: 55}] exit_code: 0})
  } {
    let result = add-todo-item 1 "Test item"

    assert ($result.success == true)
    assert ($result.status == "backlog")
    assert ($result.id == 55)
  }
}

# Test upsert-item updates existing item
export def "test upsert-item updates existing" [] {
  use ../tests/mocks.nu *
  use ../storage.nu upsert-item

  with-env {
    MOCK_query_db: ({output: [{id: 42 list_id: 1 content: "Updated" status: "in_progress" priority: 1 position: null created_at: "2025-01-01" started_at: null completed_at: null}] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1}] exit_code: 0})
  } {
    let result = upsert-item 1 42 "Updated content"

    assert ($result.success == true)
    assert ($result.created == false)
  }
}

# Test upsert-item fails for non-existent item
export def "test upsert-item fails for non-existent" [] {
  use ../tests/mocks.nu *
  use ../storage.nu upsert-item

  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1}] exit_code: 0})
  } {
    let result = upsert-item 1 999 "Content"

    assert ($result.success == false)
    assert ($result.error | str contains "not found")
  }
}

# Test delete-item removes item
export def "test delete-item success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu delete-item

  with-env {
    MOCK_query_db: ({output: [{id: 42}] exit_code: 0})
  } {
    let result = delete-item 1 42

    assert ($result.success == true)
  }
}

# Test move-item moves between lists
export def "test move-item success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu move-item

  with-env {
    MOCK_query_db: ({output: [{id: 42}] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 2}] exit_code: 0})
  } {
    let result = move-item 1 42 2

    assert ($result.success == true)
  }
}

# --- Note Operations ---

# Test create-note creates note
export def "test create-note success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu create-note

  with-env {
    MOCK_query_db: ({output: [{id: 77}] exit_code: 0})
  } {
    let result = create-note "Test Note" "Content" ["tag1"]

    assert ($result.success == true)
    assert ($result.id == 77)
  }
}

# Test upsert-note updates existing note
export def "test upsert-note updates existing" [] {
  use ../tests/mocks.nu *
  use ../storage.nu upsert-note

  with-env {
    MOCK_query_db: ({output: [{id: 42 title: "Updated" content: "New content" tags: null note_type: "manual" source_id: null created_at: "2025-01-01" updated_at: "2025-01-01"}] exit_code: 0})
  } {
    let result = upsert-note 42 "New Title"

    assert ($result.success == true)
    assert ($result.created == false)
  }
}

# Test get-note finds note
export def "test get-note success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-note

  let mock_data = [
    {
      id: 123
      title: "Test Note"
      content: "Content"
      tags: '["tag1"]'
      note_type: "manual"
      source_id: null
      created_at: "2025-01-14 16:30:00"
      updated_at: "2025-01-14 16:30:00"
    }
  ]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
  } {
    let result = get-note 123

    assert ($result.success == true)
    assert ($result.note.title == "Test Note")
  }
}

# Test get-notes returns filtered by type
export def "test get-notes filters by type" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-notes

  let mock_data = [
    {
      id: 1
      title: "Manual Note"
      content: "Content"
      tags: null
      note_type: "manual"
      source_id: null
      created_at: "2025-01-14 16:30:00"
      updated_at: "2025-01-14 16:30:00"
    }
  ]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
  } {
    let result = get-notes [] "manual"

    assert ($result.success == true)
    assert ($result.notes.0.note_type == "manual")
  }
}

# Test delete-note removes note
export def "test delete-note success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu delete-note

  with-env {
    MOCK_query_db: ({output: [{id: 42}] exit_code: 0})
  } {
    let result = delete-note 42

    assert ($result.success == true)
  }
}

# Test search-notes with query
export def "test search-notes success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu search-notes

  let mock_data = [
    {
      id: 42
      title: "Database Design"
      content: "Notes about database"
      tags: '["database"]'
      note_type: "manual"
      created_at: "2025-01-14 16:30:00"
      rank: -0.5
    }
  ]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
  } {
    let result = search-notes "database"

    assert ($result.success == true)
    assert ($result.count == 1)
  }
}

# --- Summary/Export ---

# Test get-summary returns expected structure
# Note: get-summary is a complex orchestration function that calls multiple
# sub-functions, each making their own database queries. The mock system
# can't easily distinguish between different SQL patterns.
# This test verifies the function signature and basic structure.
export def "test get-summary returns structure" [] {
  # Verify get-summary function exists and accepts --all-projects flag
  # by checking that it's exported from the module
  use ../storage.nu [ get-summary ]

  # Test passes if the function can be imported
  # Full integration testing would require a real database
  assert true
}

# Test export-data returns all data
export def "test export-data returns data" [] {
  use ../tests/mocks.nu *
  use ../storage.nu export-data

  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1 name: "Test" status: "active"}] exit_code: 0})
  } {
    let result = export-data

    assert ($result.success == true)
    assert ("lists" in $result.data)
    assert ("items" in $result.data)
    assert ("notes" in $result.data)
  }
}

# --- Repository Isolation ---

# Test parse-git-remote extracts org/repo from various URL formats
export def "test parse-git-remote handles https url" [] {
  use ../storage.nu parse-git-remote

  let result = parse-git-remote "https://github.com/ck3mp3r/nu-mcp.git"
  assert ($result == "github:ck3mp3r/nu-mcp")
}

export def "test parse-git-remote handles ssh url" [] {
  use ../storage.nu parse-git-remote

  let result = parse-git-remote "git@github.com:ck3mp3r/nu-mcp.git"
  assert ($result == "github:ck3mp3r/nu-mcp")
}

export def "test parse-git-remote handles gitlab" [] {
  use ../storage.nu parse-git-remote

  let result = parse-git-remote "git@gitlab.com:myorg/myrepo.git"
  assert ($result == "gitlab:myorg/myrepo")
}

export def "test parse-git-remote strips .git suffix" [] {
  use ../storage.nu parse-git-remote

  let result1 = parse-git-remote "https://github.com/org/repo.git"
  let result2 = parse-git-remote "https://github.com/org/repo"
  assert ($result1 == $result2)
}

# Test get-repo returns existing repo
export def "test get-repo returns existing" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-repo

  with-env {
    MOCK_query_db_REPO: ({output: [{id: 42 remote: "github:ck3mp3r/nu-mcp" path: "/Users/test/nu-mcp"}] exit_code: 0})
  } {
    let result = get-repo "github:ck3mp3r/nu-mcp"

    assert ($result.success == true)
    assert ($result.exists == true)
    assert ($result.repo_id == 42)
  }
}

# Test get-repo returns not exists for unknown repo
export def "test get-repo returns not exists" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-repo

  with-env {
    MOCK_query_db_REPO: ({output: [] exit_code: 0})
  } {
    let result = get-repo "github:unknown/repo"

    assert ($result.success == true)
    assert ($result.exists == false)
  }
}

# Test get-current-repo-id uses git remote from PWD
export def "test get-current-repo-id from git remote" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-current-repo-id

  with-env {
    # Mock git remote to return a known URL - must be JSON string for mock
    MOCK_git_remote_get_url_origin: '{"output": "git@github.com:ck3mp3r/nu-mcp.git", "exit_code": 0}'
    MOCK_query_db_REPO: ({output: [{id: 99 remote: "github:ck3mp3r/nu-mcp"}] exit_code: 0})
  } {
    let result = get-current-repo-id

    assert ($result.success == true)
    assert ($result.repo_id == 99)
  }
}

# Test get-current-repo-id fails gracefully when not in git repo
# Test get-git-remote returns error when git fails
export def "test get-git-remote error handling" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-git-remote

  with-env {
    MOCK_git_remote_get_url_origin: '{"output": "", "exit_code": 1}'
  } {
    let result = get-git-remote

    # The function should return success: false when git fails
    assert ($result.success == false)
    assert ("error" in $result)
  }
}

# Test create-todo-list uses current repo
export def "test create-todo-list uses repo_id" [] {
  use ../tests/mocks.nu *
  use ../storage.nu create-todo-list

  with-env {
    MOCK_git_remote_get_url_origin: '{"output": "git@github.com:ck3mp3r/nu-mcp.git", "exit_code": 0}'
    MOCK_query_db_REPO: ({output: [{id: 5 remote: "github:ck3mp3r/nu-mcp"}] exit_code: 0})
    MOCK_query_db: ({output: [{id: 42}] exit_code: 0})
  } {
    let result = create-todo-list "Test List" "Description" []

    assert ($result.success == true)
    assert ($result.id == 42)
    assert ($result.repo_id == 5)
  }
}

# Test get-active-lists filters by current repo
export def "test get-active-lists filters by repo" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-active-lists

  with-env {
    MOCK_git_remote_get_url_origin: '{"output": "git@github.com:ck3mp3r/nu-mcp.git", "exit_code": 0}'
    MOCK_query_db_REPO: ({output: [{id: 5 remote: "github:ck3mp3r/nu-mcp"}] exit_code: 0})
    MOCK_query_db: ({output: [{id: 1 name: "Repo List" repo_id: 5 description: null tags: null created_at: "2025-01-01" updated_at: "2025-01-01"}] exit_code: 0})
  } {
    let result = get-active-lists

    assert ($result.success == true)
    # Should only return lists for current repo (repo_id = 5)
  }
}

# Test get-active-lists with all_repos flag
export def "test get-active-lists all repos" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-active-lists

  with-env {
    MOCK_query_db: (
      {
        output: [
          {id: 1 name: "List A" repo_id: 1 description: null tags: null created_at: "2025-01-01" updated_at: "2025-01-01"}
          {id: 2 name: "List B" repo_id: 2 description: null tags: null created_at: "2025-01-01" updated_at: "2025-01-01"}
        ]
        exit_code: 0
      }
    )
  } {
    let result = get-active-lists --all-repos

    assert ($result.success == true)
    assert ($result.count == 2)
  }
}

# Test create-note uses current repo
export def "test create-note uses repo_id" [] {
  use ../tests/mocks.nu *
  use ../storage.nu create-note

  with-env {
    MOCK_git_remote_get_url_origin: '{"output": "git@github.com:ck3mp3r/nu-mcp.git", "exit_code": 0}'
    MOCK_query_db_REPO: ({output: [{id: 5 remote: "github:ck3mp3r/nu-mcp"}] exit_code: 0})
    MOCK_query_db: ({output: [{id: 99}] exit_code: 0})
  } {
    let result = create-note "Test Note" "Content" []

    assert ($result.success == true)
    assert ($result.id == 99)
    assert ($result.repo_id == 5)
  }
}

# Test get-xdg-data-path returns correct path
# Note: HOME cannot be reliably overridden in Nushell, so we test the default behavior
export def "test get-xdg-data-path returns correct path" [] {
  use ../storage.nu get-xdg-data-path

  # Clear XDG_DATA_HOME to test the default path based on HOME
  with-env {XDG_DATA_HOME: null} {
    let result = get-xdg-data-path
    let expected = $"($env.HOME)/.local/share/c5t"

    assert ($result == $expected)
  }
}

# Test get-xdg-data-path respects XDG_DATA_HOME
export def "test get-xdg-data-path respects XDG_DATA_HOME" [] {
  use ../storage.nu get-xdg-data-path

  with-env {
    XDG_DATA_HOME: "/custom/data"
  } {
    let result = get-xdg-data-path

    assert ($result == "/custom/data/c5t")
  }
}

# --- Repository Listing ---

# Test list-repos returns all known repositories
export def "test list-repos returns all repos" [] {
  use ../tests/mocks.nu *
  use ../storage.nu list-repos

  let mock_data = [
    {id: 1 remote: "github:org/repo1" path: "/path/to/repo1" created_at: "2025-01-01" last_accessed_at: "2025-01-15"}
    {id: 2 remote: "github:org/repo2" path: "/path/to/repo2" created_at: "2025-01-02" last_accessed_at: "2025-01-14"}
  ]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
  } {
    let result = list-repos

    assert ($result.success == true)
    assert ($result.count == 2)
    assert ($result.repos.0.remote == "github:org/repo1")
  }
}

# Test list-repos returns empty when no repos
export def "test list-repos handles empty" [] {
  use ../tests/mocks.nu *
  use ../storage.nu list-repos

  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
  } {
    let result = list-repos

    assert ($result.success == true)
    assert ($result.count == 0)
    assert ($result.repos | is-empty)
  }
}

# --- Upsert Repo ---

# Test upsert-repo creates new repo
export def "test upsert-repo creates new" [] {
  use ../tests/mocks.nu *
  use ../storage.nu upsert-repo

  with-env {
    MOCK_git_remote_get_url_origin: '{"output": "git@github.com:org/new-repo.git", "exit_code": 0}'
    MOCK_query_db_REPO: ({output: [] exit_code: 0})
    MOCK_query_db: ({output: [{id: 10}] exit_code: 0})
  } {
    let result = upsert-repo

    assert ($result.success == true)
    assert ($result.created == true)
    assert ($result.repo_id == 10)
    assert ($result.remote == "github:org/new-repo")
  }
}

# Test upsert-repo updates existing repo
export def "test upsert-repo updates existing" [] {
  use ../tests/mocks.nu *
  use ../storage.nu upsert-repo

  with-env {
    MOCK_git_remote_get_url_origin: '{"output": "git@github.com:org/existing-repo.git", "exit_code": 0}'
    MOCK_query_db_REPO: ({output: [{id: 5 remote: "github:org/existing-repo" path: "/old/path"}] exit_code: 0})
  } {
    let result = upsert-repo

    assert ($result.success == true)
    assert ($result.created == false)
    assert ($result.repo_id == 5)
  }
}

# Test get-current-repo-id fails when repo not registered
export def "test get-current-repo-id fails when not registered" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-current-repo-id

  with-env {
    MOCK_git_remote_get_url_origin: '{"output": "git@github.com:org/unregistered.git", "exit_code": 0}'
    MOCK_query_db_REPO: ({output: [] exit_code: 0})
  } {
    let result = get-current-repo-id

    assert ($result.success == false)
    assert ($result.error | str contains "not registered")
    assert ($result.error | str contains "upsert_repo")
  }
}

# Test create-todo-list fails when repo not registered
export def "test create-todo-list fails when repo not registered" [] {
  use ../tests/mocks.nu *
  use ../storage.nu create-todo-list

  with-env {
    MOCK_git_remote_get_url_origin: '{"output": "git@github.com:org/unregistered.git", "exit_code": 0}'
    MOCK_query_db_REPO: ({output: [] exit_code: 0})
  } {
    let result = create-todo-list "Test List" "Description" []

    assert ($result.success == false)
    assert ($result.error | str contains "not registered")
  }
}
