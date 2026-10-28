import 'package:bb_mobile/core/background_tasks/wallet_payment_observation_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart' show WalletNetworkKey;

class _MockGateway extends Mock implements LocalNotificationGateway {}

class _MockOutbox extends Mock implements NotificationOutboxPort {}

const _key = WalletNetworkKey('wallet', 'bitcoin', 'testnet');

void main() {
  late _MockOutbox outbox;
  late NotificationsFacade notifications;

  setUp(() {
    outbox = _MockOutbox();
    notifications = NotificationsFacade(
      gateway: _MockGateway(),
      outbox: outbox,
    );
    when(
      () => outbox.recordObserved(any(), any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  test(
    'a sync finishing while the app is visible records its payments seen',
    () async {
      final adapter = WalletPaymentObservationAdapter(
        () => notifications,
        isAppVisible: () => true,
      );

      await adapter.recordSeen(_key, ['txid']);

      verify(() => outbox.recordObserved(any(), any())).called(1);
    },
  );

  test('a sync finishing after the user left records nothing seen', () async {
    // The user never saw these payments: the background must still announce
    // them.
    final adapter = WalletPaymentObservationAdapter(
      () => notifications,
      isAppVisible: () => false,
    );

    await adapter.recordSeen(_key, ['txid']);

    verifyNever(() => outbox.recordObserved(any(), any()));
  });
}
