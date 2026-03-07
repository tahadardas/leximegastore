# ShamCash Order Persistence + Visibility Bug Report (2026-03-03)

## Summary
- **Impact**: ShamCash orders returned a valid `order_id` from checkout but were intermittently missing in Woo admin lists, app admin ShamCash list, and tracking lookup.
- **COD** remained unaffected.
- **Primary root cause**: custom status slug length mismatch with WordPress storage constraints.

## Root Cause Evidence

### 1) Status key length overflow (deterministic)
- Existing custom status key: `wc-pending-verification`
- Measured length: **23**
- WordPress `post_status` storage limit is effectively **20 chars**.
- DB-safe truncated form: `wc-pending-verificat` (length **20**)

Evidence command run in workspace:

```powershell
"wc-pending-verification".Length; "wc-pending-verificat".Length
```

Output:

```text
23
20
```

### 2) Why this caused invisibility
- Orders were being assigned `pending-verification` in code.
- Persisted status could end up as truncated `pending-verificat`.
- Some admin/lookup paths expected the full slug, causing inconsistent visibility.

### 3) Secondary issue affecting tracking
- Tracking endpoint primarily resolved by `order_number`.
- App often passes `order_id` for tracking screens.
- This mismatch could produce `order_not_found` in some formats/numbering setups.

## Mandatory DB Verification Queries

Run immediately after ShamCash checkout returns `order_id`/`order_number`.

```sql
SELECT ID, post_status, post_type, post_date
FROM wp_posts
WHERE ID = {order_id} OR post_title LIKE '%{order_number}%';
```

```sql
SELECT meta_key, meta_value
FROM wp_postmeta
WHERE post_id = {order_id}
  AND meta_key IN ('_payment_method','_payment_method_title','_lexi_decision','_transaction_id');
```

Recommended extra query for proof metadata:

```sql
SELECT meta_key, meta_value
FROM wp_postmeta
WHERE post_id = {order_id}
  AND meta_key IN ('_lexi_shamcash_proof_url','_lexi_shamcash_proof_uploaded_at','_lexi_shamcash_proof_attachment_id');
```

If HPOS is enabled, also verify Woo order tables (`wc_orders`, `wc_order_meta`) with equivalent filters.

## Permanent Fix Implemented

### A) Status persistence hardened
- Added DB-safe status storage helper:
  - `Lexi_Order_Flow::pending_verification_storage_status()` => `pending-verificat`
- ShamCash creation/proof flows now persist using DB-safe status slug.
- Public API status remains normalized as `pending-verification`.

### B) Status registration/backward compatibility
- Registered both:
  - `wc-pending-verificat` (DB-safe)
  - `wc-pending-verification` (compat alias)
- Added both status keys in admin status lists/bulk actions/style hooks.
- Added legacy transition hooks in email triggers for both status slugs.

### C) ShamCash admin list filters hardened
- `/admin/shamcash/pending` now:
  - includes statuses: `pending-verification`, `pending-verificat`, `on-hold`, `pending`, `processing`
  - applies payment method filter with compatibility:
    - `_payment_method IN ('sham_cash','shamcash')`
    - `_lexi_payment_method IN ('sham_cash','shamcash')`

### D) Tracking reliability improved
- `/track-order` now accepts:
  - `order_id` directly (preferred when available)
  - `order_number` fallback (legacy behavior)
- Reduced false negatives in mixed ID/number flows.

### E) Debugging visibility endpoint added
- New admin-only endpoint:
  - `GET /wp-json/lexi/v1/admin/debug/order/{id}`
- Returns:
  - `exists`, `post_status`, `status`, `payment_method`, decision/proof meta, timestamps.

### F) Operational logging added
- Checkout and proof upload now log order persistence details:
  - `order_id`, `order_number`, `wc_status`, `post_status`, `post_type`, payment methods.

## Backward Compatibility Rules
- Accepted ShamCash payment methods in queries:
  - `sham_cash` (canonical)
  - `shamcash` (legacy)
- Accepted pending verification statuses:
  - `pending-verification` (public alias)
  - `pending-verificat` (DB-safe legacy/storage)
  - `on-hold` (compat/read paths)

## Regression Safety
- COD flow unchanged.
- No multi-currency changes.
- Existing legacy ShamCash orders remain discoverable by status/payment compatibility filters.
