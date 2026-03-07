---
name: lexi-wp-remote-config-console
description: Build and operate WordPress-based remote app config console with versioning, feature flags, navigation/home layout control, publish/rollback, schema validation, diff view, and ETag/304 API behavior. Use for server-driven app behavior without mobile redeploy.
triggers:
  - remote app config
  - feature flags
  - app-config etag
  - publish rollback
  - maintenance mode
  - force update
boundaries:
  - admin-only publish actions
  - schema validation before publish
  - immutable config version history
---

# 1) Purpose

Enable safe runtime control of app behavior from WordPress, with strict validation, versioning, and rollback guarantees.

# 2) When to use / When NOT to use

Use when:

- Designing app-config APIs and admin publishing workflows.
- Adding feature flags, navigation config, home layout config.
- Implementing maintenance mode or force-update controls.

Do not use when:

- Change is static UI code not server-driven.
- Task does not involve runtime configuration.

# 3) Inputs required

- Config schema and required feature domains.
- Role/capability matrix for editing vs publishing.
- Client cache/refresh behavior requirements.
- Rollback and incident response policy.

# 4) Workflow steps (checklist)

- [ ] Define JSON schema for full config payload.
- [ ] Implement draft editing model in WP admin console.
- [ ] Implement config diff viewer and validation output.
- [ ] Implement publish endpoint with admin-only permissions.
- [ ] Persist immutable versions and metadata.
- [ ] Implement rollback action to prior version.
- [ ] Implement `GET /app-config` with `ETag` and `304`.
- [ ] Validate client fallback behavior for fetch failures.

# 5) Output artifacts (files/docs)

- Config schema (`remote_config_schema.json`) and examples.
- Admin console workflow map.
- Publish/rollback API contracts.
- Diff and audit logging rules.
- QA scenarios for config safety.

# 6) Definition of Done + Acceptance Criteria

- Invalid config cannot be published.
- Published config versions are immutable and traceable.
- `GET /app-config` supports conditional requests with `ETag`.
- Rollback restores prior known-good version reliably.
- Feature flags and navigation/home sections update without app redeploy.

# 7) Risk controls (guardrails)

- Block publish without schema validation success.
- Block non-admin publish/rollback operations.
- Block destructive edits to historical versions.
- Block route responses that violate global envelope.

# 8) Example invocation prompts

- Build remote config console with publish/rollback and schema validation.
- Add ETag and 304 support to app-config endpoint.
- Implement force update and maintenance toggles in WP config system.

