# QA Checklist: Remote Config

- [ ] Draft config validates against `remote_config_schema.json`.
- [ ] Config diff view highlights changed fields.
- [ ] Publish action is admin-only.
- [ ] Published version increments monotonically.
- [ ] Client `GET /app-config` returns valid `ETag`.
- [ ] Client receives `304` when config unchanged.
- [ ] Rollback restores previous known-good version.
- [ ] Force update rule blocks outdated builds as expected.
- [ ] Maintenance mode banner/message behavior verified.
- [ ] Failed publish does not alter active version.

