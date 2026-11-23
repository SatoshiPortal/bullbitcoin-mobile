import 'package:silent/src/domain/usecases/create_sp_wallet_usecase.dart';
import 'package:silent/src/domain/usecases/recreate_sp_wallet_usecase.dart';
import 'package:silent/src/domain/usecases/scan_sp_wallet_usecase.dart';
import 'package:silent/src/domain/sp_session_guard.dart';

import 'dart:async';

import 'package:preferences/preferences.dart';
import 'package:silent/src/domain/entities/sp_backend_config.dart';
import 'package:silent/src/domain/entities/sp_wallet.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:silent/src/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import '../../sp_fakes.dart';

class _Settings extends Mock implements Preferences {}

class _Account extends FakeSpAccountRepository {
  void Function()? onSnapshot;
  int disposals = 0, backups = 0, restores = 0;
  void Function()? onCreated;
  bool nativeFailure = false;

  @override
  Future<Result<void, SilentFailure>> createFromSecret({
    required BitcoinNetwork network,
    required Secret secret,
    required String blindbitUrl,
    required String electrumUrl,
    int fetchConcurrencyFactor = 12,
    int matchConcurrencyFactor = 1,
  }) async {
    final result = await super.createFromSecret(
      network: network,
      secret: secret,
      blindbitUrl: blindbitUrl,
      electrumUrl: electrumUrl,
      fetchConcurrencyFactor: fetchConcurrencyFactor,
      matchConcurrencyFactor: matchConcurrencyFactor,
    );
    onCreated?.call();
    return nativeFailure
        ? const Err(SilentUnexpected('native create failed'))
        : result;
  }

  @override
  Future<Result<bool, SilentFailure>> backupAccountDir() async {
    backups++;
    return const Ok(true);
  }

  @override
  Future<Result<bool, SilentFailure>> restoreAccountDir() async {
    restores++;
    return const Ok(true);
  }

  _Account({required super.networkValue, super.hasSessionValue});

  @override
  Result<SilentWallet, SilentFailure> snapshot() {
    onSnapshot?.call();
    return super.snapshot();
  }

  @override
  Future<Result<void, SilentFailure>> dispose() {
    disposals++;
    return super.dispose();
  }
}

