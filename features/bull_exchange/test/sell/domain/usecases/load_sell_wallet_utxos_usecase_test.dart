import 'package:sync/sync.dart'
    show WalletKey, Coin, BitcoinCoin, Keychain, SyncStorageFailure;
import 'package:bull_exchange/src/payin/payin_wallets.dart';

import 'dart:typed_data';

import 'package:bull_exchange/src/sell/domain/usecases/load_sell_wallet_utxos_usecase.dart';
import 'package:bull_exchange/src/sell/domain/sell_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockGetWalletUtxos extends Mock implements PayinWallets {}

// Coin is sealed, so the test uses a real one.

void main() {
  late _MockGetWalletUtxos getWalletUtxos;
  late LoadSellWalletUtxosUsecase usecase;

  setUp(() {
    getWalletUtxos = _MockGetWalletUtxos();
    usecase = LoadSellWalletUtxosUsecase(getWalletUtxos);
  });

  test('returns the wallet utxos', () async {
    final utxos = <Coin>[
      BitcoinCoin(
        outpoint: (txId: 'tx-1', vout: 0),
        keychain: Keychain.external,
        confirmations: 0,
        scriptPubkey: Uint8List(0),
        amountSat: BigInt.from(100000),
        address: 'bc1qaddress',
      ),
    ];
    when(
      () => getWalletUtxos.coins(
        WalletKey(id: 'wallet-1', network: BitcoinNetwork.mainnet),
      ),
    ).thenAnswer((_) async => Ok(utxos));

    final result = await usecase.execute(
      walletKey: WalletKey(id: 'wallet-1', network: BitcoinNetwork.mainnet),
    );

    expect((result as Ok<List<Coin>, SellFailure>).value, utxos);
  });

  test('sanitizes a lookup failure', () async {
    when(
      () => getWalletUtxos.coins(
        WalletKey(id: 'wallet-1', network: BitcoinNetwork.mainnet),
      ),
    ).thenAnswer((_) async => const Err(SyncStorageFailure()));

    final result = await usecase.execute(
      walletKey: WalletKey(id: 'wallet-1', network: BitcoinNetwork.mainnet),
    );

    switch (result) {
      case Ok():
        fail('a failed lookup must not report an empty coin list');
      case Err(:final failure):
        expect(failure, isA<SellUnexpectedFailure>());
        expect(failure.logMessage, contains('Coin control unavailable'));
    }
  });
}
