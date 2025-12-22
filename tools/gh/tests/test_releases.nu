# Tests for GitHub release tools
# Mocks must be imported BEFORE the module under test

use std/assert
use test_helpers.nu *

# Helper to create mock JSON for success
def mock-success [output: string] {
  {exit_code: 0 output: $output} | to json
}

# Helper to create mock JSON for error
def mock-error [error: string] {
  {exit_code: 1 error: $error output: ""} | to json
}

# =============================================================================
# list-releases tests
# =============================================================================

export def "test list-releases returns release list" [] {
  let mock_output = sample-release-list
  # Key: release_list___json_tagName_name_isDraft_isPrerelease_isLatest_createdAt_publishedAt
  let result = with-env {MOCK_gh_release_list___json_tagName_name_isDraft_isPrerelease_isLatest_createdAt_publishedAt: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu list-releases
      list-releases
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 3) "Should return 3 releases"
  assert (($parsed | get 0 | get tagName) == "v1.0.0") "First release should be v1.0.0"
  assert (($parsed | get 0 | get isLatest) == true) "First release should be latest"
}

export def "test list-releases with limit" [] {
  let mock_output = sample-release-list
  let result = with-env {MOCK_gh_release_list___json_tagName_name_isDraft_isPrerelease_isLatest_createdAt_publishedAt___limit_2: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu list-releases
      list-releases --limit 2
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 3) "Should return releases"
}

export def "test list-releases exclude drafts" [] {
  let mock_output = (
    [
      {tagName: "v1.0.0" name: "Release v1.0.0" isDraft: false isPrerelease: false isLatest: true createdAt: "2025-01-15T10:00:00Z" publishedAt: "2025-01-15T10:05:00Z"}
      {tagName: "v0.9.0" name: "Beta v0.9.0" isDraft: false isPrerelease: true isLatest: false createdAt: "2025-01-10T10:00:00Z" publishedAt: "2025-01-10T10:05:00Z"}
    ] | to json
  )
  let result = with-env {MOCK_gh_release_list___json_tagName_name_isDraft_isPrerelease_isLatest_createdAt_publishedAt___exclude_drafts: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu list-releases
      list-releases --exclude-drafts
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return only non-draft releases"
}

export def "test list-releases exclude prereleases" [] {
  let mock_output = (
    [
      {tagName: "v1.0.0" name: "Release v1.0.0" isDraft: false isPrerelease: false isLatest: true createdAt: "2025-01-15T10:00:00Z" publishedAt: "2025-01-15T10:05:00Z"}
    ] | to json
  )
  let result = with-env {MOCK_gh_release_list___json_tagName_name_isDraft_isPrerelease_isLatest_createdAt_publishedAt___exclude_pre_releases: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu list-releases
      list-releases --exclude-prereleases
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 1) "Should return only stable releases"
}

export def "test list-releases with empty result" [] {
  let result = with-env {MOCK_gh_release_list___json_tagName_name_isDraft_isPrerelease_isLatest_createdAt_publishedAt: (mock-success "[]")} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu list-releases
      list-releases
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 0) "Should return empty list"
}

export def "test list-releases handles gh error" [] {
  let result = with-env {MOCK_gh_release_list___json_tagName_name_isDraft_isPrerelease_isLatest_createdAt_publishedAt: (mock-error "not a git repository")} {
    do {
      nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu list-releases
      list-releases
    "
    } | complete
  }

  assert ($result.exit_code != 0) "Should fail"
  assert ($result.stderr | str contains "not a git repository") "Should contain error message"
}

# =============================================================================
# get-release tests
# =============================================================================

export def "test get-release returns single release" [] {
  let mock_output = sample-release
  let result = with-env {MOCK_gh_release_view_v1_0_0___json_tagName_name_body_isDraft_isPrerelease_createdAt_publishedAt_author_url_assets: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu get-release
      get-release 'v1.0.0'
    "
  }
  let parsed = $result | from json

  assert (($parsed | get tagName) == "v1.0.0") "Should return v1.0.0"
  assert (($parsed | get isDraft) == false) "Should not be draft"
  assert ("assets" in $parsed) "Should have assets field"
}

