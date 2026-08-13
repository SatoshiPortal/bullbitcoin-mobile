// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2603
// Finding: pending send swaps are reused by invoice without wallet binding.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2603 cross-wallet swap reuse', () {
    test('usecase binds lookup to wallet and swap type', () {
      final source = File(
        'lib/features/send/domain/usecases/create_send_swap_usecase.dart',
      ).readAsStringSync();

      expect(source, contains('getSendSwapByInvoice('));
      expect(source, contains('invoice: finalInvoice'));
      expect(
        source,
        contains('if (existingSwap != null) return existingSwap;'),
      );
      expect(source, contains('walletId: walletId'));
      expect(source, contains('type: type'));
    });

    test('repository lookup filters by wallet and swap type', () {
      final source = File(
        'lib/core/swaps/data/repository/boltz_swap_repository.dart',
      ).readAsStringSync();
      final start = source.indexOf('Future<LnSendSwap?> getSendSwapByInvoice');
      final end = source.indexOf('\n  Future<int> getSwapRefundTxSize', start);
      final method = source.substring(start, end);

      expect(method, contains('fetchAll(walletId: walletId)'));
      expect(
        method,
        contains('swap.invoice.toLowerCase() == invoice.toLowerCase()'),
      );
      expect(method, contains('swap.status == SwapStatus.pending'));
      expect(method, contains('swap.walletId == walletId'));
      expect(method, contains('swap.type == type'));
    });
  });
}
