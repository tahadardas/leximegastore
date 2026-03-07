# Architecture Overview

## Stack

- Mobile: Flutter Customer App, optional Flutter Courier App
- Admin: Full Flutter Admin Console
- Backend: WordPress + WooCommerce + custom `lexi-api` plugin
- Push: Firebase Cloud Messaging (HTTP v1 sender from WordPress)
- Config control plane: WordPress-powered Remote App Config API

## Core Design Principles

1. Separate domain logic from transport:
   - `lexi-api` routes call services/use-cases, not inline business logic.
2. Keep WooCommerce as commerce engine:
   - Product/catalog/order primitives remain source of truth.
3. Treat order/payment/courier workflows as state machines:
   - Explicit transitions with actor and permission checks.
4. Standardize API envelopes and codes:
   - Uniform success/error payloads across all endpoints.
5. Prefer additive API evolution:
   - Version route groups (`/v1`) and preserve existing clients.

## Canonical Domains

- Identity and roles: customer/admin/courier/manager/support
- Orders and order events
- Payments and payment ledger
- Courier assignments and location state
- Support tickets and threaded messages
- App remote configuration and versions
- Notifications and delivery outcomes

## Deployment Modes

- Current: single-tenant deployment
- Commercial-ready: multi-tenant-ready architecture with tenant-aware keys, scoped caching, and migration strategy

## Non-Functional Requirements

- RTL-first UI behavior for all Flutter surfaces
- Deterministic operational flows and auditability
- No multi-currency support in this release
- Graceful degradation for offline courier actions

