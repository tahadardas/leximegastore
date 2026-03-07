# AUTH + Navigation Audit

## Scope
- Flutter app auth/session flow
- Flutter routing and back-button behavior
- WordPress `lexi-api` auth endpoints

## Current Auth Flow Issues (Before Changes)
- Login relied on a single access token (`jwt-auth/v1/token`) with no refresh lifecycle.
- Startup trusted stored access token and attempted `/auth/me`; expired token led to forced unauthenticated state.
- 401 handling in network interceptor cleared local session immediately instead of refreshing/retrying.
- Auth state was spread across `AppSession` and `CustomerAuthController` login/register/logout methods, causing competing transitions.
- Backend did not expose refresh/logout token management endpoints under `lexi/v1/auth/*`.

## Current Navigation Issues (Before Changes)
- Router started at `/splash` (not Account), then redirected to login/home.
- Account root (`/profile`) did not strictly gate between authenticated profile and unauthenticated login/register form state.
- Login/register flows could redirect users away from Account context.

## Planned Fixes
- Add server-side token lifecycle endpoints:
  - `POST /lexi/v1/auth/login`
  - `POST /lexi/v1/auth/register`
  - `POST /lexi/v1/auth/refresh`
  - `POST /lexi/v1/auth/logout`
- Add refresh-token rotation + revocation backend storage and password-change invalidation.
- Make refresh token the startup source of truth and silently refresh access token on startup.
- Implement 401 interceptor policy: one refresh flight, retry once, queue concurrent 401 retries.
- Move startup entry to Account (`/profile`) and render Account root by auth state:
  - authenticated -> profile
  - unauthenticated -> login/register UI in Account
- Keep back behavior safe:
  - inner pages pop normally
  - Account root back switches to Home tab
  - exit confirmation only from Home root

## Implemented Status
- Implemented all planned fixes above with minimal module churn.
