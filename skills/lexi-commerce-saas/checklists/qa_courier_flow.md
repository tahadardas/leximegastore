# QA Checklist: Courier Flow

- [ ] Courier login blocked until location permission granted.
- [ ] Assignment appears with TTL and expiration timestamp.
- [ ] Courier can accept/reject assignment.
- [ ] Rejected/expired assignment returns to queue.
- [ ] Navigation to customer address works.
- [ ] Transition to `out_for_delivery` enforced by accepted assignment.
- [ ] Mark delivered updates order and logs event.
- [ ] COD collection submission supported from courier flow when required.
- [ ] Offline action queue works and syncs when connection returns.
- [ ] High-priority alert popup/sound verified for urgent assignments.

