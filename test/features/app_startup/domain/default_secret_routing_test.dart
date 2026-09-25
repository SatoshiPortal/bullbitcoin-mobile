import 'dart:convert';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/app_startup/domain/missing_default_secret_exception.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

/// Startup must not collapse three different states into one screen.
///
/// A locked keystore is transient, and the user is only asked to unlock. A
/// genuine absence is the fss9 cohort, and the remedy is a restore. An
/// unreadable value is neither — offering to replace a seed that may still be
/// recoverable is the one irreversible mistake available here.
///
/// `Secrets` is `final` and takes no injected store (the rule-6 derogation),
/// so the conditions are produced at the plugin seam, which is what the real
/// app has underneath it too.
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
  const fingerprint = '73c5da0a';
  final entry = jsonEncode({
    'mnemonicWords': words,
    'passphrase': null,
    'runtimeType': 'mnemonic',
  });

  late _MockSettingsRepository settings;
  late _MockWalletRepository wallets;

  Wallet wallet(Network network) => Wallet(
    origin: 'origin-${network.name}',
    label: 'Test',
    network: network,
    isDefault: true,
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
    settings = _MockSettingsRepository();
    wallets = _MockWalletRepository();

    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    // A complete default set, so the test exercises the seed read alone.
    when(
      () => wallets.getWallets(
        onlyDefaults: any(named: 'onlyDefaults'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer(
      (_) async => [
        wallet(Network.bitcoinMainnet),
        wallet(Network.liquidMainnet),
      ],
    );
  });

  CheckForExistingDefaultWalletsUsecase usecaseOn(
    FakeSecureStoragePlatform storage,
  ) {
    storage.install();
    return CheckForExistingDefaultWalletsUsecase(
      settingsRepository: settings,
      walletRepository: wallets,
      secrets: Secrets(scratchDirectory: () async => '/tmp'),
    );
  }

  test('a readable seed is a normal start', () async {
    final usecase = usecaseOn(
      FakeSecureStoragePlatform(entries: {'seed_$fingerprint': entry}),
    );

    expect(await usecase.execute(), isTrue);
  });

  test('a locked keystore asks for an unlock, not a restore', () async {
    final usecase = usecaseOn(
      FakeSecureStoragePlatform(
        entries: {'seed_$fingerprint': entry},
        locked: true,
      ),
    );

    await expectLater(
      usecase.execute(),
      throwsA(isA<KeychainLockedException>()),
      reason: 'the seed is intact; the device is not unlocked yet',
    );
  });

  test(
    'an absent seed names the wallet and asks for a restore',
    () async {
      // The fss9 cohort: metadata survived, the entry did not.
      final usecase = usecaseOn(FakeSecureStoragePlatform());

      await expectLater(
        usecase.execute(),
        throwsA(
          isA<MissingDefaultSecretException>().having(
            (e) => e.masterFingerprint,
            'masterFingerprint',
            fingerprint,
          ),
        ),
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('an unreadable seed is neither of those', () async {
    // Still on the device and possibly readable after a plugin fix, so it
    // must not reach the restore flow.
    final usecase = usecaseOn(
      FakeSecureStoragePlatform(
        entries: {'seed_$fingerprint': 'not json at all'},
      ),
    );

    await expectLater(
      usecase.execute(),
      throwsA(
        allOf(
          isA<Exception>(),
          isNot(isA<MissingDefaultSecretException>()),
          isNot(isA<KeychainLockedException>()),
        ),
      ),
    );
  });
}
