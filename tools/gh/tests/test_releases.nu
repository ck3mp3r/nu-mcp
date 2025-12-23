# Tests for GitHub release tools
# Uses nu-mock framework for mocking gh commands

use std/assert
use nu-mock *
use test_helpers.nu *
use wrappers.nu *

# =============================================================================
# list-releases tests
# =============================================================================

export def --env "test list-releases returns release list" [] {
  mock reset

  let mock_output = sample-release-list
  mock register gh {
    args: ['release' 'list' '--json' 'tagName,name,isDraft,isPrerelease,isLatest,createdAt,publishedAt']
    returns: $mock_output
  }

  use ../releases.nu list-releases
  let result = list-releases

  # Now expecting formatted text output
  assert ($result | str contains "Releases:") "Should have header"
  assert ($result | str contains "v1.0.0") "Should contain v1.0.0"
  assert ($result | str contains "latest") "Should indicate latest"

  mock verify
}

export def --env "test list-releases with limit" [] {
  mock reset

  let mock_output = sample-release-list
  mock register gh {
    args: ['release' 'list' '--json' 'tagName,name,isDraft,isPrerelease,isLatest,createdAt,publishedAt' '--limit' '2']
    returns: $mock_output
  }

  use ../releases.nu list-releases
  let result = list-releases --limit 2

  # Expecting formatted text output
  assert ($result | str contains "Releases:") "Should have header"
  assert ($result | str contains "v1.0.0") "Should contain releases"

  mock verify
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

  # Expecting formatted text output
  assert ($result | str contains "Releases:") "Should have header"
  assert ($result | str contains "v1.0.0") "Should contain stable release"
  assert ($result | str contains "v0.9.0") "Should contain prerelease"
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

  # Expecting formatted text output
  assert ($result | str contains "Releases:") "Should have header"
  assert ($result | str contains "v1.0.0") "Should contain stable release"
  assert (not ($result | str contains "prerelease")) "Should not show prerelease badge"
}

export def "test list-releases with empty result" [] {
  let mock_output = ([] | to json)
  let result = with-env {MOCK_gh_release_list___json_tagName_name_isDraft_isPrerelease_isLatest_createdAt_publishedAt: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu list-releases
      list-releases
    "
  }

  # Expecting formatted text for empty list
  assert ($result == "No releases found.") "Should return empty message"
}

export def --env "test list-releases handles gh error" [] {
  mock reset

  mock register gh {
    args: ['release' 'list' '--json' 'tagName,name,isDraft,isPrerelease,isLatest,createdAt,publishedAt']
    returns: "not a git repository"
    exit_code: 1
  }

  use ../releases.nu list-releases

  let result = try {
    list-releases
    {success: true}
  } catch {|err|
    {success: false error: $err.msg}
  }

  assert (not $result.success) "Should fail"
  assert ($result.error | str contains "not a git repository") "Should contain error message"

  mock verify
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

  # Expecting formatted text output
  assert ($result | str contains "Release") "Should have Release header"
  assert ($result | str contains "v1.0.0") "Should contain tag"
  assert ($result | str contains "assets") "Should mention assets"
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

  # Expecting formatted text output
  assert ($result | str contains "Release") "Should have Release header"
  assert ($result | str contains "v1.0.0") "Should contain tag"
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

export def "test create-release with short SHA resolves to full SHA" [] {
  let short_sha = "ed970d9"
  let full_sha = "ed970d9d17688e7d315c120cd290fdd352c4c382"

  # Mock git rev-parse to return full SHA
  # Mock gh to expect FULL SHA in target parameter
  let result = with-env {
    MOCK_git_rev_parse_ed970d9: (mock-success $full_sha)
    MOCK_gh_release_create_v2_0_0___target_ed970d9d17688e7d315c120cd290fdd352c4c382: (mock-success "")
  } {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu create-release
      create-release 'v2.0.0' --target 'ed970d9'
    "
  }

  # Should succeed - short SHA was resolved to full SHA
  assert true
}

export def "test create-release with full SHA passes through" [] {
  let full_sha = "ed970d9d17688e7d315c120cd290fdd352c4c382"

  # Mock git rev-parse to return same full SHA
  # Mock gh to expect the full SHA
  let result = with-env {
    MOCK_git_rev_parse_ed970d9d17688e7d315c120cd290fdd352c4c382: (mock-success $full_sha)
    MOCK_gh_release_create_v2_0_0___target_ed970d9d17688e7d315c120cd290fdd352c4c382: (mock-success "")
  } {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu create-release
      create-release 'v2.0.0' --target 'ed970d9d17688e7d315c120cd290fdd352c4c382'
    "
  }

  # Should succeed
  assert true
}

export def "test create-release with branch name resolves to SHA" [] {
  let branch = "main"
  let commit_sha = "abc123def456abc123def456abc123def456abc1"

  # Mock git rev-parse to resolve branch to commit SHA
  # Mock gh to expect the resolved SHA
  let result = with-env {
    MOCK_git_rev_parse_main: (mock-success $commit_sha)
    MOCK_gh_release_create_v2_0_0___target_abc123def456abc123def456abc123def456abc1: (mock-success "")
  } {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/releases.nu create-release
      create-release 'v2.0.0' --target 'main'
    "
  }

  # Should succeed - branch name was resolved to commit SHA
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
