# Cloudflare Worker Response Body Memory Leak

**Extracted:** 2026-03-30
**Context:** Any Cloudflare Worker that makes multiple outbound fetch() calls

## Problem
When a Worker calls `fetch()` and doesn't read or cancel the response body, the body stays in memory. Workers have a limit on concurrent HTTP connections. Once hit, Cloudflare cancels the oldest response, logs "A stalled HTTP response was canceled to prevent deadlock", and eventually the Worker exceeds its memory limit (128MB).

This commonly happens with:
- Crawlers that check HTTP status but skip non-HTML responses
- Conditional requests (304 Not Modified) where the body is empty but not cancelled
- Error responses where you return early without draining the body

## Solution
Call `response.body?.cancel()` on EVERY early return path:

```javascript
async function fetchPage(url) {
  const response = await fetch(url);

  // 304 — no body to read, but MUST cancel
  if (response.status === 304) {
    response.body?.cancel();
    return { url, notModified: true };
  }

  // Non-200 — cancel before returning
  if (!response.ok) {
    response.body?.cancel();
    return null;
  }

  // Non-HTML — cancel before returning
  const ct = response.headers.get("content-type") ?? "";
  if (!ct.includes("text/html")) {
    response.body?.cancel();
    return null;
  }

  // Success path — read the body (this drains it)
  const html = await response.text();
  return { url, html };
}
```

Also reduce concurrent outbound fetches. Workers support ~6 concurrent connections safely. Higher concurrency causes backpressure:

```javascript
const CONCURRENT_FETCHES = 6; // NOT 15 or 20
```

## When to Use
- Any Worker that calls `fetch()` in a loop or with `Promise.allSettled`
- Crawlers, scrapers, health checkers, proxy workers
- Any code path where `fetch()` response might not be fully read
