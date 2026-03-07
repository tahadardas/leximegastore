# Risk Register Template

| ID | Risk | Probability | Impact | Trigger Signal | Mitigation | Contingency | Owner | Status |
|---|---|---|---|---|---|---|---|---|
| R1 | Order transition regression | Medium | High | Invalid transition errors spike | Add transition tests and event assertions | Freeze deploy and rollback | Backend lead | Open |
| R2 | ShamCash visibility bug | Medium | High | Verified payments not visible in order lists | Canonical status filters + debug endpoints | Hotfix filter query | Backend lead | Open |
| R3 | Courier assignment TTL drift | Low | Medium | Orders stale in assigned state | Scheduled TTL expiry job + alerts | Manual requeue script | Ops | Open |
| R4 | FCM token decay | Medium | Medium | High notification failure rate | Cleanup `UNREGISTERED` tokens | Re-register campaign | Mobile lead | Open |
| R5 | Remote config bad publish | Low | High | App startup errors after publish | Schema validation + diff review + staged rollout | Rollback to last good config | Admin lead | Open |
| R6 | Admin console role leakage | Low | High | Unauthorized actions in audit logs | Strict role gating and server-side checks | Revoke sessions and patch | Security owner | Open |

