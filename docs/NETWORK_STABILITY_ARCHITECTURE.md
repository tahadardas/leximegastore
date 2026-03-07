# Network Stability Refactor

## Flow Diagram

```text
UI / Repository call
        |
        v
DioClient facade (path normalization + fallback strategy)
        |
        v
ApiClient (single Dio source of truth)
        |
        v
[Interceptors order]
1) JsonSanitizer
2) ClientIdentity
3) NetworkLogging (+ active request counter)
4) AuthInterceptor
   - attach token from TokenManager
   - on 401 (non-refresh): refresh once then retry once
5) RetryInterceptor
   - max 2 retries
   - backoff 1s, 2s
   - only timeout/socket/5xx
   - skip refresh + payment POST
6) NetworkGuardInterceptor
   - fail fast with NoInternetException if offline
7) RequestQueueInterceptor
   - max 4 concurrent requests
   - FIFO queue for the rest
        |
        v
Response / Error -> mapped by existing app mappers
```

## Core Components

- `ApiClient`: one configured Dio instance.
- `TokenManager` (singleton): single-flight refresh with mutex + shared future.
- `RetryPolicy`: bounded, endpoint-aware retries.
- `RequestQueue`: concurrency limiter and FIFO queue.
- `NetworkGuard`: connectivity gate + change stream.
- `PollingManager`: centralized timers with lifecycle/auth/connectivity guards.
- `SubmissionLockService`: duplicate-submit guard returning the same in-flight future.
- `AppBootService`: serialized startup sequence to prevent startup firestorms.

## Why the Previous Instability Happened

- Concurrent startup fetches triggered at once from multiple bootstrap points.
- Refresh logic existed in more than one place, increasing race risk.
- Polling lived in multiple services/screens with independent timers.
- No global request concurrency cap, allowing bursts on reconnect.
- Retry behavior was not endpoint-aware for critical submission paths.

## Stability Improvements

- Single refresh in-flight across all requests.
- Queue cap (`4`) reduces radio/network burst pressure on Android 4G.
- Retry is limited and safe (no payment/refresh retries, no infinite loops).
- Polling pauses on background/offline/logout and resumes only when safe.
- Duplicate checkout/proof/refresh submissions collapse to one request.
