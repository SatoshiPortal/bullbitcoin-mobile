// Behavioral proof for the audit finding on the BIP85 derive-next use cases
// (issue #2645 fix).
//
// `fix(bip85)` passes a hardcoded `Environment.mainnet` to `getWallets`, so a
// wallet running on testnet finds no default wallet at all and derivation
// fails instead of using the active-environment default.
import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_hex_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBip85Repository extends Mock implements Bip85Repository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

final _testnetWallet = Wallet(
  origin: 'testnet-default',
  label: 'Secure Bitcoin',
  network: Network.bitcoinTestnet,
  isDefault: true,
  masterFingerprint: 'aabbccdd',
  xpubFingerprint: 'aabbccdd',
  scriptType: ScriptType.bip84,
  xpub: 'tpub',
  externalPublicDescriptor: 'desc',
  internalPublicDescriptor: 'desc',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

void main() {
  late _MockBip85Repository bip85Repository;
  late _MockWalletRepository walletRepository;
  late _MockSeedRepository seedRepository;
  late _MockSettingsRepository settingsRepository;

  final seed = MnemonicSeed(
    mnemonicWords: const [
      'abandon',
      'abandon',
      'abandon',
      'abandon',
      'abandon',
      'abandon',
      'abandon',
      'abandon',
      'abandon',
      'abandon',
      'abandon',
      'about',
    ],
    bytes: Uint8List.fromList(List<int>.filled(32, 7)),
    masterFingerprint: 'aabbccdd',
  );

  setUpAll(() {
    registerFallbackValue(Bip85Application.bip39);
    registerFallbackValue(bip39.MnemonicLength.words12);
  });

  setUp(() {
    bip85Repository = _MockBip85Repository();
    walletRepository = _MockWalletRepository();
    seedRepository = _MockSeedRepository();
    settingsRepository = _MockSettingsRepository();

    // The app is running on testnet.
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );

    // Only a testnet default wallet exists — the app is running on testnet.
    when(
      () => walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: Environment.mainnet,
      ),
    ).thenAnswer((_) async => <Wallet>[]);
    when(
      () => walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: Environment.testnet,
      ),
    ).thenAnswer((_) async => <Wallet>[_testnetWallet]);

    when(() => seedRepository.get(any())).thenAnswer((_) async => seed);
    when(
      () => bip85Repository.fetchNextIndexForApplication(any()),
    ).thenAnswer((_) async => const Ok(0));
    when(
      () => bip85Repository.deriveMnemonic(
        xprvBase58: any(named: 'xprvBase58'),
        length: any(named: 'length'),
        index: any(named: 'index'),
        alias: any(named: 'alias'),
      ),
    ).thenAnswer(
      (_) async => Ok((
        derivation: "83696968'/39'/0'/12'/0'",
        mnemonic: bip39.Mnemonic.fromWords(
          words: const [
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'about',
          ],
        ),
      )),
    );
    when(
      () => bip85Repository.deriveHex(
        xprvBase58: any(named: 'xprvBase58'),
        length: any(named: 'length'),
        index: any(named: 'index'),
        alias: any(named: 'alias'),
      ),
    ).thenAnswer(
      (_) async =>
          const Ok((derivation: "83696968'/128169'/30'/0'", hex: 'ab')),
    );
  });

  test(
    'mnemonic derivation uses the active-environment default wallet',
    () async {
      final usecase = DeriveNextBip85MnemonicFromDefaultWalletUsecase(
        bip85Repository: bip85Repository,
        walletRepository: walletRepository,
        seedRepository: seedRepository,
        settingsRepository: settingsRepository,
      );

      final result = await usecase.execute();

      expect(
        result,
        isA<Ok<({String derivation, bip39.Mnemonic mnemonic}), Bip85Failure>>(),
        reason: 'a testnet default wallet must be usable for BIP85 derivation',
      );
    },
  );

  test('hex derivation uses the active-environment default wallet', () async {
    final usecase = DeriveNextBip85HexFromDefaultWalletUsecase(
      bip85Repository: bip85Repository,
      walletRepository: walletRepository,
      seedRepository: seedRepository,
      settingsRepository: settingsRepository,
    );

    final result = await usecase.execute(length: 30);

    expect(
      result,
      isA<Ok<({String derivation, String hex}), Bip85Failure>>(),
      reason: 'a testnet default wallet must be usable for BIP85 derivation',
    );
  });
}
