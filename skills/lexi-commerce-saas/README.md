# Lexi Commerce SaaS Skill System

Commercial Codex skill pack for building and operating a WooCommerce-connected, Flutter-first e-commerce platform:

- Flutter Customer App
- Flutter Admin Console (full panel)
- Optional Flutter Courier App
- WordPress + WooCommerce backend
- `lexi-api` custom plugin as business-logic gateway

The system is designed for single-tenant deployment now, with explicit multi-tenant-ready patterns.

## Core Product Rules

- RTL-first UX with Noon-like interaction priorities.
- No multi-currency in this version.
- Strict order/payment/courier operational workflows.
- Remote App Config managed from WordPress.
- Firebase Cloud Messaging (HTTP v1 sender in WP, receiver in Flutter apps).
- Deterministic acceptance criteria for every module.

## How to Use

Trigger the orchestrator skill with prompts such as:

- `Build a WooCommerce-connected e-commerce app with full Flutter admin panel`
- `Create a production-ready customer app + admin console with WordPress gateway`
- `Implement ShamCash + COD workflow with audit-safe order lifecycle`

The master skill (`SKILL.md`) routes to specialized sub-skills and enforces:

1. Scope decomposition
2. Data model/contracts
3. API routes plan
4. UI screens map (Customer + Admin)
5. Implementation plan (PR-style)
6. Risk register + mitigations
7. Definition of Done + QA checklist

## Folder Layout

```text
skills/lexi-commerce-saas/
├── SKILL.md
├── README.md
├── architecture/
├── templates/
├── checklists/
├── scripts/
└── <14 sub-skills>/
```

## Operational Non-Negotiables

- Keep API backward compatible through versioning (`/v1`, additive changes first).
- Do not break order/payment/courier state machine invariants.
- Enforce one global API envelope:
  - Success: `{ "ok": true, "data": { ... } }`
  - Error: `{ "ok": false, "code": "SOME_CODE", "message": "Human readable", "details": { ... } }`

