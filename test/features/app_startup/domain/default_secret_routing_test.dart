import 'dart:convert';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bb_mobile/features/app_startup/data/shared_preferences_startup_storage_repository.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

/// Startup distinguishes locked, missing, unreadable and retired storage.
/// An Android fss9 marker stops startup before wallet or keystore access;
/// missing and unreadable current-store seeds have distinct typed outcomes.
/// Conditions are injected at the secure-storage plugin seam.
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

  Wallet wallet(Network network, {String masterFingerprint = fingerprint}) =>
      Wallet(
        origin: 'origin-${network.name}',
        label: 'Test',
        network: network,
        isDefault: true,
        masterFingerprint: masterFingerprint,
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
    SharedPreferences.setMockInitialValues({});
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
      (_) async =>
          Ok([wallet(Network.bitcoinMainnet), wallet(Network.liquidMainnet)]),
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
      startupStorageRepository: SharedPreferencesStartupStorageRepository(
        isAndroid: true,
      ),
    );
  }

  test('a readable seed is a normal start', () async {
    final usecase = usecaseOn(
      FakeSecureStoragePlatform(entries: {'seed_$fingerprint': entry}),
    );

    expect(
      await usecase.execute(),
      isA<Ok<bool, AppStartupFailure>>().having(
        (r) => r.value,
        'value',
        isTrue,
      ),
    );
  });

  test('a locked keystore asks for an unlock, not a restore', () async {
    final usecase = usecaseOn(
      FakeSecureStoragePlatform(
        entries: {'seed_$fingerprint': entry},
        locked: true,
      ),
    );

    expect(
      await usecase.execute(),
      isA<Err<bool, AppStartupFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<AppStartupKeychainLockedFailure>(),
      ),
      reason: 'the seed is intact; the device is not unlocked yet',
    );
  });

  test(
    'an absent seed names the wallet and asks for a restore',
    () async {
      // Current-store metadata survived, but its seed entry is absent.
      final usecase = usecaseOn(FakeSecureStoragePlatform());

      expect(
        await usecase.execute(),
        isA<Err<bool, AppStartupFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<AppStartupDefaultSecretMissingFailure>().having(
            (f) => f.logMessage,
            'logMessage',
            contains(fingerprint),
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

    expect(
      await usecase.execute(),
      isA<Err<bool, AppStartupFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<AppStartupDefaultSecretUnreadableFailure>().having(
          (f) => f.logMessage,
          'logMessage',
          isNot(contains(fingerprint)),
        ),
      ),
    );
  });
  test(
    'missing and unreadable secrets have distinct recovery outcomes',
    () async {
      final missing = await usecaseOn(FakeSecureStoragePlatform()).execute();
      final unreadable = await usecaseOn(
        FakeSecureStoragePlatform(entries: {'seed_$fingerprint': 'not json'}),
      ).execute();
      expect(missing, isA<Err<bool, AppStartupFailure>>());
      expect(unreadable, isA<Err<bool, AppStartupFailure>>());
      expect(
        (missing as Err<bool, AppStartupFailure>).failure.runtimeType,
        isNot((unreadable as Err<bool, AppStartupFailure>).failure.runtimeType),
        reason:
            'absence requires a verified backup; unreadable storage must be preserved',
      );
    },
  );
  test(
    'a malformed stored fingerprint is unreadable, never a missing secret',
    () async {
      when(
        () => wallets.getWallets(
          onlyDefaults: any(named: 'onlyDefaults'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer(
        (_) async => Ok([
          wallet(Network.bitcoinMainnet, masterFingerprint: 'malformed'),
          wallet(Network.liquidMainnet, masterFingerprint: 'malformed'),
        ]),
      );
      final result = await usecaseOn(FakeSecureStoragePlatform()).execute();
      expect(
        result,
        isA<Err<bool, AppStartupFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<AppStartupDefaultSecretUnreadableFailure>(),
        ),
      );
    },
  );

  test('fss9 requests restoration before wallet and seed access', () async {
    SharedPreferences.setMockInitialValues({
      'seed_store_type': '{"storageLibrary":"fss9"}',
    });
    final storage = FakeSecureStoragePlatform(
      entries: {'seed_$fingerprint': entry},
    );
    final before = Map<String, String>.of(storage.entries);
    final result = await usecaseOn(storage).execute();

    expect(
      result,
      isA<Err<bool, AppStartupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<AppStartupLegacyStorageFailure>(),
      ),
    );
    verifyZeroInteractions(settings);
    verifyZeroInteractions(wallets);
    expect(storage.reads, 0);
    expect(storage.entries, before);
  });

  test(
    'malformed storage metadata fails before wallet and seed access',
    () async {
      SharedPreferences.setMockInitialValues({'seed_store_type': 'not json'});
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_$fingerprint': entry},
      );
      final result = await usecaseOn(storage).execute();

      expect(
        result,
        isA<Err<bool, AppStartupFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<AppStartupWalletCheckFailure>(),
        ),
      );
      verifyZeroInteractions(settings);
      verifyZeroInteractions(wallets);
      expect(storage.reads, 0);
      expect(storage.entries, {'seed_$fingerprint': entry});
    },
  );
}
