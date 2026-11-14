library;

export 'src/notifications_facade.dart';
export 'src/notification_permissions_facade.dart';
export 'src/notifications_factories.dart';
export 'src/domain/local_notification.dart';
export 'src/domain/notifications_failure.dart';
export 'src/domain/observation.dart';
export 'src/domain/ports/local_notification_port.dart';
export 'src/domain/ports/notification_permission_port.dart';
export 'src/domain/repositories/notification_store_repository.dart';
// Phase A only: lib/features/wallet still constructs these two by name.
export 'src/data/flutter_local_notification_gateway.dart'
    show FlutterLocalNotificationGateway;
export 'src/data/sqlite_notification_store_repository.dart'
    show SqliteNotificationOutbox;
// Wallet mappings, moved to lib/features/wallet in phase B.
export 'src/wallet_payment_notification_identity.dart';
export 'src/wallet_sync_completion.dart';
export 'src/wallet_payment_observation_adapter.dart';
