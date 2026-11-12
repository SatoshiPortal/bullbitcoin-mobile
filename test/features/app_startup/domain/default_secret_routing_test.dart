import 'dart:convert';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Fingerprint;
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {
  int storeDeletions = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #deleteLwkDb) {
      storeDeletions++;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

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
      (_) async => Ok<List<Wallet>, WalletFailure>([
        wallet(Network.bitcoinMainnet),
        wallet(Network.liquidMainnet),
      ]),
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

  test(
    'empty active regtest preserves an existing catalog without secret IO',
    () async {
      when(settings.fetch).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.regtest,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      when(
        () => wallets.getWallets(
          onlyDefaults: true,
          environment: Environment.regtest,
        ),
      ).thenAnswer((_) async => const Ok([]));
      when(wallets.hasStoredWallets).thenAnswer((_) async => const Ok(true));
      final storage = FakeSecureStoragePlatform();
      final result = await usecaseOn(storage).execute();
      expect(
        result,
        isA<Ok<bool, AppStartupFailure>>().having(
          (result) => result.value,
          'existing catalog',
          true,
        ),
      );
      verify(
        () => wallets.getWallets(
          onlyDefaults: true,
          environment: Environment.regtest,
        ),
      ).called(1);
      verify(wallets.hasStoredWallets).called(1);
      verifyNoMoreInteractions(wallets);
      expect(storage.entries, isEmpty);
    },
  );

  void onRegtest(List<Wallet> defaults) {
    when(settings.fetch).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.regtest,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    when(
      () => wallets.getWallets(
        onlyDefaults: true,
        environment: Environment.regtest,
      ),
    ).thenAnswer((_) async => Ok(defaults));
  }

  test('a complete regtest default set is not healed', () async {
    onRegtest([wallet(Network.bitcoinRegtest), wallet(Network.liquidRegtest)]);
    final result = await usecaseOn(
      FakeSecureStoragePlatform(entries: {'seed_$fingerprint': entry}),
    ).execute();
    expect(
      result,
      isA<Ok<bool, AppStartupFailure>>().having(
        (result) => result.value,
        'has defaults',
        true,
      ),
    );
    // Only the scoped catalog read is needed; no healing/create call occurs.
    verify(
      () => wallets.getWallets(
        onlyDefaults: true,
        environment: Environment.regtest,
      ),
    ).called(1);
    verifyNoMoreInteractions(wallets);
  });

  test(
    'a bitcoin-only regtest set heals its Liquid default from the default seed',
    () async {
      // `Secret` is final; mocktail's fallback for `any(named: 'secret')` is a
      // real one, read from the same fake keystore.
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_$fingerprint': entry},
      );
      storage.install();
      final fallback = await Secrets(
        scratchDirectory: () async => '/tmp',
      ).fetch(Fingerprint(fingerprint));
      registerFallbackValue((fallback as Ok<Secret, SecretFailure>).value);
      onRegtest([wallet(Network.bitcoinRegtest)]);
      when(
        () => wallets.createWallet(
          secret: any(named: 'secret'),
          network: Network.liquidRegtest,
          scriptType: ScriptType.bip84,
          isDefault: true,
        ),
      ).thenAnswer((_) async => wallet(Network.liquidRegtest));

      final result = await usecaseOn(storage).execute();

      expect(
        result,
        isA<Ok<bool, AppStartupFailure>>().having(
          (result) => result.value,
          'has defaults',
          true,
        ),
      );
      final created = verify(
        () => wallets.createWallet(
          secret: captureAny(named: 'secret'),
          network: Network.liquidRegtest,
          scriptType: ScriptType.bip84,
          isDefault: true,
        ),
      )..called(1);
      expect((created.captured.single as Secret).id.hex, fingerprint);
      // The catalog is read once, then re-read after the heal.
      verify(
        () => wallets.getWallets(
          onlyDefaults: true,
          environment: Environment.regtest,
        ),
      ).called(2);
      verifyNoMoreInteractions(wallets);
    },
  );

  test('a status conflict never deletes stores or retries the read', () async {
    when(
      () => wallets.getWallets(
        onlyDefaults: any(named: 'onlyDefaults'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async => const Err(WalletLwkStatusConflictFailure()));
    final result = await usecaseOn(FakeSecureStoragePlatform()).execute();
    expect(result, isA<Err<bool, AppStartupFailure>>());
    expect(wallets.storeDeletions, 0);
    verify(
      () => wallets.getWallets(
        onlyDefaults: true,
        environment: Environment.mainnet,
      ),
    ).called(1);
  });

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
      // The fss9 cohort: metadata survived, the entry did not.
      final usecase = usecaseOn(FakeSecureStoragePlatform());

      expect(
        await usecase.execute(),
        isA<Err<bool, AppStartupFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<AppStartupMissingDefaultSecretFailure>().having(
            (f) => f.logMessage,
            'logMessage',
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

    expect(
      await usecase.execute(),
      isA<Err<bool, AppStartupFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<AppStartupWalletCheckFailure>(),
      ),
    );
  });
}
