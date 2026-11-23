import 'dart:convert';

import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart'
    show
        BitcoinNetwork,
        BitcoinUnit,
        Err,
        Fingerprint,
        LiquidNetwork,
        Ok,
        Result,
        ScriptType;
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart'
    show Wallet, Network;
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:provisioning/provisioning.dart';
import 'package:primitives/primitives.dart' as primitives show Network;
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:startup/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockWalletRepository extends Mock implements WalletRepository {}

/// Records the repair account creations the startup check performs.
final class _RecordingAccounts implements WalletProvisioning {
  final List<({Secret secret, primitives.Network network})> created = [];

  @override
  Future<Result<void, WalletProvisioningFailure>> resume() async =>
      const Ok(null);

  @override
  Future<Result<String, WalletProvisioningFailure>> createDefault(
    Secret secret,
    primitives.Network network, {
    DateTime? birthday,
  }) async {
    created.add((secret: secret, network: network));
    return Ok(network.toString());
  }

  @override
  Future<Result<void, ParentCustodyFailure>> importMnemonic({
    required Fingerprint parent,
    required Secrets secrets,
    required ParentCustodyAdmissionPort admission,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    String? label,
  }) => throw StateError('Unexpected mnemonic provisioning');

  @override
  Future<Result<void, WalletProvisioningFailure>> importDescriptor(
    WatchOnlyAccount account,
  ) => throw StateError('Unexpected descriptor provisioning');

  @override
  Future<Result<void, WalletProvisioningFailure>> importXpub({
    required String xpub,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    required String label,
  }) => throw StateError('Unexpected xpub provisioning');
}

final class _FailingAccounts implements WalletProvisioning {
  @override
  Future<Result<void, WalletProvisioningFailure>> resume() async =>
      const Ok(null);

  @override
  Future<Result<String, WalletProvisioningFailure>> createDefault(
    Secret secret,
    primitives.Network network, {
    DateTime? birthday,
  }) async => fail('complete default pair');

  @override
  Future<Result<void, ParentCustodyFailure>> importMnemonic({
    required Fingerprint parent,
    required Secrets secrets,
    required ParentCustodyAdmissionPort admission,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    String? label,
  }) => throw StateError('Unexpected mnemonic provisioning');

  @override
  Future<Result<void, WalletProvisioningFailure>> importDescriptor(
    WatchOnlyAccount account,
  ) => throw StateError('Unexpected descriptor provisioning');

  @override
  Future<Result<void, WalletProvisioningFailure>> importXpub({
    required String xpub,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    required String label,
  }) => throw StateError('Unexpected xpub provisioning');
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
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
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

  var hasWalletsCalls = 0;

  CheckForExistingDefaultWalletsUsecase usecaseOn(
    FakeSecureStoragePlatform storage, {
    WalletProvisioning? accounts,
  }) {
    storage.install();
    hasWalletsCalls = 0;
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    return CheckForExistingDefaultWalletsUsecase(
      preferences: _StartupPreferences(settings),
      inventory: _StartupInventory(wallets),
      hasWallets: () async {
        hasWalletsCalls++;
        return const Ok(true);
      },
      secrets: secrets,
      repair: DefaultWalletRepair(secrets, accounts ?? _RecordingAccounts()),
    );
  }

