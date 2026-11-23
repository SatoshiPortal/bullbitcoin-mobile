import 'package:transactions/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swaps/swaps.dart';

void main() {
  for (final environment in Environment.values) {
    for (final type in [
      SwapType.lightningToBitcoin,
      SwapType.lightningToLiquid,
    ]) {
      test(
        'swap-only ${environment.name} ${type.name} respects explorer policy',
        () {
          final swap = Swap.lnReceive(
            id: 'public-id001',
            type: type,
            status: SwapStatus.completed,
            environment: environment,
            keyIndex: 0,
            creationTime: DateTime.utc(2026),
            receiveWalletId: 'public-wallet',
            invoice: 'public-placeholder',
            receiveTxid: 'public-tx',
          );
          final transaction = Transaction(swap: swap);
          expect(transaction.txId, 'public-tx');
          expect(
            transaction.supportsPublicExplorer,
            environment != Environment.regtest,
          );
        },
      );
    }
  }
}
