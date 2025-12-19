# Tests for upsert functions with proper required/optional params
# TDD: Write tests first, then implement

use std/assert
use test_helpers.nu *

# =============================================================================
# UPSERT-LIST TESTS
# Signature: upsert-list [name: string, description: string, repo_id: string, 
#            --list-id: string, --tags: list, --notes: string, --external-ref: string]
# =============================================================================

export def "test upsert-list create requires name description repo_id" [] {
  with-test-db {
    use ../storage.nu [ upsert-list init-database ]

    let repo_id = (create-test-repo)

    let result = upsert-list "My List" "A description" $repo_id

    assert ($result.success == true)
    assert ($result.created == true)
    assert ($result.name == "My List")
    assert ($result.description == "A description")
    assert ($result.repo_id == $repo_id)
    assert (($result.id | str length) == 8)
  }
}

export def "test upsert-list create with optional tags" [] {
  with-test-db {
    use ../storage.nu [ upsert-list get-list init-database ]

    let repo_id = (create-test-repo)

    let result = upsert-list "Tagged List" "Description" $repo_id --tags ["tag1" "tag2"]

    assert ($result.success == true)
    assert ($result.tags == ["tag1" "tag2"])

    let fetched = get-list $result.id
    assert ($fetched.list.tags == ["tag1" "tag2"])
  }
}

export def "test upsert-list create with external_ref" [] {
  with-test-db {
    use ../storage.nu [ upsert-list get-list init-database ]

    let repo_id = (create-test-repo)

    let result = upsert-list "JIRA List" "Sprint work" $repo_id --external-ref "PROJ-123"

    assert ($result.success == true)
    assert ($result.external_ref == "PROJ-123")

    let fetched = get-list $result.id
    assert ($fetched.list.external_ref == "PROJ-123")
  }
}

export def "test upsert-list update with list_id" [] {
  with-test-db {
    use ../storage.nu [ upsert-list get-list init-database ]

    let repo_id = (create-test-repo)

    # Create
    let created = upsert-list "Original" "Original desc" $repo_id
    assert ($created.success == true)

    # Update - still need name/description/repo_id but can change them
    let updated = upsert-list "Updated Name" "Updated desc" $repo_id --list-id $created.id
    assert ($updated.success == true)
    assert ($updated.created == false)

    let fetched = get-list $created.id
    assert ($fetched.list.name == "Updated Name")
    assert ($fetched.list.description == "Updated desc")
  }
}

export def "test upsert-list update adds external_ref" [] {
  with-test-db {
    use ../storage.nu [ upsert-list get-list init-database ]

    let repo_id = (create-test-repo)

    # Create without external_ref
    let created = upsert-list "List" "Desc" $repo_id
    assert ($created.external_ref == null)

    # Update with external_ref
    let updated = upsert-list "List" "Desc" $repo_id --list-id $created.id --external-ref "GH-456"
    assert ($updated.success == true)

    let fetched = get-list $created.id
    assert ($fetched.list.external_ref == "GH-456")
  }
}

# =============================================================================
# UPSERT-TASK TESTS
# Signature: upsert-task [list_id: string, content: string,
#            --task-id: string, --priority: int = 3, --status: string = "backlog", --parent-id: string]
# =============================================================================

export def "test upsert-task create requires list_id and content" [] {
  with-test-db {
    use ../storage.nu [ upsert-list upsert-task init-database ]

    let repo_id = (create-test-repo)
    let list = upsert-list "Test List" "Desc" $repo_id

    let result = upsert-task $list.id "My task content"

    assert ($result.success == true)
    assert ($result.created == true)
    assert ($result.content == "My task content")
    assert ($result.list_id == $list.id)
    assert (($result.id | str length) == 8)
  }
}

export def "test upsert-task create has default priority 3" [] {
  with-test-db {
    use ../storage.nu [ upsert-list upsert-task get-task init-database ]

    let repo_id = (create-test-repo)
    let list = upsert-list "Test List" "Desc" $repo_id

    let result = upsert-task $list.id "Task with default priority"

    assert ($result.success == true)
    assert ($result.priority == 3)

    let fetched = get-task $list.id $result.id
    assert ($fetched.task.priority == 3)
  }
}

