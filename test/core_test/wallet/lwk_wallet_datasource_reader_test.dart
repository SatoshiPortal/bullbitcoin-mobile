import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/data/lwk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Wallet extends Mock implements lwk.Wallet {}

class _Tx extends Mock implements lwk.Tx {}

class _Output extends Mock implements lwk.TxOut {}

void main() {
  test('address use checks every Liquid output', () async {
    final native = _Wallet();
    final tx = _Tx();
    final first = _Output();
    final second = _Output();
    when(() => first.address).thenReturn(
      const lwk.Address(standard: 'other', confidential: 'other-ct'),
    );
    when(() => second.address).thenReturn(
      const lwk.Address(standard: 'recipient', confidential: 'recipient-ct'),
    );
    when(() => tx.outputs).thenReturn([first, second]);
    when(() => native.txs()).thenAnswer((_) async => [tx]);
    final reader = LwkWalletDatasource(readWallet: (_) async => native);
    final wallet = WalletModel.publicLwk(
      id: 'outputs',
      combinedCtDescriptor: 'unused',
      network: Network.liquidTestnet,
    );
    expect(await reader.isAddressUsed('recipient', wallet: wallet), isTrue);
    expect(await reader.isAddressUsed('recipient-ct', wallet: wallet), isTrue);
    expect(await reader.isAddressUsed('absent', wallet: wallet), isFalse);
    when(() => native.txs()).thenAnswer((_) async => []);
    expect(await reader.isAddressUsed('recipient', wallet: wallet), isFalse);
  });

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
      network: Network.liquidTestnet,
    );
    await expectLater(
      reader.getBalance(wallet: wallet),
      throwsA('UpdateOnDifferentStatus'),
    );
    expect(reads, 1);
  });
}
