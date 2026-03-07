# Search Audit

## Scope
- App: Flutter (Riverpod + GoRouter)
- Backend: WordPress/WooCommerce custom plugin (`lexi-api`)
- Feature audited: search entry, suggestions, results, history, backend search routes

## State Management Used
- Global state management is Riverpod.
- App root is correctly wrapped with `ProviderScope` in `lib/main.dart`.
- Search state is managed by `searchControllerProvider` (`AutoDisposeNotifierProvider`) in `lib/features/search/search_controller.dart`.

## Search UI/Provider Wiring
- Search entry screen: `lib/features/search/search_screen.dart`
  - Search input changes call `searchControllerProvider.notifier.onQueryChanged(...)`.
  - History/trending/suggestions are rendered from controller state.
- Search results screen: `lib/features/search/search_results_screen.dart`
  - Now reads results/pagination/loading/error from the same search controller.
- Home entry point: `lib/features/home/presentation/pages/home_page.dart`
  - Home search field routes to `/search`.

## Existing Backend Endpoints Found
- Legacy endpoints already present:
  - `GET /wp-json/lexi/v1/search/suggest`
  - `GET /wp-json/lexi/v1/search`
  - `GET /wp-json/lexi/v1/search/trending`
- New compatibility endpoints added in this upgrade:
  - `GET /wp-json/lexi/v1/search/suggestions`
  - `GET /wp-json/lexi/v1/search/products`

## Current UX Flow (Before Fix)
1. User taps search from Home and opens `/search`.
2. Typing triggers debounced suggestions.
3. Submitting query opens `/search/results`.
4. Results screen used its own local state/pagination.
5. Recent history persisted locally in SharedPreferences.

## Root Cause of Crash
- Crash: `Bad state: Tried to read the state of an uninitialized provider`.
- Root cause in `SearchController.build()`:
  - It read/wrote `state` before initial state was returned (`state = state.copyWith(...)` inside `build`).
  - In Riverpod Notifier lifecycle, provider state is not initialized until `build()` returns.
  - This produced intermittent crashes when the search field triggered provider initialization.

## Navigation/Provider Lifecycle Risks Identified
- Search results used a separate local state path, while entry used provider state.
- Different logic paths increased lifecycle complexity and made provider timing issues harder to reason about.
- Error/empty/loading states were split across screens with inconsistent handling.

## Fix Plan (Implemented)
1. Fix provider initialization crash first.
   - Remove all `state` reads/writes from `SearchController.build()` before returning initial state.
2. Introduce a stable search state machine.
   - `idle`, `typing`, `loadingSuggestions`, `suggestionsReady`, `loadingResults`, `resultsReady`, `error`.
3. Centralize orchestration in one controller.
   - Suggestions debounce + cancellation.
   - Results search + pagination + cancellation.
4. Harden local history.
   - Normalize query (trim/collapse/lowercase/remove Arabic diacritics), de-duplicate, cap size, resilient error handling.
5. Align API layer with required contracts while keeping backward compatibility.
   - Added `/search/suggestions` and `/search/products` plugin endpoints.
   - Flutter client falls back to legacy endpoints if newer routes are unavailable.
6. Improve UX consistency.
   - Friendly empty/error states with retry.
   - History visible on empty query.
   - Per-item history delete + clear all.
7. Add lightweight performance improvements.
   - In-memory suggestion cache (last successful queries).
   - Transient caching on backend for suggestions and trending.

## Crash Verification Target
- Tapping/typing in search no longer initializes provider in an invalid state.
- Provider can be safely created from search screen interactions without uninitialized-state exceptions.

## Non-goals / Constraints Followed
- No multi-currency logic was introduced or modified.
- Existing checkout/order creation flow not touched.
