-- Order and payment consistency audit queries
-- Run against WordPress/WooCommerce + lexi-api tables.

-- 1) Count orders by fulfillment status
SELECT status, COUNT(*) AS total
FROM lexi_orders
GROUP BY status
ORDER BY total DESC;

-- 2) Count orders by payment status
SELECT payment_status, COUNT(*) AS total
FROM lexi_orders
GROUP BY payment_status
ORDER BY total DESC;

-- 3) Detect orders stuck in assigned state past TTL
SELECT o.id, o.status, a.expires_at, NOW() AS now_ts
FROM lexi_orders o
JOIN lexi_courier_assignments a ON a.order_id = o.id AND a.active = 1
WHERE o.status = 'assigned_to_driver'
  AND a.expires_at < NOW();

-- 4) Detect non-canonical ShamCash payment method IDs
SELECT id, order_id, payment_method
FROM lexi_payment_ledger
WHERE LOWER(payment_method) IN ('sham_cash', 'sham-cash', 'sham cash');

-- 5) Detect delivered orders without paid/partial status (review list)
SELECT id, status, payment_status
FROM lexi_orders
WHERE status = 'delivered'
  AND payment_status NOT IN ('paid', 'partial');

-- 6) Detect missing order events for status transitions
SELECT o.id, o.status
FROM lexi_orders o
LEFT JOIN lexi_order_events e
  ON e.order_id = o.id
 AND e.event_type = 'status_changed'
WHERE e.id IS NULL;

