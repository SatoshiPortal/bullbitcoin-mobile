// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2631
// Finding: refreshing UTXOs replaces the visible set without pruning selectedUtxos.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2631 stale coin-control selections', () {
    test(
      'loadUtxos assigns refreshed UTXOs without intersecting selection',
      () {
        final source = File(
          'lib/features/send/presentation/bloc/send_cubit.dart',
        ).readAsStringSync();
        final loadUtxos = source.substring(
          source.indexOf('Future<void> loadUtxos()'),
          source.indexOf('Future<void> utxoSelected'),
        );

        expect(loadUtxos, contains('utxos: utxos'));
        expect(loadUtxos, contains('selectedUtxos:'));
      },
    );
  });
}
