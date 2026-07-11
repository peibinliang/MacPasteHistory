## Why

The app is intended to run continuously, so history data and image files must not grow forever or degrade UI performance. This phase bounds storage, improves search/list responsiveness, and checks long-running resource use.

## What Changes

- Clean expired records on startup.
- Remove oldest records when count limits are exceeded.
- Remove old image files when storage limits are exceeded.
- Add database indexes for created time, type, hash, and favorite state.
- Add paginated list loading.
- Improve thumbnail cache behavior.
- Tune clipboard polling frequency.
- Check for memory leaks and long-running CPU usage.

## Capabilities

### New Capabilities
- `optimize-data-cleanup-and-performance`: Automatic cleanup, bounded record and image storage, database indexes, pagination, thumbnail caching, polling optimization, and long-running performance checks.

### Modified Capabilities

## Impact

- Affects cleanup service, database migrations and indexes, repository queries, history list loading, image storage, thumbnail loading, clipboard monitor interval, and test/performance validation.
