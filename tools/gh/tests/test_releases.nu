# Tests for GitHub release tools
# Uses nu-mimic framework for mocking gh commands

use std/assert
use nu-mimic *
use test_helpers.nu *
use wrappers.nu *

# =============================================================================
# list-releases tests
# =============================================================================

export def --env "test list-releases returns release list" [] {
  with-mimic {
    let mock_output = sample-release-list
    mimic register gh {
      args: ['release' 'list' '--json' 'tagName,name,isDraft,isPrerelease,isLatest,createdAt,publishedAt']
      returns: $mock_output
    }

    use ../releases.nu list-releases
    let result = list-releases

    # Now expecting formatted text output
    assert ($result | str contains "Releases:") "Should have header"
    assert ($result | str contains "v1.0.0") "Should contain v1.0.0"
    assert ($result | str contains "latest") "Should indicate latest"
  }
}

export def --env "test list-releases with limit" [] {
  with-mimic {
    let mock_output = sample-release-list
    mimic register gh {
      args: ['release' 'list' '--json' 'tagName,name,isDraft,isPrerelease,isLatest,createdAt,publishedAt' '--limit' '2']
      returns: $mock_output
    }

    use ../releases.nu list-releases
    let result = list-releases --limit 2

    # Expecting formatted text output
    assert ($result | str contains "Releases:") "Should have header"
    assert ($result | str contains "v1.0.0") "Should contain releases"
  }
}

export def --env "test list-releases exclude drafts" [] {
  with-mimic {
    let mock_output = (
      [
        {tagName: "v1.0.0" name: "Release v1.0.0" isDraft: false isPrerelease: false isLatest: true createdAt: "2025-01-15T10:00:00Z" publishedAt: "2025-01-15T10:05:00Z"}
        {tagName: "v0.9.0" name: "Beta v0.9.0" isDraft: false isPrerelease: true isLatest: false createdAt: "2025-01-10T10:00:00Z" publishedAt: "2025-01-10T10:05:00Z"}
      ] | to json
    )

    mimic register gh {
      args: ['release' 'list' '--json' 'tagName,name,isDraft,isPrerelease,isLatest,createdAt,publishedAt' '--exclude-drafts']
      returns: $mock_output
    }

    use ../releases.nu list-releases
    let result = list-releases --exclude-drafts

    # Expecting formatted text output
    assert ($result | str contains "Releases:") "Should have header"
    assert ($result | str contains "v1.0.0") "Should contain stable release"
    assert ($result | str contains "v0.9.0") "Should contain prerelease"
  }
}

export def --env "test list-releases exclude prereleases" [] {
  with-mimic {
    let mock_output = (
      [
        {tagName: "v1.0.0" name: "Release v1.0.0" isDraft: false isPrerelease: false isLatest: true createdAt: "2025-01-15T10:00:00Z" publishedAt: "2025-01-15T10:05:00Z"}
      ] | to json
    )

    mimic register gh {
      args: ['release' 'list' '--json' 'tagName,name,isDraft,isPrerelease,isLatest,createdAt,publishedAt' '--exclude-pre-releases']
      returns: $mock_output
    }

    use ../releases.nu list-releases
    let result = list-releases --exclude-prereleases

    # Expecting formatted text output
    assert ($result | str contains "Releases:") "Should have header"
    assert ($result | str contains "v1.0.0") "Should contain stable release"
    assert (not ($result | str contains "prerelease")) "Should not show prerelease badge"
  }
}

export def --env "test list-releases with empty result" [] {
  with-mimic {
    let mock_output = ([] | to json)

    mimic register gh {
      args: ['release' 'list' '--json' 'tagName,name,isDraft,isPrerelease,isLatest,createdAt,publishedAt']
      returns: $mock_output
    }

    use ../releases.nu list-releases
    let result = list-releases

    # Expecting formatted text for empty list
    assert ($result == "No releases found.") "Should return empty message"
  }
}

