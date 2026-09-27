import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/fetch_all_bip85_derivations_with_entropy_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockBip85Repository extends Mock implements Bip85Repository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

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
    ).thenAnswer((_) async => Ok(<Wallet>[]));
    when(
      () => walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: Environment.testnet,
      ),
    ).thenAnswer((_) async => Ok(<Wallet>[testnetWallet]));
  });

  test('skips an invalid mnemonic count without dropping valid rows', () async {
    final secret =
        (await secrets.import(words: words)) as Err<Secret, SecretFailure>;
    final id = (secret.failure as SecretAlreadyExistsFailure).id.hex;
    Bip85DerivationEntity row(int count) => Bip85DerivationEntity(
      path: "m/39'/0'/$count'/0'",
      xprvFingerprint: id,
      alias: null,
      status: Bip85Status.active,
      application: Bip85Application.bip39,
      index: 0,
    );
    final valid = row(12);
    when(
      () => bip85Repository.fetchAll(),
    ).thenAnswer((_) async => Ok([row(13), valid]));
    final usecase = FetchAllBip85DerivationsWithEntropyUsecase(
      bip85Repository: bip85Repository,
      walletRepository: walletRepository,
      secrets: secrets,
      settingsRepository: settingsRepository,
    );

    final result = await usecase.execute();
    expect(
      result,
      isA<
        Ok<
          List<({Bip85DerivationEntity derivation, String entropy})>,
          Bip85Failure
        >
      >(),
    );
    final rows =
        (result
                as Ok<
                  List<({Bip85DerivationEntity derivation, String entropy})>,
                  Bip85Failure
                >)
            .value;
    expect(rows.single.derivation, same(valid));
    expect(rows.single.entropy.split(' '), hasLength(12));
  });
}
