#!/usr/bin/env nu

# Tests for GitHub formatters

use std assert

# =============================================================================
# Release List Formatter Tests
# =============================================================================

export def "test format-release-list with multiple releases" [] {
  use ../formatters.nu format-release-list

  let releases = [
    {tagName: "v1.0.0" name: "Release v1.0.0" isDraft: false isPrerelease: false isLatest: true createdAt: "2025-12-22T10:00:00Z" publishedAt: "2025-12-22T10:05:00Z"}
    {tagName: "v0.9.0" name: "Beta v0.9.0" isDraft: false isPrerelease: true isLatest: false createdAt: "2025-12-20T10:00:00Z" publishedAt: "2025-12-20T10:05:00Z"}
    {tagName: "v0.8.0-draft" name: "Draft Release" isDraft: true isPrerelease: false isLatest: false createdAt: "2025-12-15T10:00:00Z" publishedAt: null}
  ]

  let output = format-release-list $releases

  # Should contain header
  assert ($output | str contains "Releases:")

  # Should show all releases
  assert ($output | str contains "v1.0.0")
  assert ($output | str contains "v0.9.0")
  assert ($output | str contains "v0.8.0-draft")

  # Should indicate latest
  assert ($output | str contains "latest")

  # Should indicate prerelease
  assert ($output | str contains "prerelease")

  # Should indicate draft
  assert ($output | str contains "draft")
}

export def "test format-release-list with empty list" [] {
  use ../formatters.nu format-release-list

  let releases = []
  let output = format-release-list $releases

  assert ($output == "No releases found.")
}

export def "test format-release-list shows relative time" [] {
  use ../formatters.nu format-release-list

  # Recent release (within last day)
  let now = date now
  let recent_time = $now - 2hr | format date "%Y-%m-%dT%H:%M:%SZ"

  let releases = [
    {tagName: "v1.0.0" name: "Release v1.0.0" isDraft: false isPrerelease: false isLatest: true createdAt: $recent_time publishedAt: $recent_time}
  ]

  let output = format-release-list $releases

  # Should show relative time like "2h ago"
  assert ($output | str contains "ago")
}

# =============================================================================
# Single Release Formatter Tests  
# =============================================================================

export def "test format-release with full details" [] {
  use ../formatters.nu format-release

  let release = {
    tagName: "v1.0.0"
    name: "Release v1.0.0"
    body: "## What's New\n- Feature A\n- Bug fix B"
    isDraft: false
    isPrerelease: false
    createdAt: "2025-12-22T10:00:00Z"
    publishedAt: "2025-12-22T10:05:00Z"
    author: {login: "ck3mp3r" name: "Christian Kemper"}
    url: "https://github.com/ck3mp3r/nu-mcp/releases/tag/v1.0.0"
    assets: [
      {name: "binary.tar.gz" size: 1024 downloadCount: 42}
      {name: "checksums.txt" size: 256 downloadCount: 10}
    ]
  }

  let output = format-release $release

  # Should contain header
  assert ($output | str contains "Release v1.0.0")

  # Should show tag
  assert ($output | str contains "v1.0.0")

  # Should show author
  assert ($output | str contains "ck3mp3r")

  # Should show URL
  assert ($output | str contains "https://github.com")

  # Should show release body
  assert ($output | str contains "What's New")

  # Should show asset count
  assert ($output | str contains "2 assets")
}

export def "test format-release with draft" [] {
  use ../formatters.nu format-release

  let release = {
    tagName: "v2.0.0"
    name: "Draft Release"
    isDraft: true
    isPrerelease: false
    createdAt: "2025-12-22T10:00:00Z"
    publishedAt: null
    author: {login: "bot"}
    url: "https://github.com/ck3mp3r/nu-mcp/releases/tag/v2.0.0"
  }

  let output = format-release $release

  # Should indicate draft status
  assert ($output | str contains "draft")

  # Should not show published date for drafts
  assert (not ($output | str contains "Published:"))
}

export def "test format-release with prerelease" [] {
  use ../formatters.nu format-release

  let release = {
    tagName: "v1.0.0-beta.1"
    name: "Beta Release"
    isDraft: false
    isPrerelease: true
    createdAt: "2025-12-22T10:00:00Z"
    publishedAt: "2025-12-22T10:05:00Z"
    author: {login: "bot"}
    url: "https://github.com/ck3mp3r/nu-mcp/releases/tag/v1.0.0-beta.1"
  }

  let output = format-release $release

  # Should indicate prerelease status
  assert ($output | str contains "prerelease")
}

export def "test format-release truncates long body" [] {
  use ../formatters.nu format-release

  # Create a very long body (over 300 chars)
  let long_text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."

  let release = {
    tagName: "v1.0.0"
    name: "Release"
    body: $long_text
    isDraft: false
    isPrerelease: false
    createdAt: "2025-12-22T10:00:00Z"
    publishedAt: "2025-12-22T10:05:00Z"
    author: {login: "user"}
    url: "https://github.com/example/repo/releases/tag/v1.0.0"
  }

  let output = format-release $release

  # Should truncate with ellipsis
  assert ($output | str contains "...")
}
