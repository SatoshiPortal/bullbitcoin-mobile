import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/restore_missing_default_secret_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' hide Network, ScriptType;
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

/// The words the default wallets were built from, and another wallet's.
const _missing = [
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
const _other = [
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
const _missingFingerprint = '73c5da0a';

void main() {
  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  late _MockWalletRepository wallets;
  late RestoreMissingDefaultSecretUsecase usecase;

  Wallet localWallet(String fingerprint) => Wallet(
    origin: 'origin-$fingerprint',
    label: 'Test',
    network: Network.bitcoinMainnet,
    isDefault: false,
    masterFingerprint: fingerprint,
    xpubFingerprint: fingerprint,
    scriptType: ScriptType.bip84,
    xpub: 'xpub',
    externalPublicDescriptor: 'desc',
    internalPublicDescriptor: 'desc',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );

  setUp(() {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    wallets = _MockWalletRepository();
    when(
      () => wallets.getWallets(),
    ).thenAnswer((_) async => Ok<List<Wallet>, WalletFailure>([]));
    usecase = RestoreMissingDefaultSecretUsecase(
      secrets: secrets,
      walletRepository: wallets,
    );
  });

  test('stores the words of the missing wallet', () async {
    final result = await usecase.execute(
      expectedFingerprint: _missingFingerprint,
      words: _missing,
    );

    expect(result, isA<Ok<void, AppStartupFailure>>());
    expect(storage.entries.keys, contains('seed_$_missingFingerprint'));
  });

  test("refuses another wallet's words and leaves nothing behind", () async {
    final result = await usecase.execute(
      expectedFingerprint: _missingFingerprint,
      words: _other,
    );

    expect((result as Err).failure, isA<AppStartupRestoreMismatchFailure>());
    expect(storage.entries, isEmpty);
  });

  test("keeps another wallet's words when a wallet uses them", () async {
    final other =
        (await secrets.import(words: _other)) as Ok<Secret, SecretFailure>;
    final otherFingerprint = other.value.id.hex;
    expect(
      await secrets.trash(Fingerprint(otherFingerprint)),
      isA<Ok<void, SecretFailure>>(),
    );
    when(() => wallets.getWallets()).thenAnswer(
      (_) async =>
          Ok<List<Wallet>, WalletFailure>([localWallet(otherFingerprint)]),
    );

    final result = await usecase.execute(
      expectedFingerprint: _missingFingerprint,
      words: _other,
    );

    expect((result as Err).failure, isA<AppStartupRestoreMismatchFailure>());
    expect(storage.entries.keys, contains('seed_$otherFingerprint'));
  });

  test('refuses words that are not a recovery phrase', () async {
    final result = await usecase.execute(
      expectedFingerprint: _missingFingerprint,
      words: [..._missing.take(11), 'abandon'],
    );

    expect((result as Err).failure, isA<AppStartupRestoreMismatchFailure>());
    expect(storage.entries, isEmpty);
  });
}
