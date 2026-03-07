# Publish And Rollback Protocol

## Publish Steps

1. Load draft config.
2. Validate against JSON schema.
3. Render diff vs active version.
4. Require admin confirmation.
5. Persist new version with metadata (`published_by`, `published_at`).
6. Generate and store `etag`.
7. Mark as active and emit audit event.

## Rollback Steps

1. Select target historical version.
2. Validate integrity.
3. Confirm admin authorization.
4. Activate selected version as current.
5. Emit rollback event with `from_version` and `to_version`.

## API Behavior

- `GET /app-config`
  - If `If-None-Match` equals active `etag`, return `304`.
  - Else return envelope with config payload and current `etag`.

## Safety Controls

- Deny publish on schema validation errors.
- Deny publish/rollback for non-admin roles.
- Never mutate historical version records.

