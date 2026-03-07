# QA Checklist: ShamCash Flow

- [ ] Create ShamCash order from checkout.
- [ ] Upload payment proof.
- [ ] Confirm proof appears in admin verification queue.
- [ ] Approve proof and validate order remains visible in all order lists.
- [ ] Reject proof path also tested with clear reason.
- [ ] Confirm payment method ID is canonical `shamcash`.
- [ ] Confirm no `sham_cash` variant appears in DB/API.
- [ ] Continue lifecycle: assign courier -> out for delivery -> delivered.
- [ ] Validate payment ledger entries and final payment status.
- [ ] Verify event logs include proof uploaded and decision events.

