// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2603
// Finding: pending Boltz send swaps were reused by invoice without wallet
// binding. Exchange orders are always created for an explicit source wallet.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2603 cross-wallet swap reuse', () {
    test('usecase binds the new order to its source wallet and purpose', () {
      final source = File(
        'lib/features/send/domain/usecases/create_send_swap_usecase.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('getSendSwapByInvoice(')));
      expect(source, contains('sourceWalletId: walletId'));
      expect(source, contains('purpose: OrderSwapPurpose.sendLightning'));
      expect(source, contains('destinationAddress: invoice.invoice'));
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
