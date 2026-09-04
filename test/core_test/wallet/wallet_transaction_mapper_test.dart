import 'package:bb_mobile/core/wallet/data/mappers/wallet_transaction_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_transaction_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps a self-spend to an outgoing transaction', () {
    final model = WalletTransactionModel(
      txId: 'self-spend',
      isIncoming: true,
      amountSat: 99000,
      feeSat: 1000,
      vsize: 150,
      inputs: const [],
      outputs: const [],
      isLiquid: false,
      isTestnet: true,
      isRbf: false,
      isToSelf: true,
    );

    final transaction = WalletTransactionMapper.toEntity(
      model,
      walletId: 'wallet-1',
      inputs: const [],
      outputs: const [],
      isRbf: false,
    );

    expect(transaction.direction, WalletTransactionDirection.outgoing);
    expect(transaction.isOutgoing, isTrue);
    expect(transaction.isIncoming, isFalse);
  });
}
