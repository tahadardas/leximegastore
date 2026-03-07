# Customer Screen Contracts

## Shell Tabs

- Home
- Categories
- Cart
- Orders
- Profile

## Mandatory Modules

- Auth + session persistence
- Home sections (server-driven)
- Category/brand/tag discovery
- Product details
- Cart
- Checkout wizard (city selection included here only)
- Order tracking
- Support tickets

## UI State Contract

Each networked screen must handle:

- loading (skeleton)
- content
- empty
- error + retry

## Routing Contract

- Explicit route names.
- Back navigation path deterministic.
- Guard protected routes by auth/session status.