export def "test upsert-task create has default status backlog" [] {
  with-test-db {
    use ../storage.nu [ upsert-list upsert-task get-task init-database ]

    let repo_id = (create-test-repo)
    let list = upsert-list "Test List" "Desc" $repo_id

    let result = upsert-task $list.id "Task with default status"

    assert ($result.success == true)
    assert ($result.status == "backlog")

    let fetched = get-task $list.id $result.id
    assert ($fetched.task.status == "backlog")
  }
}

export def "test upsert-task create with custom priority and status" [] {
  with-test-db {
    use ../storage.nu [ upsert-list upsert-task init-database ]

    let repo_id = (create-test-repo)
    let list = upsert-list "Test List" "Desc" $repo_id

    let result = upsert-task $list.id "High priority task" --priority 1 --status "todo"

    assert ($result.success == true)
    assert ($result.priority == 1)
    assert ($result.status == "todo")
  }
}

export def "test upsert-task create subtask with parent_id" [] {
  with-test-db {
    use ../storage.nu [ upsert-list upsert-task get-task init-database ]

    let repo_id = (create-test-repo)
    let list = upsert-list "Test List" "Desc" $repo_id

    let parent = upsert-task $list.id "Parent task"
    let subtask = upsert-task $list.id "Subtask" --parent-id $parent.id

    assert ($subtask.success == true)
    assert ($subtask.parent_id == $parent.id)

    let fetched = get-task $list.id $subtask.id
    assert ($fetched.task.parent_id == $parent.id)
  }
}

export def "test upsert-task update with task_id" [] {
  with-test-db {
    use ../storage.nu [ upsert-list upsert-task get-task init-database ]

    let repo_id = (create-test-repo)
    let list = upsert-list "Test List" "Desc" $repo_id

    # Create
    let created = upsert-task $list.id "Original content"

    # Update
    let updated = upsert-task $list.id "Updated content" --task-id $created.id --status "in_progress"
    assert ($updated.success == true)
    assert ($updated.created == false)

    let fetched = get-task $list.id $created.id
    assert ($fetched.task.content == "Updated content")
    assert ($fetched.task.status == "in_progress")
  }
}

# =============================================================================
# UPSERT-NOTE TESTS
# Signature: upsert-note [title: string, content: string, repo_id: string,
#            --note-id: string, --tags: list]
# =============================================================================

export def "test upsert-note create requires title content repo_id" [] {
  with-test-db {
    use ../storage.nu [ upsert-note init-database ]

    let repo_id = (create-test-repo)

    let result = upsert-note "My Note" "Note content here" $repo_id

    assert ($result.success == true)
    assert ($result.created == true)
    assert ($result.title == "My Note")
    assert ($result.repo_id == $repo_id)
    assert (($result.id | str length) == 8)
  }
}

export def "test upsert-note create with tags" [] {
  with-test-db {
    use ../storage.nu [ upsert-note get-note init-database ]

    let repo_id = (create-test-repo)

    let result = upsert-note "Tagged Note" "Content" $repo_id --tags ["session" "important"]

    assert ($result.success == true)
    assert ($result.tags == ["session" "important"])

    let fetched = get-note $result.id
    assert ($fetched.note.tags == ["session" "important"])
  }
}

export def "test upsert-note update with note_id" [] {
  with-test-db {
    use ../storage.nu [ upsert-note get-note init-database ]

    let repo_id = (create-test-repo)

    # Create
    let created = upsert-note "Original Title" "Original content" $repo_id

    # Update
    let updated = upsert-note "Updated Title" "Updated content" $repo_id --note-id $created.id
    assert ($updated.success == true)
    assert ($updated.created == false)

    let fetched = get-note $created.id
    assert ($fetched.note.title == "Updated Title")
    assert ($fetched.note.content == "Updated content")
  }
}

# =============================================================================
# ADDITIONAL TESTS (kept from original)
# =============================================================================

