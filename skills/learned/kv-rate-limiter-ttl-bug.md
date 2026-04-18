# KV Rate Limiter TTL Reset Bug

**Extracted:** 2026-03-30
**Context:** Any KV-based rate limiter that sets expirationTtl on every write

## Problem
A common KV rate limiter pattern:
```javascript
const count = await kv.get(key) ?? 0;
if (count >= limit) throw new Error("Rate limited");
await kv.put(key, count + 1, { expirationTtl: 60 });
```

The bug: `expirationTtl` resets the TTL from NOW on every write. Under active use, the key never expires because each request extends the window by another 60 seconds. After hitting the limit, the user is locked out for a full 60 seconds even though the "window" should have rolled over.

## Solution
Use time-bucketed keys instead of TTL-resetting counters:

```javascript
const bucket = Math.floor(Date.now() / (WINDOW_SECONDS * 1000));
const key = `rate:${userId}:${bucket}`;

const count = await kv.get(key) ?? 0;
if (count >= limit) throw new Error("Rate limited");

// TTL is 2× window — key naturally expires after the bucket rolls over
await kv.put(key, count + 1, { expirationTtl: WINDOW_SECONDS * 2 });
```

Each minute gets a fresh counter. The key auto-expires after the window ends regardless of write frequency.

Also: exempt system overhead requests (auth sync, error reporting, usage tracking, notifications) from rate limiting. Only count user-initiated data requests.

## When to Use
- Any KV-based rate limiter (Cloudflare KV, Redis with TTL, DynamoDB TTL)
- Any counter where you set TTL on every increment
- Rate limiters that seem to "lock out" users permanently under active use
