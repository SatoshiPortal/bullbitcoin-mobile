import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_scan_key_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import '../../sp_fakes.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWallet extends Mock implements Wallet {}

/// A second BIP39 test vector, so the mainnet and testnet defaults hold
/// different secrets and picking the wrong one shows in the fingerprint.
const _testnetWords = [
  'legal',
  'winner',
  'thank',
  'year',
  'wave',
  'sausage',
  'worth',
  'useful',
  'legal',
  'winner',
  'thank',
  'yellow',
];

void main() {
  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  late Fingerprint mainnetId;
  late Fingerprint testnetId;
  late _MockWalletRepository walletRepository;
  late GetSpScanKeyUsecase usecase;

  _MockWallet defaultWallet(Network network, Fingerprint id) {
    final wallet = _MockWallet();
    when(() => wallet.network).thenReturn(network);
    when(() => wallet.isDefault).thenReturn(true);
    when(() => wallet.masterFingerprint).thenReturn(id.hex);
    return wallet;
  }

  /// Answers like the real repository: the filters the use case passes are
  /// applied to [stored], in [stored]'s order.
  void storeWallets(List<_MockWallet> stored) {
    when(
      () => walletRepository.getWallets(
        environment: any(named: 'environment'),
        onlyDefaults: any(named: 'onlyDefaults'),
        onlyBitcoin: any(named: 'onlyBitcoin'),
      ),
    ).thenAnswer((invocation) async {
      final environment =
          invocation.namedArguments[#environment] as Environment?;
      final onlyDefaults = invocation.namedArguments[#onlyDefaults] == true;
      final onlyBitcoin = invocation.namedArguments[#onlyBitcoin] == true;
      return Ok(
        stored
            .where(
              (w) =>
                  (environment == null ||
                      w.network.isMainnet == environment.isMainnet) &&
                  (!onlyDefaults || w.isDefault) &&
                  (!onlyBitcoin || w.network.isBitcoin),
            )
            .toList(),
      );
    });
  }

  setUpAll(() {
    registerFallbackValue(Environment.mainnet);
  });

  setUp(() async {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    mainnetId =
        ((await secrets.import(words: spTestWords))
                as Ok<Secret, SecretFailure>)
            .value
            .id;
    testnetId =
        ((await secrets.import(words: _testnetWords))
                as Ok<Secret, SecretFailure>)
            .value
            .id;
    walletRepository = _MockWalletRepository();
    usecase = GetSpScanKeyUsecase(
      walletRepository: walletRepository,
      secrets: secrets,
    );
  });

  group('GetSpScanKeyUsecase picks the default of the SP network', () {
    final orders =
        <String, List<_MockWallet> Function(Fingerprint, Fingerprint)>{
          'mainnet default listed first': (main, test) => [
            defaultWallet(Network.bitcoinMainnet, main),
            defaultWallet(Network.liquidMainnet, main),
            defaultWallet(Network.bitcoinTestnet, test),
            defaultWallet(Network.liquidTestnet, test),
          ],
          'testnet default listed first': (main, test) => [
            defaultWallet(Network.liquidTestnet, test),
            defaultWallet(Network.bitcoinTestnet, test),
            defaultWallet(Network.liquidMainnet, main),
            defaultWallet(Network.bitcoinMainnet, main),
          ],
        };
    const expectations = {
      BitcoinNetwork.mainnet: true,
      BitcoinNetwork.testnet: false,
      BitcoinNetwork.signet: false,
      BitcoinNetwork.regtest: false,
    };

    for (final MapEntry(key: order, value: build) in orders.entries) {
      for (final MapEntry(key: network, value: fromMainnet)
          in expectations.entries) {
        test('$order: ${network.name} SP derives from the '
            '${fromMainnet ? 'mainnet' : 'testnet'} default', () async {
          storeWallets(build(mainnetId, testnetId));

          final result = await usecase.execute(network: network);

          final key = (result as Ok<SilentPaymentDescriptors, SpFailure>).value;
          expect(key.fingerprint, fromMainnet ? mainnetId : testnetId);
          expect(key.network, network);
        });
      }
    }
  });

  test('derives the same credential the package derives directly', () async {
    storeWallets([defaultWallet(Network.bitcoinMainnet, mainnetId)]);
    final secret =
        (await secrets.fetch(mainnetId) as Ok<Secret, SecretFailure>).value;
    final direct =
        (await secret.derive.descriptors.silentPayment(
                  network: BitcoinNetwork.mainnet,
                )
                as Ok<SilentPaymentDescriptors, SecretFailure>)
            .value;

    final key =
        (await usecase.execute(network: BitcoinNetwork.mainnet)
                as Ok<SilentPaymentDescriptors, SpFailure>)
            .value;

    expect(key.sp, direct.sp);
    expect(key.taproot, direct.taproot);
  });

  test('no default wallet for the SP network is SpNoDefaultWallet', () async {
    // Only the mainnet default exists; a signet SP wallet must not fall back
    // to it.
    storeWallets([defaultWallet(Network.bitcoinMainnet, mainnetId)]);

    final result = await usecase.execute(network: BitcoinNetwork.signet);

    expect((result as Err).failure, isA<SpNoDefaultWallet>());
  });

  test('a locked keystore is SpKeystoreLocked', () async {
    storeWallets([defaultWallet(Network.bitcoinMainnet, mainnetId)]);
    storage.locked = true;

    final result = await usecase.execute(network: BitcoinNetwork.mainnet);

    final failure = (result as Err).failure;
    expect(failure, isA<SpKeystoreLocked>());
    expect(failure.logMessage, 'KeystoreLockedFailure');
  });

  test('a default whose secret is gone is SpUnexpected with the failure type '
      'only', () async {
    storeWallets([
      defaultWallet(Network.bitcoinMainnet, Fingerprint('deadbeef')),
    ]);

    final result = await usecase.execute(network: BitcoinNetwork.mainnet);

    final failure = (result as Err).failure;
    expect(failure, isA<SpUnexpected>());
    expect(
      failure.logMessage,
      'scan credential unavailable: SecretNotFoundFailure',
    );
  });

  test(
    'a failed wallet read is SpUnexpected, not "no default wallet"',
    () async {
      when(
        () => walletRepository.getWallets(
          environment: any(named: 'environment'),
          onlyDefaults: any(named: 'onlyDefaults'),
          onlyBitcoin: any(named: 'onlyBitcoin'),
        ),
      ).thenAnswer(
        (_) async => const Err<List<Wallet>, WalletFailure>(
          WalletStorageFailure('SqliteException(11): disk image is malformed'),
        ),
      );

      final result = await usecase.execute(network: BitcoinNetwork.mainnet);

      final failure = (result as Err).failure as SpFailure;
      expect(failure, isA<SpUnexpected>());
      // The wallet layer's raw reason stays in its log.
      expect(failure.logMessage, isNot(contains('disk image is malformed')));
    },
  );
}
