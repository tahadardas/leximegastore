# Regression Class Catalog

## Critical Classes

1. Invisible orders
2. Invalid order transitions
3. Payment method mismatch (`shamcash` variants)
4. Provider lifecycle crash
5. FCM token registration/sync drift
6. Remote config publish causing client breakage

## Quick Checks

- DB status/payment consistency queries
- API envelope and required field checks
- Role and permission checks on affected routes
- Event and ledger append integrity

## Evidence Standard

- Before/after request samples
- Before/after UI behavior proof
- Query outputs confirming repaired data/state
- Regression checklist pass references

