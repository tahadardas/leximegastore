# API Contract Template (`lexi-api`)

## 1) Global Envelope (Mandatory)

### Success

```json
{
  "ok": true,
  "data": {}
}
```

### Error

```json
{
  "ok": false,
  "code": "SOME_CODE",
  "message": "Human readable",
  "details": {}
}
```

## 2) Endpoint Metadata

- Method:
- Route:
- Version: `v1`
- Auth requirement:
- Role permissions:
- Rate limit policy:
- Cache policy:

## 3) Request Schema

### Query Params

| Name | Type | Required | Validation |
|---|---|---|---|
| `page` | integer | no | `>=1` |
| `per_page` | integer | no | `1..100` |

### Body

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": [],
  "properties": {}
}
```

## 4) Response Schema

```json
{
  "ok": true,
  "data": {
    "items": [],
    "meta": {
      "page": 1,
      "per_page": 20,
      "total": 0
    }
  }
}
```

## 5) Error Codes

| Code | HTTP | Meaning | Details Keys |
|---|---:|---|---|
| `UNAUTHORIZED` | 401 | Missing/invalid authentication | `reason` |
| `FORBIDDEN` | 403 | Role lacks permission | `role`, `required` |
| `VALIDATION_ERROR` | 422 | Request validation failed | `fields` |
| `NOT_FOUND` | 404 | Resource does not exist | `resource`, `id` |
| `CONFLICT` | 409 | State conflict | `current_state`, `attempted` |
| `RATE_LIMITED` | 429 | Rate limit exceeded | `retry_after_seconds` |
| `INTERNAL_ERROR` | 500 | Unexpected server error | `trace_id` |

## 6) Versioning Rules

- Introduce breaking changes only in new version namespace (`/v2`).
- Additive changes are allowed in current version with backward compatibility.
- Do not remove existing fields without deprecation window.

## 7) Deterministic Acceptance Tests

1. Returns envelope shape for success and errors.
2. Rejects malformed payloads with `VALIDATION_ERROR`.
3. Enforces role permissions.
4. Enforces state machine transitions when relevant.
5. Emits audit event on mutating operations.

