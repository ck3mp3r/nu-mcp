# Tests for new task schema (migration 0003)
# Tests: task_list, task with parent_id, no position

use std/assert
use test_helpers.nu *

# --- Task List Tests ---

export def "test create-task-list success" [] {
  with-test-db {
    use ../storage.nu [ create-task-list init-database ]

    # Create a repo first
    let repo_id = (create-test-repo)

    let result = create-task-list "Test List" "A description" ["tag1" "tag2"] $repo_id

    assert ($result.success == true)
    assert ($result.name == "Test List")
    assert ($result.id != null)
    assert ($result.repo_id == $repo_id)
  }
}

export def "test get-task-lists returns all statuses" [] {
  with-test-db {
    use ../storage.nu [ create-task-list get-task-lists init-database get-db-path execute-sql ]

    let repo_id = (create-test-repo)

    # Create active and archived lists (explicit_repo_id is 4th positional param)
    let _ = create-task-list "Active List" "" [] $repo_id
    let _ = create-task-list "Archived List" "" [] $repo_id

    # Archive one (direct SQL for now)
    let db_path = get-db-path
    let _ = execute-sql $db_path "UPDATE task_list SET status = 'archived' WHERE name = 'Archived List'" []

    # Get all
    let result = get-task-lists --status "all" --repo-id $repo_id
    assert ($result.success == true)
    assert ($result.count == 2)

    # Get active only
    let active = get-task-lists --status "active" --repo-id $repo_id
    assert ($active.count == 1)
    assert ($active.lists.0.name == "Active List")

    # Get archived only
    let archived = get-task-lists --status "archived" --repo-id $repo_id
    assert ($archived.count == 1)
    assert ($archived.lists.0.name == "Archived List")
  }
}

# --- Task Tests ---

export def "test create-task success" [] {
  with-test-db {
    use ../storage.nu [ create-task-list add-task init-database ]

    let repo_id = (create-test-repo)
    let list = create-task-list "Test List" "" [] $repo_id

    let result = add-task $list.id "Test task content" 2 "todo"

    assert ($result.success == true)
    assert ($result.content == "Test task content")
    assert ($result.priority == 2)
    assert ($result.status == "todo")
  }
}

export def "test create-subtask with parent_id" [] {
  with-test-db {
    use ../storage.nu [ create-task-list add-task add-subtask get-task init-database ]

    let repo_id = (create-test-repo)
    let list = create-task-list "Test List" "" [] $repo_id

    # Create parent task
    let parent = add-task $list.id "Parent task" 1 "todo"
    assert ($parent.success == true)

    # Create subtask
    let subtask = add-subtask $list.id $parent.id "Subtask content" 2 "backlog"
    assert ($subtask.success == true)
    assert ($subtask.parent_id == $parent.id)

    # Verify subtask has correct parent
    let fetched = get-task $list.id $subtask.id
    assert ($fetched.success == true)
    assert ($fetched.task.parent_id == $parent.id)
  }
}

export def "test get-subtasks returns children" [] {
  with-test-db {
    use ../storage.nu [ create-task-list add-task add-subtask get-subtasks init-database ]

    let repo_id = (create-test-repo)
    let list = create-task-list "Test List" "" [] $repo_id

    # Create parent with 2 subtasks
    let parent = add-task $list.id "Parent task" 1 "todo"
    let sub1 = add-subtask $list.id $parent.id "Subtask 1"
    let sub2 = add-subtask $list.id $parent.id "Subtask 2"

    let subtasks = get-subtasks $list.id $parent.id
    assert ($subtasks.success == true)
    assert (($subtasks.tasks | length) == 2)
  }
}

export def "test task has no position field" [] {
  with-test-db {
    use ../storage.nu [ create-task-list add-task get-task init-database ]

    let repo_id = (create-test-repo)
    let list = create-task-list "Test List" "" [] $repo_id
    let task = add-task $list.id "Test task"

    let fetched = get-task $list.id $task.id
    assert ($fetched.success == true)
    # Position should not exist in the task record
    assert ("position" not-in ($fetched.task | columns))
  }
}

export def "test delete-parent-cascades-subtasks" [] {
  with-test-db {
    use ../storage.nu [ create-task-list add-task add-subtask delete-task get-task init-database ]

    let repo_id = (create-test-repo)
    let list = create-task-list "Test List" "" [] $repo_id

    let parent = add-task $list.id "Parent"
    let subtask = add-subtask $list.id $parent.id "Subtask"

    # Delete parent
    let _ = delete-task $list.id $parent.id

    # Subtask should also be deleted (CASCADE)
    let result = get-task $list.id $subtask.id
    assert ($result.success == false)
  }
}

# --- Export/Import Tests ---

export def "test export-data includes repos and repo_id" [] {
  with-test-db {
    use ../storage.nu [ create-task-list add-task create-note export-data init-database ]

    let repo_id = (create-test-repo "github:test/export")
    let list = create-task-list "Export Test" "" [] $repo_id
    let _ = add-task $list.id "Task 1"
    let _ = create-note "Test Note" "Content" [] $repo_id

    let result = export-data

    assert ($result.success == true)
    assert ($result.data.version == "2.0")

    # Repos included
    assert ("repos" in ($result.data | columns))
    assert (($result.data.repos | length) >= 1)

    # Lists have repo_id
    assert (($result.data.lists | length) >= 1)
    assert ("repo_id" in ($result.data.lists.0 | columns))

    # Notes have repo_id
    assert (($result.data.notes | length) >= 1)
    assert ("repo_id" in ($result.data.notes.0 | columns))

    # Notes do NOT have source_id
    assert ("source_id" not-in ($result.data.notes.0 | columns))
  }
}

export def "test import-data requires v2 format with repos" [] {
  with-test-db {
    use ../storage.nu [ import-data init-database ]

    let _ = init-database

    # v1.0 format without repos should fail
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

    # Verify data was imported with correct repo association
    let lists = get-task-lists --status "all" --all-repos
    assert (($lists.lists | length) >= 1)

    let notes = get-notes --all-repos
    assert (($notes.notes | length) >= 1)
  }
}
