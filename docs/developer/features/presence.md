# Presence (Online Users)

This doc describes how presence (who is online) works today.

## Storage
- Firestore collection: `presence`
  - Fields: `uid`, `displayName`, `photoURL`, `role`, `online` (bool), `lastSeen` (timestamp), `isAnonymous`, `metadata` (platform/version)

## Updates
- PresenceService (lib/features/student/data/services/presence_service.dart)
  - Updates `online` and `lastSeen` via `updateUserPresence(true|false)`
  - Router calls `PresenceService().markUserActive(...)` on key route entries to refresh activity
  - Optional heartbeat logic to update activity while user is interacting

## Consumption
- Online Users Card (dashboard)
  - Widget: `lib/features/student/presentation/widgets/online_users_card.dart`
  - Subscribes to a stream from PresenceService:
    - Defaults to Firestore real-time snapshots for all platforms
    - Filters to users active in the last N minutes (configurable; default 5m)

## Platform behavior
- Real-time listeners: used across platforms by default
- Windows polling fallback: disabled by default; can be enabled via
  `PresenceService.enableWindowsPollingFallback = true` if an environment
  proves unreliable with long-lived connections. Prefer keeping it off.

## Stale cleanup
- `PresenceService.cleanupStalePresence()` can mark online users as offline if
  `lastSeen` is older than the threshold (default 5 minutes).

## Notes
- We do not use Realtime Database for presence in this build; Firestore snapshots provide
  sufficient real-time behavior and simpler operational setup.

