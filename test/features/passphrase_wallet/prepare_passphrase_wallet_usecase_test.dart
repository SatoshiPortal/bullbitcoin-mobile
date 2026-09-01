import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/entities/passphrase_wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/get_passphrase_wallets_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/prepare_passphrase_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok;

import 'support/passphrase_wallet_harness.dart';

class _Settings extends Mock implements GetSettingsUsecase {}

class _DefaultSeed extends Mock implements GetDefaultSeedUsecase {}

void main() {
  late FakePassphraseWalletDeriver deriver;
  late KeychainManifestFacade manifest;
  late FaultInjectingManifestRepository manifestRepository;
  late PreparePassphraseWalletUsecase usecase;

  final parent = Fingerprint(parentFingerprint);

  Future<void> record({
    required String walletId,
    required String descriptor,
    String? label,
  }) async {
    final saved = await manifest.recordWallet(
      parentFingerprint: parent,
      wallet: KeychainManifestWalletInventoryBinding(
        walletId: walletId,
        seedFingerprint: Fingerprint('01234567'),
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        provenance: WalletProvenance.defaultSeedPassphrase,
        derivationPath: "m/84'/0'/0'",
        seedPassphraseUsed: true,
        descriptor: descriptor,
        label: label,
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    expect(saved, isA<Ok<bool, KeychainManifestFailure>>());
  }

  setUp(() {
    final built = buildManifest();
    manifest = built.facade;
    manifestRepository = built.repository;
    deriver = FakePassphraseWalletDeriver({
      'known': (walletId: 'wallet-known', descriptor: firstDescriptor),
    });
    final settings = _Settings();
    final defaultSeed = _DefaultSeed();
    when(settings.execute).thenAnswer((_) async => fakeSettings);
    when(
      () => defaultSeed.execute(environment: any(named: 'environment')),
    ).thenAnswer((_) async => Ok(fakeParentSeed()));
    usecase = PreparePassphraseWalletUsecase(
      defaultSeed,
      settings,
      GetPassphraseWalletsUsecase(defaultSeed, settings, manifest),
      deriver,
    );
  });

  tearDown(() => manifestRepository.dispose());

  test('rejects empty and non-ASCII values before derivation', () async {
    expect(
      await usecase.execute(''),
      isA<Err<PassphraseWalletPreparation, PassphraseWalletFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<InvalidPassphraseFailure>(),
      ),
    );
    expect(
      await usecase.execute('café'),
      isA<Err<PassphraseWalletPreparation, PassphraseWalletFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<InvalidPassphraseFailure>(),
      ),
    );
    expect(deriver.derived, isEmpty);
  });

  test('preserves a printable space-only passphrase', () async {
    expect(await usecase.execute(' '), isA<Ok>());
    expect(deriver.derived, [' ']);
  });

  test('matches an existing wallet by canonical descriptor', () async {
    await record(
      walletId: 'wallet-known',
      descriptor: firstDescriptor,
      label: 'Vault',
    );

    final result = await usecase.execute('known');

    final preparation =
        (result as Ok<PassphraseWalletPreparation, PassphraseWalletFailure>)
            .value;
    expect(preparation.knownWallet?.walletId, 'wallet-known');
    expect(preparation.knownWallet?.label, 'Vault');
    expect(preparation.hasHistory, isTrue);
    expect(preparation.candidate.isHeld, isTrue);
    expect(preparation.toString(), isNot(contains('known')));
    expect(preparation.candidate.toString(), isNot(contains('known')));
  });

  test('an unknown passphrase with history is new, not a match', () async {
    await record(walletId: 'wallet-known', descriptor: firstDescriptor);

    final result = await usecase.execute('brand new');

    final preparation =
        (result as Ok<PassphraseWalletPreparation, PassphraseWalletFailure>)
            .value;
    expect(preparation.isKnown, isFalse);
    expect(preparation.hasHistory, isTrue);
  });

  test('rejects the same wallet id with a different descriptor', () async {
    // The stored record is a different wallet wearing the same id: merging them
    // would silently point one passphrase's card at another's descriptor.
    await record(walletId: 'wallet-known', descriptor: secondDescriptor);

    final result = await usecase.execute('known');

    expect(
      result,
      isA<Err<PassphraseWalletPreparation, PassphraseWalletFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<PassphraseWalletConflictFailure>(),
      ),
    );
    expect(
      deriver.issued['known']!.bytes,
      everyElement(0),
      reason: 'candidate must be cleared',
    );
  });

  test('clears the candidate when the record read fails', () async {
    manifestRepository.failFetch = true;

    expect(await usecase.execute('brand new'), isA<Err>());
    expect(deriver.issued['brand new']!.bytes, everyElement(0));
  });

  test('reports a seed failure without deriving anything', () async {
    final settings = _Settings();
    final defaultSeed = _DefaultSeed();
    when(settings.execute).thenAnswer((_) async => fakeSettings);
    when(
      () => defaultSeed.execute(environment: any(named: 'environment')),
    ).thenAnswer((_) async => const Err(DefaultSeedNotFoundFailure()));

    final result = await PreparePassphraseWalletUsecase(
      defaultSeed,
      settings,
      GetPassphraseWalletsUsecase(defaultSeed, settings, manifest),
      deriver,
    ).execute('secret');

    expect(
      result,
      isA<Err<PassphraseWalletPreparation, PassphraseWalletFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<PassphraseWalletSeedFailure>(),
      ),
    );
    expect(deriver.derived, isEmpty);
  });
}
