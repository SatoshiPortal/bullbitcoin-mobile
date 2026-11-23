import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/public/silent_bindings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' hide Network;

class _Repository extends Mock implements WalletRepository {}

class _Wallet extends Mock implements Wallet {}

void main() {
  late _Repository repository;
  late GetIt locator;

  setUp(() {
    repository = _Repository();
    locator = GetIt.asNewInstance()
      ..registerSingleton<WalletRepository>(repository);
  });

  Wallet wallet(Network network, String fingerprint) {
    final wallet = _Wallet();
    when(() => wallet.network).thenReturn(network);
    when(() => wallet.masterFingerprint).thenReturn(fingerprint);
    return wallet;
  }

  for (final regtestFirst in [false, true]) {
    test(
      'testnet inventory is exact with regtestFirst=$regtestFirst',
      () async {
        final regtest = wallet(Network.bitcoinRegtest, '11223344');
        final testnet = wallet(Network.bitcoinTestnet, 'aabbccdd');
        when(() => repository.getWallets(onlyDefaults: true, onlyBitcoin: true))
            .thenAnswer(
              (_) async =>
                  Ok(regtestFirst ? [regtest, testnet] : [testnet, regtest]),
            );
        final lookup = WalletSilentBindings.reader(locator);
        final found = await lookup(BitcoinNetwork.testnet);
        expect(
          found.fold((value) => value, (_) => null),
          Fingerprint('aabbccdd'),
        );
        final missing = await lookup(BitcoinNetwork.mainnet);
        expect(missing, isA<Ok<Fingerprint?, Failure>>());
        expect(
          missing.fold(
            (value) => value,
            (_) => throw StateError('lookup failed'),
          ),
          isNull,
        );
      },
    );
  }

  test('storage errors are not missing wallets', () async {
    when(
      () => repository.getWallets(onlyDefaults: true, onlyBitcoin: true),
    ).thenAnswer((_) async => const Err(WalletStorageFailure('read failed')));
    final lookup = WalletSilentBindings.reader(locator);
    expect(
      await lookup(BitcoinNetwork.testnet),
      isA<Err<Fingerprint?, Failure>>(),
    );
  });
}
