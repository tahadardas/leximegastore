# Async Upgrade QA Checklist

Date: 2026-03-03

## Static Verification
- `flutter analyze`: PASS (no issues).

## Functional Checklist

### 1) Orders Stream
- [ ] Place order -> Orders list updates immediately (mutation trigger).
- [ ] Wait poll interval (~45s) after status change -> UI reflects latest status.
- [ ] Simulate API failure with existing cache -> stale banner appears and cached list remains visible.

### 2) Notifications Stream
- [ ] New notification appears after poll interval (~45s) or manual refresh.
- [ ] Badge count updates from `notificationsUnreadCountStreamProvider`.
- [ ] Mark read single/all updates optimistically and remains correct after backend sync.

### 3) Search Debounce
- [ ] Typing quickly fires fewer requests (debounced ~300ms).
- [ ] Query length `< 2` does not call suggestions API.
- [ ] No stale suggestion overwrite when typing/changing quickly.

### 4) Auth Refresh Lock
- [ ] Expire token and fire multiple protected requests in parallel.
- [ ] Confirm one refresh request executes and other calls await same result.
- [ ] Requests retry once and continue without session corruption.

### 5) Checkout / ShamCash Submit Locks
- [ ] Double-tap "Place Order" -> one order created.
- [ ] Double-tap ShamCash proof upload -> one upload request accepted.
- [ ] User sees in-progress/ignored-duplicate feedback without crash.

### 6) Courier Location Stream (Admin)
- [ ] Open "Find Courier" -> location starts loading then updates.
- [ ] While modal open, updates arrive every ~12s.
- [ ] Close modal -> polling stops (no background leaks).

## Notes
- Device/integration execution is still required for runtime verification of push, navigation, and backend-side effects.
- This checklist is aligned with current implementation and should be used for UAT signoff.

