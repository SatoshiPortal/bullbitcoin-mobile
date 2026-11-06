import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('balance status conflict propagates without retry', () async {
    var reads = 0;
    final reader = LwkWalletDatasource(
      readWallet: (_) async {
        reads++;
        throw const lwk.LwkError(msg: 'UpdateOnDifferentStatus');
      },
    );
    final wallet = WalletModel.publicLwk(
      id: 'status-conflict',
      combinedCtDescriptor: 'unused',
      isTestnet: true,
    );
    await expectLater(
      reader.getBalance(wallet: wallet),
      throwsA('UpdateOnDifferentStatus'),
    );
    expect(reads, 1);
  });
}
