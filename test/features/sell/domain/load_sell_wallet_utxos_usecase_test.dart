import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/sell/domain/load_sell_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockGetWalletUtxos extends Mock implements GetWalletUtxosUsecase {}

// WalletUtxo is sealed, so the test uses a real one.

void main() {
  late _MockGetWalletUtxos getWalletUtxos;
  late LoadSellWalletUtxosUsecase usecase;

  setUp(() {
    getWalletUtxos = _MockGetWalletUtxos();
    usecase = LoadSellWalletUtxosUsecase(getWalletUtxosUsecase: getWalletUtxos);
  });

  test('returns the wallet utxos', () async {
    final utxos = <WalletUtxo>[
      WalletUtxo.bitcoin(
        walletId: 'wallet-1',
        txId: 'tx-1',
        vout: 0,
        scriptPubkey: Uint8List(0),
        amountSat: BigInt.from(100000),
        address: 'bc1qaddress',
      ),
    ];
    when(
      () => getWalletUtxos.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => utxos);

    final result = await usecase.execute(walletId: 'wallet-1');

    expect((result as Ok<List<WalletUtxo>, SellFailure>).value, utxos);
  });

  test('sanitizes a lookup failure', () async {
    when(
      () => getWalletUtxos.execute(walletId: any(named: 'walletId')),
    ).thenThrow(Exception('GetUtxosUsecaseException: db locked'));

    final result = await usecase.execute(walletId: 'wallet-1');

    switch (result) {
      case Ok():
        fail('a failed lookup must not report an empty coin list');
      case Err(:final failure):
        expect(failure, isA<SellUnexpectedFailure>());
        expect(failure.logMessage, contains('db locked'));
    }
  });
}