export def "test get-task-lists returns all statuses" [] {
  with-test-db {
    use ../storage.nu [ upsert-list get-task-lists init-database get-db-path execute-sql ]

    let repo_id = (create-test-repo)

    let _ = upsert-list "Active List" "Desc" $repo_id
    let _ = upsert-list "Archived List" "Desc" $repo_id

    # Archive one
    let db_path = get-db-path
    let _ = execute-sql $db_path "UPDATE task_list SET status = 'archived' WHERE name = 'Archived List'" []

    let result = get-task-lists --status "all" --repo-id $repo_id
    assert ($result.success == true)
    assert ($result.count == 2)

    let active = get-task-lists --status "active" --repo-id $repo_id
    assert ($active.count == 1)

    let archived = get-task-lists --status "archived" --repo-id $repo_id
    assert ($archived.count == 1)
  }
}

export def "test get-subtasks returns children" [] {
  with-test-db {
    use ../storage.nu [ upsert-list upsert-task get-subtasks init-database ]

    let repo_id = (create-test-repo)
    let list = upsert-list "Test List" "Desc" $repo_id

    let parent = upsert-task $list.id "Parent task"
    let _ = upsert-task $list.id "Subtask 1" --parent-id $parent.id
    let _ = upsert-task $list.id "Subtask 2" --parent-id $parent.id

    let subtasks = get-subtasks $list.id $parent.id
    assert ($subtasks.success == true)
    assert (($subtasks.tasks | length) == 2)
  }
}

export def "test delete-parent-cascades-subtasks" [] {
  with-test-db {
    use ../storage.nu [ upsert-list upsert-task delete-task get-task init-database ]

    let repo_id = (create-test-repo)
    let list = upsert-list "Test List" "Desc" $repo_id

    let parent = upsert-task $list.id "Parent"
    let subtask = upsert-task $list.id "Subtask" --parent-id $parent.id

    let _ = delete-task $list.id $parent.id

    let result = get-task $list.id $subtask.id
    assert ($result.success == false)
  }
}

export def "test export-data includes repos and repo_id" [] {
  with-test-db {
    use ../storage.nu [ upsert-list upsert-task upsert-note export-data init-database ]

    let repo_id = (create-test-repo "github:test/export")
    let list = upsert-list "Export Test" "Desc" $repo_id
    let _ = upsert-task $list.id "Task 1"
    let _ = upsert-note "Test Note" "Content" $repo_id

    let result = export-data

    assert ($result.success == true)
    assert ($result.data.version == "2.0")
    assert ("repos" in ($result.data | columns))
    assert (($result.data.repos | length) >= 1)
    assert (($result.data.lists | length) >= 1)
    assert ("repo_id" in ($result.data.lists.0 | columns))
    assert (($result.data.notes | length) >= 1)
    assert ("repo_id" in ($result.data.notes.0 | columns))
  }
}

export def "test import-data requires v2 format with repos" [] {
  with-test-db {
    use ../storage.nu [ import-data init-database ]

    let _ = init-database

    let v1_data = {
      version: "1.0"
      lists: []
      items: []
      notes: []
    }

    let result = import-data $v1_data
    assert ($result.success == false)
    assert ($result.error | str contains "repos")
  }
}

export def "test import-data restores with repo_id mapping" [] {
  with-test-db {
    use ../storage.nu [ import-data get-task-lists get-notes init-database ]

    let _ = init-database

    let import_data = {
      version: "2.0"
      repos: [
        {id: 100 remote: "github:imported/repo" path: "/tmp/imported"}
      ]
      lists: [
        {id: 200 repo_id: 100 name: "Imported List" status: "active" tags: null}
      ]
      tasks: [
        {id: 300 list_id: 200 parent_id: null content: "Imported Task" status: "todo"}
      ]
      notes: [
        {id: 400 repo_id: 100 title: "Imported Note" content: "Content" note_type: "manual"}
      ]
    }

    let result = import-data $import_data
    assert ($result.success == true)
    assert ($result.imported.repos == 1)
    assert ($result.imported.lists == 1)
    assert ($result.imported.tasks == 1)
    assert ($result.imported.notes == 1)

    let lists = get-task-lists --status "all" --all-repos
    assert (($lists.lists | length) >= 1)

    let notes = get-notes --all-repos
    assert (($notes.notes | length) >= 1)
  }
}
