import 'dart:io';

import 'package:bb_mobile/features/wallet/data/ark_foreground_host.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet/data/ark_foreground_runtime.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/domain/seed_reference_port.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:bull_ark/bull_ark.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Bip85 extends Mock implements Bip85Repository {}

class _Admission extends Mock implements ParentCustodyAdmissionPort {}

class _Settings extends Mock implements SettingsRepository {}

class _SettingsValue extends Mock implements SettingsEntity {}

class _Wallets extends Mock implements WalletMetadataDatasource {}

class _Wallet extends Mock implements WalletMetadataModel {}

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

Bip85DerivationEntity _entry({
  required String fingerprint,
  required String path,
  Bip85Status status = Bip85Status.active,
}) => Bip85DerivationEntity(
  path: path,
  xprvFingerprint: fingerprint,
  alias: null,
  status: status,
  application: Bip85Application.bip39,
  index: 11811,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ark BIP85 collision admission', () {
    late _Bip85 registry;
    final parent = Fingerprint('12345678');
    setUp(() => registry = _Bip85());

    test('a revoked matching derivation still refuses reuse', () async {
      when(() => registry.fetchAll()).thenAnswer(
        (_) async => Ok([
          _entry(
            fingerprint: parent.hex,
            path: "39'/0'/12'/11811'",
            status: Bip85Status.revoked,
          ),
        ]),
      );
      final result = await ArkDerivationCollision(registry)
          .hasCollision(parent);
      expect(result, isA<Ok<bool, ArkFailure>>());
      expect((result as Ok<bool, ArkFailure>).value, true);
    });

    test(
      'a numerically equivalent padded path cannot evade the guard',
      () async {
        when(() => registry.fetchAll()).thenAnswer(
          (_) async => Ok([
            _entry(fingerprint: parent.hex, path: "39'/00'/012'/011811'"),
          ]),
        );
        final result = await ArkDerivationCollision(registry)
            .hasCollision(parent);
        expect(result, isA<Ok<bool, ArkFailure>>());
        expect((result as Ok<bool, ArkFailure>).value, true);
      },
    );

    test('other parents and other BIP39 paths are not collisions', () async {
      when(() => registry.fetchAll()).thenAnswer(
        (_) async => Ok([
          _entry(fingerprint: '87654321', path: "39'/0'/12'/11811'"),
          _entry(fingerprint: parent.hex, path: "39'/1'/12'/11811'"),
        ]),
      );
      final result = await ArkDerivationCollision(registry)
          .hasCollision(parent);
      expect(result, isA<Ok<bool, ArkFailure>>());
      expect((result as Ok<bool, ArkFailure>).value, false);
    });

    test('an unreadable inventory refuses to authorize child reuse', () async {
      when(() => registry.fetchAll())
          .thenAnswer((_) async => const Err(Bip85StorageFailure()));
      expect(
        await ArkDerivationCollision(registry).hasCollision(parent),
        isA<Err<bool, ArkFailure>>(),
      );
    });

    test('malformed recorded owner refuses the complete inventory', () async {
      when(() => registry.fetchAll()).thenAnswer(
        (_) async =>
            Ok([_entry(fingerprint: 'invalid', path: "39'/0'/12'/11811'")]),
      );
      expect(
        await ArkDerivationCollision(registry).hasCollision(parent),
        isA<Err<bool, ArkFailure>>(),
      );
    });

    test(
      'unknown BIP39 path encoding refuses rather than missing a collision',
      () async {
        when(() => registry.fetchAll()).thenAnswer(
          (_) async =>
              Ok([_entry(fingerprint: parent.hex, path: 'unknown/11811')]),
        );
        expect(
          await ArkDerivationCollision(registry).hasCollision(parent),
          isA<Err<bool, ArkFailure>>(),
        );
      },
    );
  });

  test(
    'custody owner refuses a missing registry until explicit setup',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ark-custody-test',
      );
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      final locator = GetIt.asNewInstance();
      final references = SeedReferences(
        _WalletCatalog(),
        admission: _Admission(),
      );
      locator.registerSingleton<SeedReferences>(references);
      addTearDown(() async {
        await locator.reset();
        PathProviderPlatform.instance = previousPaths;
        await directory.delete(recursive: true);
      });

      expect(
        await prepareArkCustodyReferences(locator, initializeNew: false),
        isA<Err<void, ArkFailure>>(),
      );
      expect(
        await references.getCustodyFingerprints(),
        isA<Err<Set<Fingerprint>, Failure>>(),
      );

      expect(
        await prepareArkCustodyReferences(locator, initializeNew: true),
        isA<Ok<void, ArkFailure>>(),
      );
      final external = SqliteArkAccountRegistry.open(
        '${directory.path}/ark/accounts.sqlite',
        foreground: true,
      );
      expect(external, isA<Ok<SqliteArkAccountRegistry, ArkFailure>>());
      final registry =
          (external as Ok<SqliteArkAccountRegistry, ArkFailure>).value;
      final parent = Fingerprint('12345678');
      try {
        expect(
          await registry.publish(
            ArkAccountConfig(
              id: ArkAccountId(
                parent: parent,
                network: BitcoinNetwork.regtest,
                serverIdentity: 'regtest',
              ),
              arkUrl: Uri.parse('http://100.64.0.9:3535'),
              primaryEsploraUrl: Uri.parse('http://100.64.0.9:3000'),
            ),
          ),
          isA<Ok<void, ArkFailure>>(),
        );
        final inventory = await references.getCustodyFingerprints();
        expect(inventory, isA<Ok<Set<Fingerprint>, Failure>>());
        expect((inventory as Ok<Set<Fingerprint>, Failure>).value, {parent});
      } finally {
        registry.close();
      }
    },
  );

  test('first-setup authorization cannot adopt an orphaned registry', () async {
    final directory = await Directory.systemTemp.createTemp('ark-orphan-test');
    final previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    final locator = GetIt.asNewInstance();
    final references = SeedReferences(
      _WalletCatalog(),
      admission: _Admission(),
    );
    locator.registerSingleton<SeedReferences>(references);
    final arkDirectory = Directory('${directory.path}/ark');
    await arkDirectory.create();
    await File('${arkDirectory.path}/accounts.sqlite').writeAsString('orphan');
    addTearDown(() async {
      await locator.reset();
      PathProviderPlatform.instance = previousPaths;
      await directory.delete(recursive: true);
    });

    expect(
      await prepareArkCustodyReferences(locator, initializeNew: true),
      isA<Err<void, ArkFailure>>(),
    );
    expect(
      File('${arkDirectory.path}/accounts.sqlite.initialized').existsSync(),
      false,
    );
    expect(
      await references.getCustodyFingerprints(),
      isA<Err<Set<Fingerprint>, Failure>>(),
    );
  });

  test(
    'first-setup authorization cannot replace a missing marked database',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ark-marker-test',
      );
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      final locator = GetIt.asNewInstance();
      final references = SeedReferences(
        _WalletCatalog(),
        admission: _Admission(),
      );
      locator.registerSingleton<SeedReferences>(references);
      final arkDirectory = Directory('${directory.path}/ark');
      await arkDirectory.create();
      await File('${arkDirectory.path}/accounts.sqlite.initialized')
          .writeAsString('ark-accounts:1\n');
      addTearDown(() async {
        await locator.reset();
        PathProviderPlatform.instance = previousPaths;
        await directory.delete(recursive: true);
      });

      expect(
        await prepareArkCustodyReferences(locator, initializeNew: true),
        isA<Err<void, ArkFailure>>(),
      );
      expect(File('${arkDirectory.path}/accounts.sqlite').existsSync(), false);
      expect(
        await references.getCustodyFingerprints(),
        isA<Err<Set<Fingerprint>, Failure>>(),
      );
    },
  );

  group('foreground runtime over the selected regtest wallet', () {
    late Directory directory;
    late PathProviderPlatform previousPaths;
    late GetIt locator;
    late _SettingsValue settingsValue;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('ark-runtime-test');
      previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      locator = GetIt.asNewInstance();
      final settings = _Settings();
      settingsValue = _SettingsValue();
      final wallets = _Wallets();
      final wallet = _Wallet();
      when(() => settings.fetch()).thenAnswer((_) async => settingsValue);
      when(() => settingsValue.environment).thenReturn(Environment.regtest);
      when(() => wallets.fetchAll()).thenAnswer((_) async => [wallet]);
      when(() => wallet.networkCode).thenReturn('bitcoinRegtest');
      when(() => wallet.signer).thenReturn(Signer.local);
      when(() => wallet.isDefault).thenReturn(true);
      when(() => wallet.masterFingerprint).thenReturn('12345678');
      when(() => wallet.id).thenReturn('owned-regtest-wallet');
      locator.registerSingleton<SettingsRepository>(settings);
      locator.registerSingleton<WalletMetadataDatasource>(wallets);
      locator.registerSingleton<Bip85Repository>(_Bip85());
      FakeSecureStoragePlatform().install();
      locator.registerSingleton<Secrets>(
        Secrets(scratchDirectory: () async => directory.path),
      );
      locator.registerSingleton<ParentCustodyAdmissionPort>(_Admission());
      locator.registerSingleton<SeedReferences>(
        SeedReferences(
          _WalletCatalog(),
          admission: locator<ParentCustodyAdmissionPort>(),
        ),
      );
    });

    tearDown(() async {
      await locator.reset();
      PathProviderPlatform.instance = previousPaths;
      await directory.delete(recursive: true);
    });

    final account = ArkAccountId(
      parent: Fingerprint('12345678'),
      network: BitcoinNetwork.regtest,
      serverIdentity: 'http://100.64.0.9:3535',
    );

    test('a closed runtime refuses further native reads', () async {
      final result = await openArkForeground(
        locator,
        arkUrl: Uri.parse('http://100.64.0.9:3535'),
        primaryEsploraUrl: Uri.parse('http://100.64.0.9:3000'),
        initializeNew: true,
        preferences: _Preferences(),
      );
      expect(result, isA<Ok<ArkForegroundRuntime, ArkFailure>>());
      final runtime = (result as Ok<ArkForegroundRuntime, ArkFailure>).value;
      expect(await runtime.isCurrent(), true);
      await runtime.close();
      expect(await runtime.isCurrent(), false);
      expect(
        await runtime.feature.facade.read(account),
        isA<Err<ArkSnapshot, ArkFailure>>(),
      );
    });

    test('the root Ark host serves exactly the feature route paths', () async {
      final result = await openArkForeground(
        locator,
        arkUrl: Uri.parse('http://127.0.0.1:3535'),
        primaryEsploraUrl: Uri.parse('http://127.0.0.1:3000'),
        initializeNew: true,
        preferences: _Preferences(),
      );
      final runtime = (result as Ok<ArkForegroundRuntime, ArkFailure>).value;
      addTearDown(runtime.close);
      expect(
        runtime.feature.routes.map((route) => route.path).toSet(),
        arkHostPaths.toSet(),
      );
    });

    ArkForegroundHost host() => ArkForegroundHost(
      locator,
      arkUrl: Uri.parse('http://127.0.0.1:3535'),
      primaryEsploraUrl: Uri.parse('http://127.0.0.1:3000'),
      initializeNew: true,
      preferences: _Preferences(),
    );

    test('host invalidation retires the mounted runtime', () async {
      final subject = host();
      addTearDown(subject.close);
      final first =
          (await subject.current() as Ok<ArkForegroundRuntime, ArkFailure>)
              .value;
      expect(await first.isCurrent(), true);
      subject.invalidate();
      expect(await first.isCurrent(), false);
      final second =
          (await subject.current() as Ok<ArkForegroundRuntime, ArkFailure>)
              .value;
      expect(identical(first, second), false);
      expect(await second.isCurrent(), true);
    });

    test('a runtime still opening when invalidated is not published', () async {
      final subject = host();
      addTearDown(subject.close);
      final pending = subject.current();
      subject.invalidate();
      expect(await pending, isA<Err<ArkForegroundRuntime, ArkFailure>>());
      expect(
        await subject.current(),
        isA<Ok<ArkForegroundRuntime, ArkFailure>>(),
      );
    });

    test('a wallet network change makes the runtime stale', () async {
      final result = await openArkForeground(
        locator,
        arkUrl: Uri.parse('http://100.64.0.9:3535'),
        primaryEsploraUrl: Uri.parse('http://100.64.0.9:3000'),
        initializeNew: true,
        preferences: _Preferences(),
      );
      final runtime = (result as Ok<ArkForegroundRuntime, ArkFailure>).value;
      addTearDown(runtime.close);
      when(() => settingsValue.environment).thenReturn(Environment.mainnet);
      expect(await runtime.isCurrent(), false);
    });

    test('a non-regtest environment opens no runtime', () async {
      when(() => settingsValue.environment).thenReturn(Environment.mainnet);
      expect(
        await openArkForeground(
          locator,
          arkUrl: Uri.parse('http://100.64.0.9:3535'),
          primaryEsploraUrl: Uri.parse('http://100.64.0.9:3000'),
          initializeNew: true,
          preferences: _Preferences(),
        ),
        isA<Err<ArkForegroundRuntime, ArkFailure>>(),
      );
    });
  });
}
