import 'package:bull_ark/ark_wallet_setup.dart';
import 'package:secrets/bip85.dart';

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:background_tasks/background_tasks.dart';

import 'package:bull_ark/ark_foreground_setup.dart';
import 'package:bull_ark/testing.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/custody.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:bull_ark/ark_notification_setup.dart';
import 'package:ark/ark.dart' show ArkClient;
import 'package:bull_ark/bull_ark.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Bip85 extends Mock implements Bip85Derivations {}

class _Admission extends Mock implements ParentCustodyAdmissionPort {}

class _Settings extends Mock implements Preferences {}

class _SettingsValue extends Mock implements SettingsEntity {}

class _Wallets extends Mock implements WalletInventory {}

class _Board extends Mock implements ArkBoardFundingPort {}

/// Records the runtime's use of its Board funding binding.
final class _Binding {
  ArkClient? client;
  Future<String> Function(ArkAccountId account)? source;
  int binds = 0;
  int closes = 0;
  Object? refuse;
  Future<void> Function()? onClose;

  ArkBoardFundingBinding get value => (
    bind: (client, source) {
      binds++;
      this.client = client;
      this.source = source;
      final failure = refuse;
      if (failure != null) throw failure;
      return _Board();
    },
    close: () async {
      closes++;
      await onClose?.call();
    },
  );
}

void _dispatcher() {}

final class _Scheduler implements BackgroundTaskSchedulerPort {
  final calls = <String>[];
  bool fail = false;

  @override
  Future<void> initialize(BackgroundTaskDispatcher dispatcher) async {
    if (fail) throw Exception('scheduler unavailable');
    calls.add('initialize');
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    calls.add('cancel:$uniqueName');
  }

  @override
  Future<void> registerPeriodic({
    required String uniqueName,
    required String taskName,
    required Duration frequency,
    required bool requiresNetwork,
    Duration? initialDelay,
  }) async {
    calls.add('register:$uniqueName');
  }
}

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

class _Bip85Entry extends Fake implements Bip85Derivation {
  @override
  final String parentFingerprint;
  @override
  final String path;
  @override
  final Bip85Status status;

  _Bip85Entry(this.parentFingerprint, this.path, this.status);

  @override
  Bip85Application get application => Bip85Application.bip39;
}

