import 'dart:convert';

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
import 'package:provisioning/provisioning.dart';
import 'package:primitives/primitives.dart' as primitives show Network;
import 'package:startup/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockSettingsRepository extends Mock implements Preferences {}

// The startup use case consumes the public authorized-wallet inventory.
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
  late _RegistrationInventory wallets;

  WalletRegistration wallet(
    primitives.Network network, {
    String parent = fingerprint,
  }) => walletRegistrationForTesting(
    id:
        'origin-${network is BitcoinNetwork ? 'bitcoin' : 'liquid'}'
        '${network.env.name[0].toUpperCase()}${network.env.name.substring(1)}',
    label: 'Test',
    network: network,
    isDefault: true,
    signer: WalletSigner.local,
    masterFingerprint: Fingerprint(parent),
    secretFingerprint: Fingerprint(parent),
  );

  setUp(() {
    settings = _MockSettingsRepository();
    wallets = _RegistrationInventory([
      wallet(BitcoinNetwork.mainnet),
      wallet(LiquidNetwork.mainnet),
    ]);

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
  });

  var hasWalletsCalls = 0;

  CheckForExistingDefaultWalletsUsecase usecaseOn(
    FakeSecureStoragePlatform storage, {
    WalletProvisioning? accounts,
  }) {
    storage.install();
    hasWalletsCalls = 0;
    final secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => '/tmp',
    );
    return CheckForExistingDefaultWalletsUsecase(
      preferences: _StartupPreferences(settings),
      inventory: wallets,
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
      wallets = _RegistrationInventory([]);
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
      expect(wallets.calls, [BitcoinNetwork.regtest, LiquidNetwork.regtest]);
      expect(
        hasWalletsCalls,
        1,
        reason: 'the existing catalog proves the device',
      );
      // The exact network calls above include the complete read sequence.
      expect(storage.entries, isEmpty);
    },
  );

  void onRegtest(List<WalletRegistration> defaults) {
    when(settings.fetch).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.regtest,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      ),
    );
    wallets = _RegistrationInventory(defaults);
  }

  test('a complete regtest default set is not healed', () async {
    onRegtest([wallet(BitcoinNetwork.regtest), wallet(LiquidNetwork.regtest)]);
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
    expect(wallets.calls, [BitcoinNetwork.regtest, LiquidNetwork.regtest]);
    // No other inventory read is needed for a complete default pair.
  });

  test(
    'a bitcoin-only regtest set heals its Liquid default from the default seed',
    () async {
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_$fingerprint': entry},
      );
      storage.install();
      onRegtest([wallet(BitcoinNetwork.regtest)]);
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
      expect(wallets.calls, [
        BitcoinNetwork.regtest,
        LiquidNetwork.regtest,
        BitcoinNetwork.regtest,
        LiquidNetwork.regtest,
      ]);
      // The exact network calls above include the complete read sequence.
    },
  );

  test('an unreadable inventory never retries the read', () async {
    wallets.failure = const UnreadableWalletFailure();
    final result = await usecaseOn(FakeSecureStoragePlatform()).execute();
    expect(result, isA<Err<bool, AppStartupFailure>>());
    // Startup no longer owns store deletion: a failed read only fails the check.
    expect(hasWalletsCalls, 0);
    expect(wallets.calls, [BitcoinNetwork.mainnet]);
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
      wallets = _RegistrationInventory([
        wallet(LiquidNetwork.mainnet),
        wallet(BitcoinNetwork.mainnet),
      ]);
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
      wallets = _RegistrationInventory([
        wallet(LiquidNetwork.mainnet, parent: 'deadbeef'),
        wallet(BitcoinNetwork.mainnet),
      ]);
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
    final secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => '/tmp',
    );
    final inventory = _RegistrationInventory([
      for (final network in <primitives.Network>[
        BitcoinNetwork.mainnet,
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

  test('an unexpected error ends on the startup error screen', () async {
    // Without a result the splash would wait forever.
    wallets.error = StateError('unexpected');
    final usecase = usecaseOn(FakeSecureStoragePlatform());

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

class _RegistrationInventory extends Mock implements WalletInventory {
  final List<WalletRegistration> registrations;
  final calls = <primitives.Network>[];
  Object? error;
  SecretFailure? failure;

  _RegistrationInventory(this.registrations);

  @override
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    primitives.Network network,
  ) async {
    calls.add(network);
    final thrown = error;
    if (thrown != null) throw thrown;
    final failed = failure;
    if (failed != null) return Err(failed);
    return Ok(
      walletSelectionForTesting(
        registrations.where((wallet) => wallet.network == network).toList(),
      ),
    );
  }
}
