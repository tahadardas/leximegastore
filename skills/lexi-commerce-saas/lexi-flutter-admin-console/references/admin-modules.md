# Admin Modules Reference

## Roles

- `admin`: full access
- `manager`: order and reporting focus
- `support`: tickets and limited order visibility/actions
- `courier-manager`: assignment and courier operations

## KPI Dashboard

- Sales
- Orders
- Pending review
- Pending verification
- Out for delivery
- COD outstanding

## Orders Module

- Filters: status, payment, city, courier, date range
- Detail actions: verification, assignment, map, ledger, print/share

## Courier Module

- Courier list/detail
- Last-known location fetch
- Assignment queue with TTL indicators
- Performance aggregates

## Cross-Cutting Rules

- Use `timeago` for human-friendly timestamps.
- Keep full RTL support in layout, icons, and content alignment.
- Handle loading/error/empty states for every list/detail page.

