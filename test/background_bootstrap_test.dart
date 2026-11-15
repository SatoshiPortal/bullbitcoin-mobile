import 'package:get_it/get_it.dart';
import 'package:bb_mobile/features/wallet/wallet_locator.dart';
import 'package:bb_mobile/features/wallet/data/payment_notifications.dart';
import 'package:bb_mobile/features/wallet/data/wallet_payment_observer.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/background_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OFF registers no foreground observation or outbox owner', () async {
    final locator = GetIt.asNewInstance();
    addTearDown(locator.reset);
    WalletLocator.setup(locator);
    expect(backgroundSyncAvailable, isFalse);
    expect(locator.isRegistered<PaymentNotificationStore>(), isFalse);
    expect(locator.isRegistered<WalletPaymentObserver>(), isFalse);
  });
  test('OFF acknowledges persisted work without opening any platform resources', () async {
    // No path provider, Drift, native SDK or permission plugin is installed in
    // this test. Building any of the headless graph would fail the test.
    for (final task in BackgroundTask.values) {
      final runner = await bootstrapBackgroundRunner(
        task,
        clock: Stopwatch()..start(),
      );
      expect((await runner.run(task)).shouldRetry, isFalse);
      expect(runner.handlers, isEmpty);
    }
  });
}
