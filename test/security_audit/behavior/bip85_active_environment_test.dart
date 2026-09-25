import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_hex_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockBip85Repository extends Mock implements Bip85Repository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

/// BIP85 must use the default wallet of the environment the app is running in.
///
/// The app is on testnet and only a testnet default wallet exists. Asking for the mainnet one would find nothing and report "no default wallet" on a device that has one.
///
/// Since the derivation moved into `secrets`, this also covers the bug that made BIP85 fail on every non-mainnet wallet: the app used to hand the library a network-encoded xprv, and `bip85_entropy` refuses a `tprv`. The package always derives from the mainnet encoding — BIP85 has no testnet — so a testnet wallet derives like any other.
void main() {
  const words = [
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
  ];

  late _MockBip85Repository bip85Repository;
  late _MockWalletRepository walletRepository;
  late _MockSettingsRepository settingsRepository;
  late Secrets secrets;

  setUpAll(() {
    registerFallbackValue(Bip85Application.bip39);
    registerFallbackValue(bip39.MnemonicLength.words12);
  });

  setUp(() async {
    FakeSecureStoragePlatform().install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    final stored =
        (await secrets.import(words: words)) as Ok<Secret, SecretFailure>;
    final testnetWallet = Wallet(
      origin: 'testnet-default',
      label: 'Secure Bitcoin',
      network: Network.bitcoinTestnet,
      isDefault: true,
      masterFingerprint: stored.value.id.hex,
      xpubFingerprint: stored.value.id.hex,
      scriptType: ScriptType.bip84,
      xpub: 'tpub',
      externalPublicDescriptor: 'desc',
      internalPublicDescriptor: 'desc',
      signer: SignerEntity.local,
      signerDevice: null,
      balanceSat: BigInt.zero,
    );

    bip85Repository = _MockBip85Repository();
    walletRepository = _MockWalletRepository();
    settingsRepository = _MockSettingsRepository();

    // The app is running on testnet.
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    // Only a testnet default wallet exists. Asking for mainnet finds nothing.
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
    ).thenAnswer((_) async => <Wallet>[testnetWallet]);

    when(
      () => bip85Repository.fetchNextIndexForApplication(any()),
    ).thenAnswer((_) async => const Ok(0));
    when(
      () => bip85Repository.recordMnemonic(
        xprvFingerprint: any(named: 'xprvFingerprint'),
        length: any(named: 'length'),
        index: any(named: 'index'),
        alias: any(named: 'alias'),
      ),
    ).thenAnswer((_) async => const Ok("83696968'/39'/0'/12'/0'"));
    when(
      () => bip85Repository.recordHex(
        xprvFingerprint: any(named: 'xprvFingerprint'),
        length: any(named: 'length'),
        index: any(named: 'index'),
        alias: any(named: 'alias'),
      ),
    ).thenAnswer((_) async => const Ok("83696968'/128169'/30'/0'"));
  });

  test(
    'mnemonic derivation uses the active-environment default wallet',
    () async {
      final usecase = DeriveNextBip85MnemonicFromDefaultWalletUsecase(
        bip85Repository: bip85Repository,
        walletRepository: walletRepository,
        secrets: secrets,
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
      secrets: secrets,
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
