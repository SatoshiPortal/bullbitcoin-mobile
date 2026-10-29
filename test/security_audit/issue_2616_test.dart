// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2616
// Finding: opening the PushTx URL is reported as a successful broadcast.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2616 NFC broadcast status', () {
    test(
      'PushTx waits for the selected transport instead of launching a URL',
      () {
        final source = File(
          'lib/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart',
        ).readAsStringSync();
        expect(source, isNot(contains('launchUrl(')));
        expect(source, isNot(contains('package:url_launcher/')));
        expect(
          source,
          contains('Future<void> pushTxUri() => broadcastTransaction();'),
        );
        final broadcast = source.substring(
          source.indexOf('Future<void> broadcastTransaction()'),
        );
        expect(broadcast, contains('walletId: wallet.id,'));
        expect(broadcast, contains('SourceWalletRequiredFailure()'));
        final awaited = broadcast.indexOf('await _broadcast.execute(');
        final success = broadcast.indexOf('case Ok():');
        final emitted = broadcast.indexOf('isBroadcasted: true');
        expect(awaited, greaterThanOrEqualTo(0));
        expect(success, greaterThan(awaited));
        expect(emitted, greaterThan(success));
        expect(broadcast, contains('case Err(:final failure):'));
        expect(broadcast, contains('failure: failure, isBroadcasting: false'));
      },
    );
  });
}
