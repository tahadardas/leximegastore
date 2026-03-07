# QA Execution Protocol

## Evidence Requirements

- Timestamped test run logs.
- API request/response samples for critical actions.
- UI screenshots for key state transitions.
- Defect records linked to checklist items.

## Severity Policy

- Critical: blocks release.
- High: blocks release unless approved mitigation exists.
- Medium/Low: may ship with tracked remediation plan.

## Mandatory Flow Gates

- COD end-to-end
- ShamCash proof -> decision -> delivery -> payment
- Courier assignment TTL expiry and requeue
- Push notifications end-to-end
- Remote config publish and rollback

## Exit Criteria

- No unresolved critical issues.
- High issues accepted only with explicit owner and timeline.
- Go/no-go recommendation documented.

