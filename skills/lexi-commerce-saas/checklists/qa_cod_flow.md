# QA Checklist: COD Flow

- [ ] Create COD order from customer app checkout.
- [ ] Confirm order enters `pending_review`.
- [ ] Approve order to `confirmed`.
- [ ] Assign courier and verify TTL recorded.
- [ ] Courier marks `out_for_delivery`.
- [ ] Courier marks `delivered`.
- [ ] Submit COD collection entry.
- [ ] Confirm payment ledger row exists with method `cod`.
- [ ] Confirm order payment status updates (`unpaid` -> `partial`/`paid`).
- [ ] Verify customer/admin notifications delivered.
- [ ] Verify full event timeline integrity.

