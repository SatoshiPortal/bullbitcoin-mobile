/// Live proof against a running regtest Ark stack. Skipped unless
/// BULL_ARK_LIVE_URL and BULL_ARK_LIVE_ESPLORA_URL are set, for example
/// http://127.0.0.1:3535 and http://127.0.0.1:3000.
library;

import 'package:secrets/bip85.dart';

import 'dart:io';

import 'package:preferences/preferences.dart';
import 'package:bull_ark/ark_foreground_setup.dart';
import 'package:secrets/custody.dart';
import 'package:bull_ark/ark_setup.dart'
    show ArkBoardFundingPort, ArkPreferencesRepository;
import 'package:bull_ark/bull_ark.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Bip85 extends Mock implements Bip85Derivations {}

class _Settings extends Mock implements Preferences {}

class _SettingsValue extends Mock implements SettingsEntity {}

class _Wallets extends Mock implements WalletInventory {}

class _Board extends Mock implements ArkBoardFundingPort {}

class _WalletCatalog implements SeedReferencePort {
  @override
  Future<Result<Set<Fingerprint>, Failure>> getCustodyFingerprints() async =>
      const Ok({});
}

class _Preferences implements ArkPreferencesRepository {
  final _enabled = <ArkAccountId, bool>{};
  @override
  Future<Result<bool, ArkFailure>> isEnabled(ArkAccountId account) async =>
      Ok(_enabled[account] ?? false);
  @override
  Future<Result<void, ArkFailure>> setEnabled(
    ArkAccountId account,
    bool enabled,
  ) async {
    _enabled[account] = enabled;
    return const Ok(null);
  }
}

class _Paths extends PathProviderPlatform {
  final String directory;
  _Paths(this.directory);
  @override
  Future<String?> getApplicationDocumentsPath() async => directory;
}

T _value<T>(Result<T, ArkFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('$failure'),
};

void main() {
  final arkUrl = Platform.environment['BULL_ARK_LIVE_URL'];
  final esploraUrl = Platform.environment['BULL_ARK_LIVE_ESPLORA_URL'];
  final skip = arkUrl == null || esploraUrl == null
      ? 'live regtest Ark stack not configured'
      : null;

  test(
    'Settings enable creates the Ark wallet and reads its native balance',
    () async {
      final directory = await Directory.systemTemp.createTemp('ark-live');
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      FakeSecureStoragePlatform().install();
      final secrets = Secrets(
        authority: unlockedSessionAuthority(),
        scratchDirectory: () async => directory.path,
      );
      final parent = switch (await secrets.generate()) {
        Ok(:final value) => value.id,
        Err(:final failure) => throw StateError('$failure'),
      };

      final locator = GetIt.asNewInstance();
      final settings = _Settings();
      final settingsValue = _SettingsValue();
      final wallets = _Wallets();
      final bip85 = _Bip85();
      when(settings.readActiveEnvironment)
          .thenAnswer((_) async => Ok(settingsValue.environment));
      when(settings.readLanguage)
          .thenAnswer((_) async => Ok(settingsValue.language));
      when(() => settingsValue.environment).thenReturn(Environment.regtest);
      when(() => wallets.walletsForNetwork(BitcoinNetwork.regtest)).thenAnswer(
        (_) async => Ok(
          walletSelectionForTesting([
            walletRegistrationForTesting(
              id: 'live-regtest-wallet',
              network: BitcoinNetwork.regtest,
              isDefault: true,
              signer: WalletSigner.local,
              secretFingerprint: parent,
            ),
          ]),
        ),
      );
      when(() => bip85.list()).thenAnswer((_) async => const Ok([]));
      final admission = SqliteParentCustodyAdmission(
        directory: () async => directory.path,
        mayCreate: true,
      );
      locator
        ..registerSingleton<ActiveEnvironmentReader>(settings)
        ..registerSingleton<RuntimeDisplayPreferencesReader>(settings)
        ..registerSingleton<WalletInventory>(wallets)
        ..registerSingleton<Bip85Derivations>(bip85)
        ..registerSingleton<Secrets>(secrets)
        ..registerSingleton<ParentCustodyAdmissionPort>(admission)
        ..registerSingleton<SeedReferences>(
          SeedReferences(
            _WalletCatalog(),
            admission: admission,
            backupVerification: const FakeInventoryBackups(),
          ),
        );

      final opened = await openArkForeground(
        locator,
        inventory: locator<WalletInventory>(),
        arkUrl: Uri.parse(arkUrl!),
        primaryEsploraUrl: Uri.parse(esploraUrl!),
        initializeNew: true,
        boardFunding: (bind: (_, _) => _Board(), close: () async {}),
        preferences: _Preferences(),
      );
      final runtime = switch (opened) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError('open: $failure'),
      };
      addTearDown(() async {
        await runtime.close();
        await locator.reset();
        PathProviderPlatform.instance = previousPaths;
        await directory.delete(recursive: true);
      });

      final account = runtime.account;
      final facade = runtime.feature.facade;
      expect(_value(await facade.isEnabled(account)), false);
      final config = ArkAccountConfig(
        id: account,
        arkUrl: Uri.parse(arkUrl),
        primaryEsploraUrl: Uri.parse(esploraUrl),
      );
      final enabled = await facade.enable(
        config,
        privacyDisclosureAccepted: true,
      );
      final created = switch (enabled) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError('enable: $failure'),
      };
      expect(created.account, account);
      expect(created.recovery, ArkRecoveryStatus.complete);
      expect(_value(await facade.isEnabled(account)), true);

      final synchronized = await facade.synchronize(account, renew: false);
      expect(synchronized, isA<Ok<ArkPassOutcome, ArkFailure>>());
      final read = await facade.read(account);
      final snapshot = switch (read) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError('read: $failure'),
      };
      expect(snapshot.spendable, isNotNull);
      expect(snapshot.serverInfo, isNotNull);
      // Evidence for the delivery log: amounts and server only, no secrets.
      // ignore: avoid_print
      print(
        'ark-live: spendable=${snapshot.spendable} pending=${snapshot.pending} '
        'vtxos=${snapshot.vtxos.length} tip=${snapshot.tipHeight} '
        'stale=${snapshot.stale}',
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
