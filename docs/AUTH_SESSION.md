# Auth Session Notes

## Token Lifecycle
- Access token:
  - Issued by `POST /wp-json/lexi/v1/auth/login` and `POST /wp-json/lexi/v1/auth/register`.
  - Stored in memory (`AppSession._token`) and mirrored to secure storage for cold-start recovery.
  - Short-lived by design.
- Refresh token:
  - Issued on login/register.
  - Stored only in secure storage (`flutter_secure_storage` via `TokenStore` / `SecureStore`).
  - Rotated on each successful refresh (`POST /wp-json/lexi/v1/auth/refresh`) when backend returns a new token.

## Startup Refresh Flow
1. Auth state starts as `unknown`.
2. App loads stored tokens + cached profile fields from secure storage.
3. If refresh token exists:
   - Call refresh endpoint.
   - Persist returned access token and rotated refresh token (if present).
   - Call `/auth/me` with fresh access token.
   - Set auth state to `authenticated(user)`.
4. If refresh token is missing/invalid:
   - Clear auth session.
   - Set state to `unauthenticated`.

## Logout Flow
- Explicit logout is triggered by user action.
- Client calls `POST /wp-json/lexi/v1/auth/logout` (best-effort), sending refresh token when available.
- Backend revokes refresh token (or all user refresh sessions if only user context is available).
- Client clears local session and secure token storage.
- Account UI immediately renders Login/Register state.

## Password Change / Server Invalidation
- Backend revokes all refresh sessions on:
  - `POST /auth/change-password`
  - `POST /auth/reset-password`
- Any later refresh attempt with revoked/invalid token returns unauthorized and client transitions to unauthenticated.

## 401 Retry Policy (Dio Interceptor)
- On protected request 401:
  1. Attempt refresh once.
  2. If refresh succeeds, retry original request once with new access token.
  3. If refresh is invalid, clear session and set unauthenticated.
  4. If refresh fails transiently (network), bubble original error without forced logout.
- Concurrency control:
  - Multiple simultaneous 401 responses share a single in-flight refresh (`Completer`-based single-flight).
  - Waiting requests retry after the same refresh result is resolved.

## Notes
- Auth tokens are not stored in SharedPreferences.
- No multi-currency logic was added or modified.
