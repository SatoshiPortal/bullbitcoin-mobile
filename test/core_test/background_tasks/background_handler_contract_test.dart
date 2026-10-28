import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The headless graph built for a WorkManager task must opt out of every
// foreground-only process: payjoin recovery, order-swap polling and the
// autoswap watcher, which signs with the seed.
void main() {
  test('the headless graph starts no foreground-only process', () {
    final handler = File(
      'lib/core/background_tasks/handler.dart',
    ).readAsStringSync();
    final setup = handler.indexOf('await AppLocator.setup(');
    final setupEnd = handler.indexOf(');', setup);
    final arguments = handler.substring(setup, setupEnd);

    expect(arguments, contains('startPayjoinRecovery: false'));
    expect(arguments, contains('startOrderSwapWatcher: false'));
    expect(arguments, contains('startAutoswapWatcher: false'));
  });
}