export def "test get-release handles non-existent tag" [] {
  let result = with-env {MOCK_gh_release_view_v99_99_99___json_tagName_name_body_isDraft_isPrerelease_createdAt_publishedAt_author_url_assets: (mock-error "release not found")} {
    do {
      nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu get-release
      get-release 'v99.99.99'
    "
    } | complete
  }

  assert ($result.exit_code != 0) "Should fail"
  assert ($result.stderr | str contains "release not found") "Should contain error message"
}

export def "test get-release with latest" [] {
  let mock_output = sample-release
  let result = with-env {MOCK_gh_release_view___json_tagName_name_body_isDraft_isPrerelease_createdAt_publishedAt_author_url_assets: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu get-release
      get-release
    "
  }
  let parsed = $result | from json

  assert (($parsed | get tagName) == "v1.0.0") "Should return latest release"
}

# =============================================================================
# create-release tests
# =============================================================================

export def "test create-release with basic args" [] {
  let result = with-env {MOCK_gh_release_create_v2_0_0___notes_New_release: (mock-success "")} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu create-release
      create-release 'v2.0.0' --notes 'New release'
    "
  }

  # Should succeed without error
  assert true
}

export def "test create-release as draft" [] {
  let result = with-env {MOCK_gh_release_create_v2_0_0___draft: (mock-success "")} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu create-release
      create-release 'v2.0.0' --draft
    "
  }

  # Should succeed
  assert true
}

export def "test create-release as prerelease" [] {
  let result = with-env {MOCK_gh_release_create_v2_0_0___prerelease: (mock-success "")} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu create-release
      create-release 'v2.0.0' --prerelease
    "
  }

  # Should succeed
  assert true
}

# =============================================================================
# edit-release tests
# =============================================================================

export def "test edit-release updates notes" [] {
  let result = with-env {MOCK_gh_release_edit_v1_0_0___notes_New_notes: (mock-success "")} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu edit-release
      edit-release 'v1.0.0' --notes 'New notes'
    "
  }

  # Should succeed without error
  assert true
}

export def "test edit-release updates title" [] {
  let result = with-env {MOCK_gh_release_edit_v1_0_0___title_New_Title: (mock-success "")} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu edit-release
      edit-release 'v1.0.0' --title 'New Title'
    "
  }

  # Should succeed
  assert true
}

export def "test edit-release sets draft true" [] {
  let result = with-env {MOCK_gh_release_edit_v1_0_0___draft: (mock-success "")} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu edit-release
      edit-release 'v1.0.0' --draft
    "
  }

  # Should succeed
  assert true
}

export def "test edit-release sets draft false" [] {
  let result = with-env {MOCK_gh_release_edit_v1_0_0___draft_false: (mock-success "")} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu edit-release
      edit-release 'v1.0.0' --no-draft
    "
  }

  # Should succeed
  assert true
}

export def "test edit-release sets prerelease" [] {
  let result = with-env {MOCK_gh_release_edit_v1_0_0___prerelease: (mock-success "")} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu edit-release
      edit-release 'v1.0.0' --prerelease
    "
  }

  # Should succeed
  assert true
}

# =============================================================================
# delete-release tests
# =============================================================================

export def "test delete-release basic" [] {
  let result = with-env {
    MOCK_gh_release_delete_v1_0_0___yes: (mock-success "")
    MCP_GITHUB_MODE: "destructive"
  } {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu delete-release
      delete-release 'v1.0.0'
    "
  }

  # Should succeed
  assert true
}

export def "test delete-release with cleanup-tag" [] {
  let result = with-env {
    MOCK_gh_release_delete_v1_0_0___yes___cleanup_tag: (mock-success "")
    MCP_GITHUB_MODE: "destructive"
  } {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu delete-release
      delete-release 'v1.0.0' --cleanup-tag
    "
  }

  # Should succeed
  assert true
}
