import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';

class _Reader extends LwkWalletDatasource {
  int deletions = 0;

  _Reader()
    : super(
        readWallet: (_) async =>
            throw const lwk.LwkError(msg: 'UpdateOnDifferentStatus'),
      );

  @override
  Future<void> delete({required WalletModel wallet}) async {
    deletions++;
  }
}

void main() {
  test('balance status conflict preserves the native store', () async {
    final reader = _Reader();
    final wallet = WalletModel.publicLwk(
      id: 'status-conflict',
      combinedCtDescriptor: 'unused',
      isTestnet: true,
    );
    await expectLater(reader.getBalance(wallet: wallet), throwsA(anything));
    expect(reader.deletions, 0);
  });
}