  test(
    'empty active regtest preserves an existing catalog without secret IO',
    () async {
      when(settings.fetch).thenAnswer(
        (_) async => Ok(
          const SettingsEntity(
            environment: Environment.regtest,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
          ),
        ),
      );
      when(
        () => wallets.getWallets(
          onlyDefaults: true,
          environment: Environment.regtest,
        ),
      ).thenAnswer((_) async => const Ok([]));
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
      ).called(2);
      expect(
        hasWalletsCalls,
        1,
        reason: 'the existing catalog proves the device',
      );
      verifyNoMoreInteractions(wallets);
      expect(storage.entries, isEmpty);
    },
  );

  void onRegtest(List<Wallet> defaults) {
    when(settings.fetch).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.regtest,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
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
    ).called(2);
    verifyNoMoreInteractions(wallets);
  });

  test(
    'a bitcoin-only regtest set heals its Liquid default from the default seed',
    () async {
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_$fingerprint': entry},
      );
      storage.install();
      onRegtest([wallet(Network.bitcoinRegtest)]);
      final accounts = _RecordingAccounts();

      final result = await usecaseOn(storage, accounts: accounts).execute();

      expect(
        result,
        isA<Ok<bool, AppStartupFailure>>().having(
          (result) => result.value,
          'has defaults',
          true,
        ),
      );
      final created = accounts.created.single;
      expect(created.secret.id.hex, fingerprint);
      expect(created.network, LiquidNetwork.regtest);
      // The catalog is read once, then re-read after the heal.
      verify(
        () => wallets.getWallets(
          onlyDefaults: true,
          environment: Environment.regtest,
        ),
      ).called(4);
      verifyNoMoreInteractions(wallets);
    },
  );

  test('a status conflict never retries the read', () async {
    when(
      () => wallets.getWallets(
        onlyDefaults: any(named: 'onlyDefaults'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async => const Err(WalletLwkStatusConflictFailure()));
    final result = await usecaseOn(FakeSecureStoragePlatform()).execute();
    expect(result, isA<Err<bool, AppStartupFailure>>());
    // Startup no longer owns store deletion: a conflict only fails the check.
    expect(hasWalletsCalls, 0);
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

  test('an absent seed names the wallet and asks for a restore', () async {
    // The fss9 cohort: metadata survived, the entry did not.
    final usecase = usecaseOn(FakeSecureStoragePlatform());

    expect(
      await usecase.execute(),
      isA<Err<bool, AppStartupFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<AppStartupMissingDefaultSecretFailure>()
            .having((f) => f.logMessage, 'logMessage', fingerprint)
            .having((f) => f.walletId, 'walletId', 'origin-bitcoinMainnet'),
      ),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test(
    'a missing Liquid secret identifies the Bitcoin default in its environment',
    () async {
      when(
        () => wallets.getWallets(
          onlyDefaults: any(named: 'onlyDefaults'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer(
        (_) async => Ok<List<Wallet>, WalletFailure>([
          wallet(Network.liquidMainnet),
          wallet(Network.bitcoinMainnet),
        ]),
      );
      final usecase = usecaseOn(FakeSecureStoragePlatform());
      final result = await usecase.execute();
      expect(
        (result as Err).failure,
        isA<AppStartupMissingDefaultSecretFailure>().having(
          (failure) => failure.walletId,
          'walletId',
          'origin-bitcoinMainnet',
        ),
      );
    },
  );

  test(
    'a Liquid default without a matching Bitcoin default fails closed',
    () async {
      when(
        () => wallets.getWallets(
          onlyDefaults: any(named: 'onlyDefaults'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer(
        (_) async => Ok<List<Wallet>, WalletFailure>([
          wallet(Network.liquidMainnet).copyWith(masterFingerprint: 'deadbeef'),
          wallet(Network.bitcoinMainnet),
        ]),
      );
      final usecase = usecaseOn(
        FakeSecureStoragePlatform(entries: {'seed_$fingerprint': entry}),
      );
      expect(
        (await usecase.execute() as Err).failure,
        isA<AppStartupWalletCheckFailure>(),
      );
    },
  );

  test('startup resolves local custody by secret reference', () async {
    final storage = FakeSecureStoragePlatform(
      entries: {'seed_$fingerprint': entry},
    )..install();
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    final inventory = _RegistrationInventory([
      for (final network in [
        Network.bitcoinMainnet.shared,
        LiquidNetwork.mainnet,
      ])
        walletRegistrationForTesting(
          id: network.toString(),
          network: network,
          isDefault: true,
          signer: WalletSigner.local,
          masterFingerprint: Fingerprint('deadbeef'),
          secretFingerprint: Fingerprint(fingerprint),
        ),
    ]);
    final usecase = CheckForExistingDefaultWalletsUsecase(
      preferences: _StartupPreferences(settings),
      inventory: inventory,
      hasWallets: () async => const Ok(true),
      secrets: secrets,
      repair: DefaultWalletRepair(secrets, _FailingAccounts()),
    );
    expect(
      await usecase.execute(),
      isA<Ok<bool, AppStartupFailure>>().having(
        (value) => value.value,
        'has defaults',
        true,
      ),
    );
    expect(storage.entries, contains('seed_$fingerprint'));
  });

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

class _StartupPreferences implements ActiveEnvironmentReader {
  final Preferences _preferences;
  const _StartupPreferences(this._preferences);

  @override
  Future<Ok<Environment, PreferencesFailure>> readActiveEnvironment() async {
    final settings =
        await _preferences.fetch() as Ok<SettingsEntity, PreferencesFailure>;
    return Ok(settings.value.environment);
  }
}

class _StartupInventory extends Mock implements WalletInventory {
  final WalletRepository _wallets;
  _StartupInventory(this._wallets);

  @override
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    primitives.Network network,
  ) async =>
      (await _wallets.getWallets(
            onlyDefaults: true,
            environment: Environment.fromName(network.env.name),
          ))
          .map(
            (wallets) => walletSelectionForTesting([
              for (final wallet in wallets)
                if (wallet.network.shared == network)
                  walletRegistrationForTesting(
                    id: wallet.id,
                    network: network,
                    isDefault: true,
                    signer: WalletSigner.local,
                    masterFingerprint: Fingerprint(wallet.masterFingerprint),
                    secretFingerprint: Fingerprint(wallet.masterFingerprint),
                  ),
            ]),
          )
          .mapErr((_) => const FetchSecretFailure());
}

class _RegistrationInventory extends Mock implements WalletInventory {
  final List<WalletRegistration> registrations;

  _RegistrationInventory(this.registrations);

  @override
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    primitives.Network network,
  ) async => Ok(
    walletSelectionForTesting(
      registrations.where((wallet) => wallet.network == network).toList(),
    ),
  );
}
