# Search Performance Reference

## Defaults

- Debounce: 250-350 ms
- Max suggestion items per query: 10
- Cancel prior request before firing next query

## Lifecycle Safety

- Initialize providers before first query emission.
- Check mounted state before applying async results.
- Dispose controllers/subscriptions on screen teardown.

## Caching

- Cache recent query results in memory for short TTL.
- Persist search history locally by user.
- Optional sync endpoint for cross-device history.

## Metrics

- p95 suggestion latency
- request cancellation rate
- no-result query rate
- crash-free search sessions