void main() {
  late Environment active;
  late _Settings settings;
  late FakeSpBackendConfigRepository config;
  late dynamic gate;
  late MockGetSpSecretUsecase secret;

  setUpAll(() => registerFallbackValue(BitcoinNetwork.mainnet));
  setUp(() {
    active = Environment.mainnet;
    settings = _Settings();
    when(settings.fetch).thenAnswer(
      (_) async => Ok(
        SettingsEntity(
          environment: active,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
          isSuperuser: true,
          isDevModeEnabled: true,
        ),
      ),
    );
    config = FakeSpBackendConfigRepository();
    // Same test source exercises the original constructor and the fixed API.
    try {
      gate = Function.apply(GetSpFeatureGateUsecase.new, const [], {
        #settingsRepository: settings,
        #configRepository: config,
      });
    } on NoSuchMethodError {
      gate = Function.apply(GetSpFeatureGateUsecase.new, const [], {
        #settingsRepository: settings,
      });
    }
    secret = MockGetSpSecretUsecase();
  });

  Future<bool> admit({
    SpBackendConfig? config,
    bool allowUnconfigured = false,
  }) async {
    try {
      return await gate.execute(
        config: config,
        allowUnconfigured: allowUnconfigured,
      ) as bool;
    } on NoSuchMethodError {
      return await gate.execute() as bool;
    }
  }

  EnsureSpSessionUsecase ensure(_Account account) => EnsureSpSessionUsecase(
    getSpFeatureGateUsecase: gate,
    repository: account,
    files: account,
    configRepository: config,
    getSpSecretUsecase: secret,
  );

  for (final stored in [BitcoinNetwork.mainnet, BitcoinNetwork.testnet]) {
    test(
      'gate admits only the stored $stored network and returning to it',
      () async {
        final captured = spBackendConfig(network: stored);
        await config.save(captured);
        active = stored == BitcoinNetwork.mainnet
            ? Environment.mainnet
            : Environment.testnet;
        expect(await admit(config: captured), isTrue);
        active = active == Environment.mainnet
            ? Environment.testnet
            : Environment.mainnet;
        expect(await admit(config: captured), isFalse);
        expect((await config.fetch() as Ok).value, captured);
        active = stored == BitcoinNetwork.mainnet
            ? Environment.mainnet
            : Environment.testnet;
        expect(await admit(config: captured), isTrue);
      },
    );

    test(
      'recreate refuses a different requested network before touching $stored',
      () async {
        active = stored == BitcoinNetwork.mainnet
            ? Environment.mainnet
            : Environment.testnet;
        final captured = spBackendConfig(network: stored);
        await config.save(captured);
        final account = _Account(networkValue: stored);
        addTearDown(account.disposeStreams);
        final usecase = RecreateSpWalletUsecase(
          getSpFeatureGateUsecase: gate,
          getSpSecretUsecase: secret,
          repository: account,
          files: account,
          configRepository: config,
          ensureSpSessionUsecase: ensure(account),
          guard: SpSessionGuard(),
        );
        final requested = stored == BitcoinNetwork.mainnet
            ? BitcoinNetwork.testnet
            : BitcoinNetwork.mainnet;
        final result = await usecase.execute(
          network: requested,
          blindbitUrl: 'https://b.example',
          electrumUrl: 'ssl://e.example:50002',
        );
        expect((result as Err).failure, isA<SilentUnsupportedNetwork>());
        verifyZeroInteractions(secret);
        expect(account.disposals, 0);
        expect(account.backups, 0);
        expect((await config.fetch() as Ok).value, captured);
      },
    );

    test('live $stored session cannot cross active networks', () async {
      await config.save(spBackendConfig(network: stored));
      final account = _Account(networkValue: stored);
      addTearDown(account.disposeStreams);
      active = stored == BitcoinNetwork.mainnet
          ? Environment.testnet
          : Environment.mainnet;
      final result = await ensure(account).execute();
      expect((result as Err).failure, isA<SilentUnsupportedNetwork>());
      expect(account.hasSession, isTrue);
      expect(account.disposals, 0);
      expect(account.createCount, 0);
      verifyZeroInteractions(secret);
    });
  }

  test(
    'missing config permits setup availability but never a live snapshot',
    () async {
      expect(await admit(allowUnconfigured: true), isTrue);
      expect(await admit(), isFalse);
      final account = _Account(networkValue: BitcoinNetwork.mainnet);
      addTearDown(account.disposeStreams);
      expect((await ensure(account).execute() as Ok).value, isNull);
      expect(account.hasSession, isTrue);
      expect(account.disposals, 0);
    },
  );

  test(
    'storage failure and unsupported active network close availability',
    () async {
      config.readShouldFail = true;
      expect(await admit(allowUnconfigured: true), isFalse);
      config.readShouldFail = false;
      active = Environment.regtest;
      expect(await admit(allowUnconfigured: true), isFalse);
    },
  );

  test(
    'captured config does not authorize another config on the same network',
    () async {
      final captured = spBackendConfig(network: BitcoinNetwork.mainnet);
      await config.save(
        spBackendConfig(
          network: BitcoinNetwork.mainnet,
          blindbitUrl: 'https://another.example',
        ),
      );
      expect(await admit(config: captured), isFalse);
    },
  );

  for (final live in [null, BitcoinNetwork.testnet]) {
    test(
      'unknown or different live network $live cannot publish snapshot',
      () async {
        await config.save(spBackendConfig(network: BitcoinNetwork.mainnet));
        final account = _Account(networkValue: live);
        addTearDown(account.disposeStreams);
        expect(
          (await ensure(account).execute() as Err).failure,
          isA<SilentUnsupportedNetwork>(),
        );
        expect(account.disposals, 0);
      },
    );
  }

  test(
    'switch during snapshot publication refuses without disposing',
    () async {
      await config.save(spBackendConfig(network: BitcoinNetwork.mainnet));
      final account = _Account(networkValue: BitcoinNetwork.mainnet)
        ..onSnapshot = () {
          active = Environment.testnet;
        };
      addTearDown(account.disposeStreams);
      expect(
        (await ensure(account).execute() as Err).failure,
        isA<SilentUnsupportedNetwork>(),
      );
      expect(account.disposals, 0);
      active = Environment.mainnet;
      account.onSnapshot = null;
      final wallet =
          (await ensure(account).execute() as Ok).value as SilentWallet;
      expect((wallet as dynamic).network, BitcoinNetwork.mainnet);
    },
  );

  test(
    'shared establishment revalidates after a switch during secret lookup',
    () async {
      await config.save(spBackendConfig(network: BitcoinNetwork.mainnet));
      final pending = Completer<Result<Secret, SilentFailure>>();
      final started = Completer<void>();
      when(() => secret.execute(BitcoinNetwork.mainnet)).thenAnswer((_) {
        started.complete();
        return pending.future;
      });
      final account = _Account(
        networkValue: BitcoinNetwork.mainnet,
        hasSessionValue: false,
      );
      addTearDown(account.disposeStreams);
      final usecase = ensure(account);
      final first = usecase.execute();
      await started.future;
      final second = usecase.execute();
      await pumpEventQueue(times: 20);
      active = Environment.testnet;
      pending.complete(Ok(await spSecret()));
      expect((await first as Err).failure, isA<SilentUnsupportedNetwork>());
      expect((await second as Err).failure, isA<SilentUnsupportedNetwork>());
      expect(account.createCount, 0);
      expect(account.disposals, 0);
      expect((await config.fetch() as Ok).value, isNotNull);
    },
  );
  test(
    'switch during owned create finishes without deleting its inactive account',
    () async {
      final handle = await spSecret();
      when(() => secret.execute(BitcoinNetwork.mainnet))
          .thenAnswer((_) async => Ok(handle));
      final account =
          _Account(networkValue: BitcoinNetwork.mainnet, hasSessionValue: false)
            ..onCreated = () {
              active = Environment.testnet;
            };
      addTearDown(account.disposeStreams);
      final create = CreateSpWalletUsecase(
        getSpSecretUsecase: secret,
        settingsRepository: settings,
        repository: account,
        files: account,
        configRepository: config,
        scanSpWalletUsecase: ScanSpWalletUsecase(
          getSpFeatureGateUsecase: gate,
          repository: account,
        ),
      );
      final result = await create.execute(
        network: BitcoinNetwork.mainnet,
        blindbitUrl: 'https://blindbit.example',
        electrumUrl: 'ssl://electrum.example:50002',
        scanFromNow: false,
      );
      expect((result as Err).failure, isA<SilentUnsupportedNetwork>());
      expect(account.createCount, 1);
      expect(account.hasSession, isTrue);
      expect(account.disposals, 0);
      expect(
        ((await config.fetch() as Ok).value as SpBackendConfig).network,
        BitcoinNetwork.mainnet,
      );
      active = Environment.mainnet;
      expect(
        await ensure(account).execute(),
        isA<Ok<SilentWallet?, SilentFailure>>(),
      );
    },
  );

  test(
    'switch during failed recreate still completes its owned rollback',
    () async {
      final previous = spBackendConfig(network: BitcoinNetwork.mainnet);
      await config.save(previous);
      final handle = await spSecret();
      when(() => secret.execute(BitcoinNetwork.mainnet))
          .thenAnswer((_) async => Ok(handle));
      final account = _Account(networkValue: BitcoinNetwork.mainnet)
        ..nativeFailure = true
        ..onCreated = () {
          active = Environment.testnet;
        };
      addTearDown(account.disposeStreams);
      final recreate = RecreateSpWalletUsecase(
        getSpFeatureGateUsecase: gate,
        getSpSecretUsecase: secret,
        repository: account,
        files: account,
        configRepository: config,
        ensureSpSessionUsecase: ensure(account),
        guard: SpSessionGuard(),
      );
      final result = await recreate.execute(
        network: BitcoinNetwork.mainnet,
        blindbitUrl: 'https://new.example',
        electrumUrl: 'ssl://new.example:50002',
      );
      expect((result as Err).failure, isA<SilentUnexpected>());
      expect(account.backups, 1);
      expect(account.restores, 1);
      expect(account.disposals, 2);
      expect((await config.fetch() as Ok).value, previous);
    },
  );
}
