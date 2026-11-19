import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  for (final network in BitcoinNetwork.values) {
    test('Payjoin-only transaction public explorer admission on $network', () {
      final transaction = Transaction(
        payjoin: PayjoinReceiverSession(
          status: PayjoinStatus.proposed,
          id: 'public-session',
          network: network,
          walletId: 'public-wallet',
          createdAt: DateTime.utc(2026),
          expiresAt: DateTime.utc(2026, 1, 2),
          payjoinUri: 'bitcoin:fixture',
          transactionId: 'public-txid',
        ),
      );
      expect(
        transaction.supportsPublicExplorer,
        NetworkCapabilities.supports(network, NetworkCapability.publicExplorer),
      );
    });
  }
  test('unknown transaction provenance does not advertise public explorer', () {
    expect(const Transaction().supportsPublicExplorer, isFalse);
  });
}
