# Endpoint Patterns

## Route Shape

- Prefix: `/wp-json/lexi/v1`
- Domain grouping:
  - `/auth/*`
  - `/orders/*`
  - `/payments/*`
  - `/courier/*`
  - `/support/*`
  - `/app-config`
  - `/notifications/*`

## Handler Pattern

1. Parse and sanitize input.
2. Validate against schema/rules.
3. Authorize role/capability.
4. Execute domain service.
5. Emit event log for mutations.
6. Return envelope response.

## Error Standard

Always return:

```json
{
  "ok": false,
  "code": "SOME_CODE",
  "message": "Human readable",
  "details": {}
}
```

Map WordPress/Woo errors to stable `code` values before returning.

## Rate Limit Guidance

- Identify routes by user ID and IP.
- Apply tighter limits on write and notification routes.
- Return `RATE_LIMITED` with `retry_after_seconds`.

