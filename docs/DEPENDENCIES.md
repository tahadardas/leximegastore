# Dependencies Added for Async Upgrade

## Added
- `synchronized: ^3.3.1`
  - Reason: shared mutex/lock primitive used across critical flows:
    - token refresh single-flight
    - checkout submit lock
    - ShamCash proof upload per-order lock
    - realtime refresh serialization

## Chosen (No New Package Needed)
- Streams:
  - Used existing Riverpod + Dart `StreamController` / `StreamProvider`.
  - No extra stream package required.
- Debounce:
  - Implemented local reusable `Debouncer` (`lib/core/async/debouncer.dart`).
  - No `rxdart` added to keep dependency surface small.
- Background isolate:
  - Used Flutter `compute()` for heavy order parsing.
  - No worker manager package added.

## Already Present and Reused
- `flutter_riverpod`: existing app state-management foundation.
- `dio`: in-flight request cancellation for search and network layer.
- `timeago`: already present and reused by relative-time utility.
- `convex_bottom_bar`: already present (navigation UI work was already integrated previously).

## Command Executed
- `flutter pub get` completed successfully after dependency update.

