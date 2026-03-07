# Admin Console Screen Map (Flutter)

## Auth

- Login
- Session/role bootstrap
- Unauthorized role fallback

## Dashboard

- KPI cards: sales, orders, pending review, pending verification, out for delivery, COD outstanding
- Time window selector
- Quick actions panel

## Orders

- Order list
  - Filters: status, payment, city, courier, date range
  - Search: order ID, customer phone/name
- Order detail
  - Header summary
  - Timeline (wizard-like events)
  - ShamCash approve/reject controls
  - Assign/reassign courier controls
  - Customer address and map action
  - Payment ledger panel
  - Print/share summary action

## Couriers

- Courier list
- Courier detail
  - Last-known location
  - Active assignment
  - Navigation to courier position
- Assignment queue with TTL badges
- Courier performance report

## Support

- Tickets list
- Ticket detail thread
- Reply with attachments
- Ticket status controls: open/pending/closed

## Catalog (Optional)

- Featured items manager
- Banner manager

## App Config Console

- Feature flags editor
- Navigation config editor
- Home sections editor
- Draft validation view
- Publish + rollback history
- Config diff viewer

## Notifications Center

- Broadcast push sender
- Targeted push sender
- Send history and delivery outcomes

## Audit Logs

- Event stream list
- Filters: actor/date/type/entity
- Event detail pane