Bip85Derivation _entry({
  required String fingerprint,
  required String path,
  Bip85Status status = Bip85Status.active,
}) => _Bip85Entry(fingerprint, path, status);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ark BIP85 collision admission', () {
    late _Bip85 registry;
    final parent = Fingerprint('12345678');
    setUp(() => registry = _Bip85());

    test('a revoked matching derivation still refuses reuse', () async {
      when(() => registry.list()).thenAnswer(
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
        when(() => registry.list()).thenAnswer(
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
      when(() => registry.list()).thenAnswer(
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
      when(() => registry.list())
          .thenAnswer((_) async => const Err(FetchSecretFailure('Unreadable')));
      expect(
        await ArkDerivationCollision(registry).hasCollision(parent),
        isA<Err<bool, ArkFailure>>(),
      );
    });

    test('malformed recorded owner refuses the complete inventory', () async {
      when(() => registry.list()).thenAnswer(
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
        when(() => registry.list()).thenAnswer(
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
        backupVerification: const FakeInventoryBackups(),
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
        await references.isReferenced(Fingerprint('01234567')),
        isA<Err<bool, Failure>>(),
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
        final inventory = await references.isReferenced(parent);
        expect(inventory, isA<Ok<bool, Failure>>());
        expect((inventory as Ok<bool, Failure>).value, isTrue);
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
      backupVerification: const FakeInventoryBackups(),
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
      await references.isReferenced(Fingerprint('01234567')),
      isA<Err<bool, Failure>>(),
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
        backupVerification: const FakeInventoryBackups(),
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
        await references.isReferenced(Fingerprint('01234567')),
        isA<Err<bool, Failure>>(),
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
      when(settings.readActiveEnvironment)
          .thenAnswer((_) async => Ok(settingsValue.environment));
      when(settings.readLanguage)
          .thenAnswer((_) async => Ok(settingsValue.language));
      when(() => settingsValue.environment).thenReturn(Environment.regtest);
      when(() => wallets.walletsForNetwork(BitcoinNetwork.regtest)).thenAnswer(
        (_) async => Ok(
          walletSelectionForTesting([
            walletRegistrationForTesting(
              id: 'owned-regtest-wallet',
              network: BitcoinNetwork.regtest,
              isDefault: true,
              signer: WalletSigner.local,
              secretFingerprint: Fingerprint('12345678'),
            ),
          ]),
        ),
      );
      locator.registerSingleton<ActiveEnvironmentReader>(settings);
      locator.registerSingleton<RuntimeDisplayPreferencesReader>(settings);
      locator.registerSingleton<WalletInventory>(wallets);
      locator.registerSingleton<Bip85Derivations>(_Bip85());
      FakeSecureStoragePlatform().install();
      locator.registerSingleton<Secrets>(
        Secrets(
          authority: unlockedSessionAuthority(),
          scratchDirectory: () async => directory.path,
        ),
      );
      locator.registerSingleton<ParentCustodyAdmissionPort>(_Admission());
      locator.registerSingleton<SeedReferences>(
        SeedReferences(
          _WalletCatalog(),
          admission: locator<ParentCustodyAdmissionPort>(),
          backupVerification: const FakeInventoryBackups(),
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

    test('unsupported notification locale uses English copy', () {
      expect(
        arkExpiryCopy(const Locale('es')),
        arkExpiryCopy(const Locale('en')),
      );
      expect(
        arkExpiryCopy(const Locale('fr')).title,
        isNot(arkExpiryCopy(const Locale('en')).title),
      );
    });

    test('runtime creates and reopens the durable reminder ledger', () async {
      final first = await openArkForeground(
        locator,
        inventory: locator<WalletInventory>(),
        arkUrl: Uri.parse('http://100.64.0.9:3535'),
        primaryEsploraUrl: Uri.parse('http://100.64.0.9:3000'),
        initializeNew: true,
        boardFunding: _Binding().value,
        preferences: _Preferences(),
      );
      expect(first, isA<Ok<ArkForegroundRuntime, ArkFailure>>());
      expect(
        File('${directory.path}/ark/reminders.sqlite.initialized').existsSync(),
        isTrue,
      );
      await (first as Ok<ArkForegroundRuntime, ArkFailure>).value.close();
      final reopened = await openArkForeground(
        locator,
        inventory: locator<WalletInventory>(),
        arkUrl: Uri.parse('http://100.64.0.9:3535'),
        primaryEsploraUrl: Uri.parse('http://100.64.0.9:3000'),
        initializeNew: false,
        boardFunding: _Binding().value,
        preferences: _Preferences(),
      );
      expect(reopened, isA<Ok<ArkForegroundRuntime, ArkFailure>>());
      await (reopened as Ok<ArkForegroundRuntime, ArkFailure>).value.close();
    });

    test('publishing a protected account registers maintenance', () async {
      final opened = SqliteArkAccountRegistry.open(
        '${directory.path}/schedule.sqlite',
        foreground: true,
        initializeNew: true,
      );
      final registry =
          (opened as Ok<SqliteArkAccountRegistry, ArkFailure>).value;
      addTearDown(registry.close);
      final scheduler = _Scheduler();
      final managed = scheduledArkRegistryForTesting(
        registry,
        _dispatcher,
        scheduler,
      );
      final result = await managed.publish(
        ArkAccountConfig(
          id: account,
          arkUrl: Uri.parse('http://100.64.0.9:3535'),
          primaryEsploraUrl: Uri.parse('http://100.64.0.9:3000'),
        ),
      );
      expect(result, isA<Ok>());
      expect(scheduler.calls, [
        'initialize',
        'register:${BackgroundTask.arkRenewal.id}',
      ]);
      scheduler.fail = true;
      expect(
        await managed.publish(
          ArkAccountConfig(
            id: account,
            arkUrl: Uri.parse('http://100.64.0.9:3535'),
            primaryEsploraUrl: Uri.parse('http://100.64.0.9:3000'),
          ),
        ),
        isA<Ok>(),
      );
      expect(
        (await registry.list() as Ok<List<ArkAccountConfig>, ArkFailure>).value,
        hasLength(1),
      );
    });

    test('scheduler failure does not suppress startup protection', () async {
      expect(
        await prepareArkCustodyReferences(locator, initializeNew: true),
        isA<Ok>(),
      );
      final opened = SqliteArkAccountRegistry.open(
        '${directory.path}/ark/accounts.sqlite',
        foreground: false,
      );
      final registry =
          (opened as Ok<SqliteArkAccountRegistry, ArkFailure>).value;
      expect(
        await registry.publish(
          ArkAccountConfig(
            id: account,
            arkUrl: Uri.parse('http://100.64.0.9:3535'),
            primaryEsploraUrl: Uri.parse('http://100.64.0.9:3000'),
          ),
        ),
        isA<Ok>(),
      );
      registry.close();
      expect(
        await prepareArkMaintenanceSchedule(
          locator,
          _dispatcher,
          scheduler: _Scheduler()..fail = true,
        ),
        isTrue,
      );
    });

    test('a closed runtime refuses further native reads', () async {
      final result = await openArkForeground(
        locator,
        inventory: locator<WalletInventory>(),
        arkUrl: Uri.parse('http://100.64.0.9:3535'),
        primaryEsploraUrl: Uri.parse('http://100.64.0.9:3000'),
        initializeNew: true,
        boardFunding: _Binding().value,
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
        inventory: locator<WalletInventory>(),
        arkUrl: Uri.parse('http://127.0.0.1:3535'),
        primaryEsploraUrl: Uri.parse('http://127.0.0.1:3000'),
        initializeNew: true,
        boardFunding: _Binding().value,
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
      inventory: locator<WalletInventory>(),
      arkUrl: Uri.parse('http://127.0.0.1:3535'),
      primaryEsploraUrl: Uri.parse('http://127.0.0.1:3000'),
      initializeNew: true,
      boardFunding: () => _Binding().value,
      preferences: _Preferences(),
    );

    test('dashboard observation does not open an absent runtime', () async {
      final binding = _Binding();
      final subject = ArkForegroundHost(
        locator,
        inventory: locator<WalletInventory>(),
        arkUrl: Uri.parse('http://127.0.0.1:3535'),
        primaryEsploraUrl: Uri.parse('http://127.0.0.1:3000'),
        initializeNew: true,
        boardFunding: () => binding.value,
        preferences: _Preferences(),
      );
      expect(await subject.homeObservation(), isNull);
      expect(binding.binds, 0);
      await subject.close();
      expect(await subject.homeObservation(), isNull);
    });

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

    test('Board binds once to the runtime client and closes with it', () async {
      final binding = _Binding();
      final result = await openArkForeground(
        locator,
        inventory: locator<WalletInventory>(),
        arkUrl: Uri.parse('http://127.0.0.1:3535'),
        primaryEsploraUrl: Uri.parse('http://127.0.0.1:3000'),
        initializeNew: true,
        boardFunding: binding.value,
        preferences: _Preferences(),
      );
      final runtime = (result as Ok<ArkForegroundRuntime, ArkFailure>).value;
      expect(binding.binds, 1);
      expect(binding.client, isNotNull);
      final source = binding.source;
      if (source == null) throw StateError('missing source resolver');
      expect(await source(runtime.account), 'owned-regtest-wallet');
      when(() => settingsValue.environment).thenReturn(Environment.mainnet);
      await expectLater(source(runtime.account), throwsStateError);
      expect(binding.closes, 0);
      await runtime.close();
      expect(binding.closes, 1);
      await runtime.close();
      expect(binding.closes, 1);
    });

    test(
      'a Board bind failure closes the binding and keeps the error',
      () async {
        final binding = _Binding()..refuse = StateError('factory refused');
        await expectLater(
          openArkForeground(
            locator,
            inventory: locator<WalletInventory>(),
            arkUrl: Uri.parse('http://127.0.0.1:3535'),
            primaryEsploraUrl: Uri.parse('http://127.0.0.1:3000'),
            initializeNew: true,
            boardFunding: binding.value,
            preferences: _Preferences(),
          ),
          throwsA(same(binding.refuse)),
        );
        expect(binding.closes, 1);
      },
    );

    test('a replacement waits until the retired runtime has drained', () async {
      final gate = Completer<void>();
      final bindings = <_Binding>[];
      final subject = ArkForegroundHost(
        locator,
        inventory: locator<WalletInventory>(),
        arkUrl: Uri.parse('http://127.0.0.1:3535'),
        primaryEsploraUrl: Uri.parse('http://127.0.0.1:3000'),
        initializeNew: true,
        boardFunding: () {
          final binding = _Binding();
          if (bindings.isEmpty) binding.onClose = () => gate.future;
          bindings.add(binding);
          return binding.value;
        },
        preferences: _Preferences(),
      );
      addTearDown(() async {
        if (!gate.isCompleted) gate.complete();
        await subject.close();
      });
      expect(
        await subject.current(),
        isA<Ok<ArkForegroundRuntime, ArkFailure>>(),
      );
      subject.invalidate();
      var replaced = false;
      final replacement = subject.current().whenComplete(() => replaced = true);
      await pumpEventQueue();
      expect(bindings.first.closes, 1);
      expect(bindings, hasLength(1));
      expect(replaced, false);
      gate.complete();
      expect(await replacement, isA<Ok<ArkForegroundRuntime, ArkFailure>>());
      expect(bindings, hasLength(2));
    });

    ArkForegroundHost gated(List<_Binding> bindings, Completer<void> gate) =>
        ArkForegroundHost(
          locator,
          inventory: locator<WalletInventory>(),
          arkUrl: Uri.parse('http://127.0.0.1:3535'),
          primaryEsploraUrl: Uri.parse('http://127.0.0.1:3000'),
          initializeNew: true,
          boardFunding: () {
            final binding = _Binding();
            if (bindings.isEmpty) binding.onClose = () => gate.future;
            bindings.add(binding);
            return binding.value;
          },
          preferences: _Preferences(),
        );

    test(
      'a suspended host opens nothing until reopened, after the drain',
      () async {
        final gate = Completer<void>();
        final bindings = <_Binding>[];
        final subject = gated(bindings, gate);
        addTearDown(() async {
          if (!gate.isCompleted) gate.complete();
          await subject.close();
        });
        expect(
          await subject.current(),
          isA<Ok<ArkForegroundRuntime, ArkFailure>>(),
        );

        var confirmed = false;
        final suspending = subject.suspend().whenComplete(
          () => confirmed = true,
        );
        expect(
          await subject.current(),
          isA<Err<ArkForegroundRuntime, ArkFailure>>(),
          reason: 'revoked before the stop is confirmed',
        );
        await pumpEventQueue();
        expect(confirmed, false, reason: 'the Board close is still running');
        expect(bindings, hasLength(1));

        gate.complete();
        await suspending;
        expect(bindings.first.closes, 1);
        expect(
          await subject.current(),
          isA<Err<ArkForegroundRuntime, ArkFailure>>(),
        );
        expect(
          bindings,
          hasLength(1),
          reason: 'no second instance while suspended',
        );

        subject.reopen();
        expect(
          await subject.current(),
          isA<Ok<ArkForegroundRuntime, ArkFailure>>(),
        );
        expect(bindings, hasLength(2));
      },
    );

    test('suspending while a runtime opens leaves none running', () async {
      final bindings = <_Binding>[];
      final subject = gated(bindings, Completer<void>()..complete());
      addTearDown(subject.close);
      final opening = subject.current();
      await subject.suspend();
      expect(await opening, isA<Err<ArkForegroundRuntime, ArkFailure>>());
      expect(
        bindings.every((binding) => binding.closes == binding.binds),
        true,
      );
      expect(await subject.homeObservation(), isNull);
    });

    test(
      'host close waits for retired runtimes and rethrows a failure',
      () async {
        final gate = Completer<void>();
        final failure = StateError('board close failed');
        final subject = ArkForegroundHost(
          locator,
          inventory: locator<WalletInventory>(),
          arkUrl: Uri.parse('http://127.0.0.1:3535'),
          primaryEsploraUrl: Uri.parse('http://127.0.0.1:3000'),
          initializeNew: true,
          boardFunding: () =>
              (_Binding()
                    ..onClose = () async {
                      await gate.future;
                      throw failure;
                    })
                  .value,
          preferences: _Preferences(),
        );
        expect(
          await subject.current(),
          isA<Ok<ArkForegroundRuntime, ArkFailure>>(),
        );
        subject.invalidate();
        var closed = false;
        final closing = subject.close().whenComplete(() => closed = true);
        await pumpEventQueue();
        expect(closed, false);
        gate.complete();
        await expectLater(closing, throwsA(same(failure)));
      },
    );

    test(
      'a close failure completed before reopening keeps the host closed',
      () async {
        final failure = StateError('board close failed');
        var opened = 0;
        final subject = ArkForegroundHost(
          locator,
          inventory: locator<WalletInventory>(),
          arkUrl: Uri.parse('http://127.0.0.1:3535'),
          primaryEsploraUrl: Uri.parse('http://127.0.0.1:3000'),
          initializeNew: true,
          boardFunding: () {
            opened++;
            return (_Binding()..onClose = () async => throw failure).value;
          },
          preferences: _Preferences(),
        );
        final first =
            (await subject.current() as Ok<ArkForegroundRuntime, ArkFailure>)
                .value;
        subject.invalidate();
        expect(await first.isCurrent(), false);
        // The retired close has failed before anyone asks the host again.
        await expectLater(first.close(), throwsA(same(failure)));
        expect(
          await subject.current(),
          isA<Err<ArkForegroundRuntime, ArkFailure>>(),
        );
        expect(opened, 1);
        await expectLater(subject.close(), throwsA(same(failure)));
      },
    );

    test('a wallet network change makes the runtime stale', () async {
      final result = await openArkForeground(
        locator,
        inventory: locator<WalletInventory>(),
        arkUrl: Uri.parse('http://100.64.0.9:3535'),
        primaryEsploraUrl: Uri.parse('http://100.64.0.9:3000'),
        initializeNew: true,
        boardFunding: _Binding().value,
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
          inventory: locator<WalletInventory>(),
          arkUrl: Uri.parse('http://100.64.0.9:3535'),
          primaryEsploraUrl: Uri.parse('http://100.64.0.9:3000'),
          initializeNew: true,
          boardFunding: _Binding().value,
          preferences: _Preferences(),
        ),
        isA<Err<ArkForegroundRuntime, ArkFailure>>(),
      );
    });
  });
}