export def --env "test list-releases handles gh error" [] {
  with-mimic {
    mimic register gh {
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
  }
}

# =============================================================================
# get-release tests
# =============================================================================

export def --env "test get-release returns single release" [] {
  with-mimic {
    let mock_output = sample-release

    mimic register gh {
      args: ['release' 'view' 'v1.0.0' '--json' 'tagName,name,body,isDraft,isPrerelease,createdAt,publishedAt,author,url,assets']
      returns: $mock_output
    }

    use ../releases.nu get-release
    let result = get-release 'v1.0.0'

    # Expecting formatted text output
    assert ($result | str contains "Release") "Should have Release header"
    assert ($result | str contains "v1.0.0") "Should contain tag"
    assert ($result | str contains "assets") "Should mention assets"
  }
}

export def --env "test get-release handles non-existent tag" [] {
  with-mimic {
    mimic register gh {
      args: ['release' 'view' 'v99.99.99' '--json' 'tagName,name,body,isDraft,isPrerelease,createdAt,publishedAt,author,url,assets']
      returns: "release not found"
      exit_code: 1
    }

    use ../releases.nu get-release

    let result = try {
      get-release 'v99.99.99'
      {success: true}
    } catch {|err|
      {success: false error: $err.msg}
    }

    assert (not $result.success) "Should fail"
    assert ($result.error | str contains "release not found") "Should contain error message"
  }
}

export def --env "test get-release with latest" [] {
  with-mimic {
    let mock_output = sample-release

    mimic register gh {
      args: ['release' 'view' '--json' 'tagName,name,body,isDraft,isPrerelease,createdAt,publishedAt,author,url,assets']
      returns: $mock_output
    }

    use ../releases.nu get-release
    let result = get-release

    # Expecting formatted text output
    assert ($result | str contains "Release") "Should have Release header"
    assert ($result | str contains "v1.0.0") "Should contain tag"
  }
}

# =============================================================================
# create-release tests
# =============================================================================

export def --env "test create-release with basic args" [] {
  with-mimic {
    mimic register gh {
      args: ['release' 'create' 'v2.0.0' '--notes' 'New release']
      returns: ""
    }

    use ../releases.nu create-release
    create-release 'v2.0.0' --notes 'New release'

    # Should succeed without error
    assert true
  }
}

export def --env "test create-release as draft" [] {
  with-mimic {
    mimic register gh {
      args: ['release' 'create' 'v2.0.0' '--draft']
      returns: ""
    }

    use ../releases.nu create-release
    create-release 'v2.0.0' --draft

    # Should succeed
    assert true
  }
}

export def --env "test create-release as prerelease" [] {
  with-mimic {
    mimic register gh {
      args: ['release' 'create' 'v2.0.0' '--prerelease']
      returns: ""
    }

    use ../releases.nu create-release
    create-release 'v2.0.0' --prerelease

    # Should succeed
    assert true
  }
}

export def --env "test create-release with short SHA resolves to full SHA" [] {
  with-mimic {
    let short_sha = "ed970d9"
    let full_sha = "ed970d9d17688e7d315c120cd290fdd352c4c382"

    # Mock git rev-parse to return full SHA
    mimic register git {
      args: ['rev-parse' 'ed970d9']
      returns: $full_sha
    }

    # Mock gh to expect FULL SHA in target parameter
    mimic register gh {
      args: ['release' 'create' 'v2.0.0' '--target' 'ed970d9d17688e7d315c120cd290fdd352c4c382']
      returns: ""
    }

    use ../releases.nu create-release
    create-release 'v2.0.0' --target 'ed970d9'

    # Should succeed - short SHA was resolved to full SHA
    assert true
  }
}

export def --env "test create-release with full SHA passes through" [] {
  with-mimic {
    let full_sha = "ed970d9d17688e7d315c120cd290fdd352c4c382"

    # Mock git rev-parse to return same full SHA
    mimic register git {
      args: ['rev-parse' 'ed970d9d17688e7d315c120cd290fdd352c4c382']
      returns: $full_sha
    }

    # Mock gh to expect the full SHA
    mimic register gh {
      args: ['release' 'create' 'v2.0.0' '--target' 'ed970d9d17688e7d315c120cd290fdd352c4c382']
      returns: ""
    }

    use ../releases.nu create-release
    create-release 'v2.0.0' --target 'ed970d9d17688e7d315c120cd290fdd352c4c382'

    # Should succeed
    assert true
  }
}

export def --env "test create-release with branch name resolves to SHA" [] {
  with-mimic {
    let branch = "main"
    let commit_sha = "abc123def456abc123def456abc123def456abc1"

    # Mock git rev-parse to resolve branch to commit SHA
    mimic register git {
      args: ['rev-parse' 'main']
      returns: $commit_sha
    }

    # Mock gh to expect the resolved SHA
    mimic register gh {
      args: ['release' 'create' 'v2.0.0' '--target' 'abc123def456abc123def456abc123def456abc1']
      returns: ""
    }

    use ../releases.nu create-release
    create-release 'v2.0.0' --target 'main'

    # Should succeed - branch name was resolved to commit SHA
    assert true
  }
}

# =============================================================================
# edit-release tests
# =============================================================================

export def --env "test edit-release updates notes" [] {
  with-mimic {
    mimic register gh {
      args: ['release' 'edit' 'v1.0.0' '--notes' 'New notes']
      returns: ""
    }

    use ../releases.nu edit-release
    edit-release 'v1.0.0' --notes 'New notes'

    # Should succeed without error
    assert true
  }
}

export def --env "test edit-release updates title" [] {
  with-mimic {
    mimic register gh {
      args: ['release' 'edit' 'v1.0.0' '--title' 'New Title']
      returns: ""
    }

    use ../releases.nu edit-release
    edit-release 'v1.0.0' --title 'New Title'

    # Should succeed
    assert true
  }
}

export def --env "test edit-release sets draft true" [] {
  with-mimic {
    mimic register gh {
      args: ['release' 'edit' 'v1.0.0' '--draft']
      returns: ""
    }

    use ../releases.nu edit-release
    edit-release 'v1.0.0' --draft

    # Should succeed
    assert true
  }
}

export def --env "test edit-release sets draft false" [] {
  with-mimic {
    mimic register gh {
      args: ['release' 'edit' 'v1.0.0' '--draft=false']
      returns: ""
    }

    use ../releases.nu edit-release
    edit-release 'v1.0.0' --no-draft

    # Should succeed
    assert true
  }
}

export def --env "test edit-release sets prerelease" [] {
  with-mimic {
    mimic register gh {
      args: ['release' 'edit' 'v1.0.0' '--prerelease']
      returns: ""
    }

    use ../releases.nu edit-release
    edit-release 'v1.0.0' --prerelease

    # Should succeed
    assert true
  }
}

# =============================================================================
# delete-release tests
# =============================================================================

export def --env "test delete-release basic" [] {
  with-mimic {
    $env.MCP_GITHUB_MODE = "destructive"

    mimic register gh {
      args: ['release' 'delete' 'v1.0.0' '--yes']
      returns: ""
    }

    use ../releases.nu delete-release
    delete-release 'v1.0.0'

    # Should succeed
    assert true
  }
}

export def --env "test delete-release with cleanup-tag" [] {
  with-mimic {
    $env.MCP_GITHUB_MODE = "destructive"

    mimic register gh {
      args: ['release' 'delete' 'v1.0.0' '--yes' '--cleanup-tag']
      returns: ""
    }

    use ../releases.nu delete-release
    delete-release 'v1.0.0' --cleanup-tag

    # Should succeed
    assert true
  }
}
