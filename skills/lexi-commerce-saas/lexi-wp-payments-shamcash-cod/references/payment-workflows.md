# Payment Workflow Reference

## ShamCash Workflow

1. Customer selects `shamcash`.
2. Customer uploads proof.
3. System stores proof metadata and sets verification pending flag.
4. Admin reviews and approves/rejects with reason.
5. Decision emits payment event and updates payment status.

## COD Workflow

1. Order created with method `cod`.
2. Courier/admin records collection events.
3. Partial collection allowed until total due is satisfied.
4. Ledger aggregation determines `unpaid|partial|paid`.

## Ledger Event Types

- `payment_initiated`
- `proof_uploaded`
- `proof_approved`
- `proof_rejected`
- `cod_collected`
- `manual_adjustment`

## Reporting Minimums

- Daily received totals by method.
- Outstanding COD by city/courier.
- Rejected ShamCash proofs with reason counts.

