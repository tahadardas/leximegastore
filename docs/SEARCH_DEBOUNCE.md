# Search Debounce Design

## Goal
Reduce API spam and stabilize search UX for typeahead and results flow.

## Implementation
- Reusable debouncer:
  - `lib/core/async/debouncer.dart`
  - API: `run`, `cancel`, `dispose`
- Integrated in:
  - `lib/features/search/search_controller.dart`

## Query Change Flow
1. User types in search field.
2. Input is normalized/sanitized.
3. If query length `< 2`:
   - clear suggestions
   - skip API call
4. Otherwise:
   - cancel previous debounce timer
   - cancel previous suggestion request (`CancelToken`)
   - schedule new request after `300ms`

## In-flight Cancellation + Stale Response Protection
- Suggestion requests:
  - cancel token cancels previous network request
  - `_suggestVersion` ensures stale responses are ignored
- Results requests:
  - separate cancel token and `_resultsVersion`
  - supports pagination without stale overwrite

## Extra Stability Guards
- Suggestion cache (`_suggestionCache`) avoids repeated hits for same normalized query.
- Controller disposes debouncer and cancel tokens in `ref.onDispose`.

## Acceptance Mapping
- Typing fast no longer triggers one request per keystroke.
- API calls fire after debounce window (`300ms`) only.
- Search tap flow remains stable (no crash from overlapping requests).

