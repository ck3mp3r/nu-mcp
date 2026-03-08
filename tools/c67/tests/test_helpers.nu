# Test helper data for c67 tests

# Sample v2 search response
export def sample-v2-search-response [] {
  {
    results: [
      {
        id: "/facebook/react"
        title: "React"
        description: "A JavaScript library for building user interfaces"
        branch: "main"
        lastUpdateDate: "2026-03-08T10:30:00.000Z"
        state: "finalized"
        totalTokens: 500000
        totalSnippets: 2500
        stars: 220000
        trustScore: 10
        benchmarkScore: 98.5
        versions: ["v18.2.0", "v17.0.2"]
      }
    ]
  }
}
