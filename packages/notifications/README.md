# notifications

Local notifications for the app: a durable store of observed events and of the aggregates waiting to be shown, and their delivery through `flutter_local_notifications`.

## Store

`notifications.sqlite` is created by a single `CREATE` with `user_version` 1; it is unpublished and has no migration.

- `topics`: a topic is initialized by its first complete foreground observation, even when it holds no event. That history is a silent baseline.
- `observed_events (topic_id, event_id)`: inserted with `INSERT OR IGNORE` in bounded batches.
- `outbox`: pending or claimed aggregates only, deleted once delivered.
- `platform_ids`: a counter allocated with each aggregate in the same transaction. An ID is never reused, so a notification still on screen is never replaced; exhaustion is refused.

An `Observation` carries one topic and event identities, never text. The two transactions that matter are in `SqliteNotificationStoreRepository`:

- `recordForeground` stores what a foreground sync saw and initializes its topic. Those events are never announced.
- `recordBackground` ignores a topic the foreground never observed. Otherwise the events it stored for the first time become one pending aggregate, built by the caller, in the same transaction.

A pending aggregate stays until it is delivered, even if the app shows its payments in the meantime (rule P, undecided; the single query option P1 would add is marked in `recordForeground`).

`openForegroundNotificationStore` creates the store. `openExistingNotificationStore` never creates or migrates it, and refuses a missing, older or newer store.

## Delivery

`NotificationsFacade.deliverPending` claims one aggregate at a time by token and deletes it once shown. A crash after the show replays it under the same platform ID; a claim taken over after its lease cannot be settled by its first owner. The permission decides first:

- allowed: show;
- refused: settle without showing, so granting it later replays no backlog (`NotificationsPermissionDeniedFailure`);
- undetermined: keep everything pending (`NotificationsPermissionUndeterminedFailure`).

A tap opens the app: notifications carry no destination. `initialize` never asks for the permission; `notificationPermissions` serves settings and the startup wizard without a store.

## Phase A

The wallet identity and observation files (`wallet_payment_notification_identity`, `wallet_sync_completion`, `wallet_payment_observation_adapter`) still live here, with the dependency on `transaction_sync` they need. The barrel still shows `FlutterLocalNotificationGateway` and `SqliteNotificationOutbox`, which `lib/features/wallet` constructs by name. All of these move to the wallet feature in phase B.
