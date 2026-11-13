import 'package:bb_mobile/features/sp/domain/usecases/check_sp_setup_entry_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/resume_sp_setup_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_secret_usecase.dart';
import 'dart:async';

import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_backend_probe_port.dart';
import 'package:bb_mobile/features/sp/domain/usecases/create_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_connection_status.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCreateSpWalletUsecase extends Mock implements CreateSpWalletUsecase {}

class _MockResumeSpSetupUsecase extends Mock implements ResumeSpSetupUsecase {}

class _MockCheckSpSetupEntryUsecase extends Mock
    implements CheckSpSetupEntryUsecase {}

class _MockGetSpSecretUsecase extends Mock implements GetSpSecretUsecase {}

/// Stubs the regtest-defaults + backend-test paths the setup cubit exercises;
/// the static networks come from [SpConfig] inside the real usecase.
class _FakeBackendProbe implements SpBackendProbePort {
  _FakeBackendProbe(
    this._regtest, {
    Future<void> Function({required String url})? testBlindbit,
    Future<void> Function({required String url})? testElectrum,
    Future<void>? regtestGate,
  }) : _testBlindbit = testBlindbit ?? (({required String url}) async {}),
       _testElectrum = testElectrum ?? (({required String url}) async {}),
       _regtestGate = regtestGate ?? Future<void>.value();

  final Result<SpBackendDefaults, SpFailure> _regtest;
  final Future<void> Function({required String url}) _testBlindbit;
  final Future<void> Function({required String url}) _testElectrum;
  // The regtest fetch blocks on this before resolving; a test passes a gate it
  // releases later to simulate a slow fetch that lands after the user typed. It
  // defaults to an already-completed future, so an ungated fetch resolves at once.
  final Future<void> _regtestGate;

  @override
  Future<Result<SpBackendDefaults, SpFailure>> fetchRegtestDefaults() async {
    await _regtestGate;
    return _regtest;
  }

  @override
  Future<Result<void, SpFailure>> testBackend(
    SpBackendKind kind,
    String url,
  ) async {
    try {
      switch (kind) {
        case SpBackendKind.blindbit:
          await _testBlindbit(url: url);
        case SpBackendKind.electrum:
          await _testElectrum(url: url);
      }
      return const Ok(null);
    } catch (e) {
      return Err(SpBackendUnreachable('SP backend test failed ($url): $e'));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  setUpAll(() {
    registerFallbackValue(BitcoinNetwork.regtest);
  });

  late SpSetupCubit cubit;
  late MockCreateSpWalletUsecase mockCreate;

  const regtestDefaults = Ok<SpBackendDefaults, SpFailure>(
    SpBackendDefaults(
      blindbitUrl: 'http://127.0.0.1:8000',
      electrumUrl: 'tcp://127.0.0.1:50001',
    ),
  );

  SpSetupCubit buildSetup({
    Future<void> Function({required String url})? testBlindbit,
    Future<void> Function({required String url})? testElectrum,
    Result<SpBackendDefaults, SpFailure>? regtest,
    Future<void>? regtestGate,
    Result<bool, SpFailure>? entryResult,
    Future<Result<bool, SpFailure>>? entryFuture,
    _MockResumeSpSetupUsecase? resume,
  }) {
    final probe = _FakeBackendProbe(
      regtest ?? regtestDefaults,
      testBlindbit: testBlindbit,
      testElectrum: testElectrum,
      regtestGate: regtestGate,
    );
    final entry = _MockCheckSpSetupEntryUsecase();
    when(() => entry.execute()).thenAnswer(
      (_) => entryFuture ?? Future.value(entryResult ?? const Ok(false)),
    );
    return SpSetupCubit(
      checkSpSetupEntryUsecase: entry,
      createSpWalletUsecase: mockCreate,
      getSpSecretUsecase: _MockGetSpSecretUsecase(),
      resumeSpSetupUsecase: resume ?? _MockResumeSpSetupUsecase(),
      testSpBackendUsecase: TestSpBackendUsecase(probe: probe),
      getSpBackendDefaultsUsecase: GetSpBackendDefaultsUsecase(probe: probe),
    );
  }

  Future<void> waitForDefaultTests(SpSetupCubit c) {
    bool tested(SpConnectionStatus test) =>
        test == SpConnectionStatus.ok || test == SpConnectionStatus.failed;
    final settled =
        !c.state.isFetchingDefaults &&
        tested(c.state.blindbitStatus) &&
        tested(c.state.electrumStatus);
    if (settled) return Future<void>.value();
    return c.stream.firstWhere(
      (s) =>
          !s.isFetchingDefaults &&
          tested(s.blindbitStatus) &&
          tested(s.electrumStatus),
    );
  }

  setUp(() async {
    mockCreate = MockCreateSpWalletUsecase();

    when(
      () => mockCreate.execute(
        network: any(named: 'network'),
        walletId: any(named: 'walletId'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
        scanFromNow: any(named: 'scanFromNow'),
      ),
    ).thenAnswer((_) async => const Ok<void, SpFailure>(null));

    cubit = buildSetup();
    // The cubit fetches and tests defaults asynchronously after construction;
    // wait for that to land so tests start from resolved defaults.
    await waitForDefaultTests(cubit);
  });

  tearDown(() => cubit.close());

  group('SpSetupCubit', () {
    test(
      'a busy teardown retains the pending binding for a later retry',
      () async {
        final resume = _MockResumeSpSetupUsecase();
        var attempts = 0;
        when(() => resume.execute()).thenAnswer((_) async {
          attempts++;
          return attempts == 1 ? const Err(SpSessionBusy()) : const Ok(null);
        });
        final pending = buildSetup(
          entryResult: const Err(SpRecoveryRequired()),
          resume: resume,
        );
        await pending.stream.firstWhere((state) => !state.isInspecting);
        await pending.retryPendingSetup();
        expect(pending.state.entryFailure, isA<SpRecoveryRequired>());
        expect(pending.state.error, isA<SpSessionBusy>());
        expect(pending.state.created, isFalse);
        await pending.retryPendingSetup();
        expect(pending.state.created, isTrue);
        verify(() => resume.execute()).called(2);
        await pending.close();
      },
    );

    test(
      'does not test a backend or enable creation before inspection finishes',
      () async {
        final entry = Completer<Result<bool, SpFailure>>();
        var backendCalls = 0;
        final waiting = buildSetup(
          entryFuture: entry.future,
          testBlindbit: ({required url}) async {
            backendCalls++;
          },
          testElectrum: ({required url}) async {
            backendCalls++;
          },
        );
        await waiting.setNetwork(BitcoinNetwork.regtest);
        expect(waiting.state.isInspecting, isTrue);
        expect(waiting.state.canCreate, isFalse);
        expect(backendCalls, 0);
        entry.complete(const Err(SpConfigInvalid('invalid')));
        await waiting.stream.firstWhere((state) => !state.isInspecting);
        expect(backendCalls, 0);
        expect(waiting.state.entryFailure, isA<SpConfigInvalid>());
        await waiting.close();
      },
    );

    test(
      'pending marker presents recovery without fetching network defaults',
      () async {
        final pending = buildSetup(
          entryResult: const Err(SpRecoveryRequired()),
        );
        await pending.stream.firstWhere((s) => !s.isInspecting);
        expect(pending.state.error, isA<SpRecoveryRequired>());
        expect(pending.state.created, isFalse);
        await pending.close();
      },
    );

    test('verified account redirects without offering a new setup', () async {
      final verified = buildSetup(entryResult: const Ok(true));
      await verified.stream.firstWhere((s) => !s.isInspecting);
      expect(verified.state.created, isTrue);
      expect(verified.state.existingVerified, isTrue);
      await verified.close();
    });

    test(
      'unverifiable state reports its failure without offering a new setup',
      () async {
        final blocked = buildSetup(
          entryResult: const Err(SpConfigInvalid('invalid')),
        );
        await blocked.stream.firstWhere((s) => !s.isInspecting);
        expect(blocked.state.error, isA<SpConfigInvalid>());
        expect(blocked.state.created, isFalse);
        await blocked.close();
      },
    );

    test('initial state is default', () {
      expect(cubit.state.network, BitcoinNetwork.mainnet);
      expect(cubit.state.blindbitUrl, isNotEmpty);
      expect(cubit.state.electrumUrl, isNotEmpty);
      expect(cubit.state.blindbitStatus, SpConnectionStatus.ok);
      expect(cubit.state.electrumStatus, SpConnectionStatus.ok);
      expect(cubit.state.isCreating, isFalse);
      expect(cubit.state.created, isFalse);
      expect(cubit.state.error, isNull);
    });

    test('constructor loads and tests bitcoin defaults', () async {
      final tested = <String>[];
      final c = buildSetup(
        testBlindbit: ({required String url}) async => tested.add(url),
        testElectrum: ({required String url}) async => tested.add(url),
      );
      addTearDown(c.close);

      await waitForDefaultTests(c);

      expect(c.state.network, BitcoinNetwork.mainnet);
      expect(
        tested,
        contains(SpConfig.staticDefaults(BitcoinNetwork.mainnet)!.blindbitUrl),
      );
      expect(
        tested,
        contains(SpConfig.staticDefaults(BitcoinNetwork.mainnet)!.electrumUrl),
      );
      expect(c.state.canCreate, isTrue);
    });

    test('setNetwork to bitcoin pre-fills default URLs', () async {
      await cubit.setNetwork(BitcoinNetwork.mainnet);

      expect(cubit.state.network, BitcoinNetwork.mainnet);
      expect(
        cubit.state.blindbitUrl,
        SpConfig.staticDefaults(BitcoinNetwork.mainnet)!.blindbitUrl,
      );
      expect(
        cubit.state.electrumUrl,
        SpConfig.staticDefaults(BitcoinNetwork.mainnet)!.electrumUrl,
      );
      expect(cubit.state.blindbitUrl, isNotEmpty);
      expect(cubit.state.electrumUrl, isNotEmpty);
      expect(cubit.state.blindbitStatus, SpConnectionStatus.ok);
      expect(cubit.state.electrumStatus, SpConnectionStatus.ok);
    });

    test('setNetwork to signet pre-fills default URLs', () async {
      await cubit.setNetwork(BitcoinNetwork.signet);

      expect(cubit.state.network, BitcoinNetwork.signet);
      expect(
        cubit.state.blindbitUrl,
        SpConfig.staticDefaults(BitcoinNetwork.signet)!.blindbitUrl,
      );
      expect(
        cubit.state.electrumUrl,
        SpConfig.staticDefaults(BitcoinNetwork.signet)!.electrumUrl,
      );
    });

    test('setNetwork to testnet pre-fills default URLs', () async {
      await cubit.setNetwork(BitcoinNetwork.testnet);

      expect(cubit.state.network, BitcoinNetwork.testnet);
      expect(
        cubit.state.blindbitUrl,
        SpConfig.staticDefaults(BitcoinNetwork.testnet)!.blindbitUrl,
      );
      expect(
        cubit.state.electrumUrl,
        SpConfig.staticDefaults(BitcoinNetwork.testnet)!.electrumUrl,
      );
    });

    test(
      'setNetwork to regtest pre-fills the injected regtest defaults',
      () async {
        await cubit.setNetwork(BitcoinNetwork.mainnet);
        expect(cubit.state.blindbitUrl, isNotEmpty);

        await cubit.setNetwork(BitcoinNetwork.regtest);
        expect(cubit.state.network, BitcoinNetwork.regtest);
        expect(cubit.state.blindbitUrl, 'http://127.0.0.1:8000');
        expect(cubit.state.electrumUrl, 'tcp://127.0.0.1:50001');
      },
    );

    test('setBlindbitUrl updates state', () {
      cubit.setBlindbitUrl('http://blindbit.local');
      expect(cubit.state.blindbitUrl, 'http://blindbit.local');
      expect(cubit.state.error, isNull);
    });

    test('setElectrumUrl updates state', () {
      cubit.setElectrumUrl('tcp://electrum.local:60001');
      expect(cubit.state.electrumUrl, 'tcp://electrum.local:60001');
      expect(cubit.state.error, isNull);
    });

    test('setNetwork clears prior error', () async {
      when(
        () => mockCreate.execute(
          network: any(named: 'network'),
          walletId: any(named: 'walletId'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          scanFromNow: any(named: 'scanFromNow'),
        ),
      ).thenAnswer(
        (_) async => const Err<void, SpFailure>(SpUnexpected('boom')),
      );

      cubit.setBlindbitUrl('http://blindbit.local');
      cubit.setElectrumUrl('tcp://electrum.local:60001');
      await cubit.testBlindbit();
      await cubit.testElectrum();
      await cubit.create('wallet');
      expect(cubit.state.error, isNotNull);

      await cubit.setNetwork(BitcoinNetwork.mainnet);
      expect(cubit.state.error, isNull);
    });

    test('create() success: calls usecase, sets created', () async {
      cubit.setBlindbitUrl('http://blindbit.local');
      cubit.setElectrumUrl('tcp://electrum.local:60001');

      await cubit.testBlindbit();
      await cubit.testElectrum();
      await cubit.create('wallet');

      verify(
        () => mockCreate.execute(
          network: BitcoinNetwork.mainnet,
          walletId: 'wallet',
          blindbitUrl: 'http://blindbit.local',
          electrumUrl: 'tcp://electrum.local:60001',
          scanFromNow: true,
        ),
      ).called(1);
      expect(cubit.state.created, isTrue);
      expect(cubit.state.error, isNull);
      expect(cubit.state.isCreating, isFalse);
    });

    test(
      'create() surfaces a failure from the usecase (BytesSeed path)',
      () async {
        when(
          () => mockCreate.execute(
            network: any(named: 'network'),
            walletId: any(named: 'walletId'),
            blindbitUrl: any(named: 'blindbitUrl'),
            electrumUrl: any(named: 'electrumUrl'),
            scanFromNow: any(named: 'scanFromNow'),
          ),
        ).thenAnswer(
          (_) async => const Err<void, SpFailure>(
            SpUnexpected(
              'SP setup requires a mnemonic-backed seed; got BytesSeed',
            ),
          ),
        );

        cubit.setBlindbitUrl('http://blindbit.local');
        cubit.setElectrumUrl('tcp://electrum.local:60001');

        await cubit.testBlindbit();
        await cubit.testElectrum();
        await cubit.create('wallet');

        expect(cubit.state.error, isA<SpUnexpected>());
        expect(
          (cubit.state.error! as SpUnexpected).logMessage,
          contains('mnemonic-backed seed'),
        );
        expect(cubit.state.created, isFalse);
        expect(cubit.state.isCreating, isFalse);
      },
    );

    test('create() failure: sets error, leaves created false', () async {
      when(
        () => mockCreate.execute(
          network: any(named: 'network'),
          walletId: any(named: 'walletId'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          scanFromNow: any(named: 'scanFromNow'),
        ),
      ).thenAnswer(
        (_) async =>
            const Err<void, SpFailure>(SpSetupCleanupFailed('cleanup failed')),
      );

      cubit.setBlindbitUrl('http://blindbit.local');
      cubit.setElectrumUrl('tcp://electrum.local:60001');

      await cubit.testBlindbit();
      await cubit.testElectrum();
      await cubit.create('wallet');

      verify(
        () => mockCreate.execute(
          network: any(named: 'network'),
          walletId: any(named: 'walletId'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          scanFromNow: any(named: 'scanFromNow'),
        ),
      ).called(1);
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.created, isFalse);
      expect(cubit.state.isCreating, isFalse);
    });

    test(
      'a failed blindbit connection test stores the error and blocks create',
      () async {
        final c = buildSetup(
          testBlindbit: ({required String url}) async =>
              throw Exception('blindbit down'),
        );
        addTearDown(c.close);
        // Wait for the async regtest-defaults init to land before simulating user
        // input; otherwise the late applyDefaults resets the URLs and conn tests.
        await c.stream.firstWhere((s) => !s.isFetchingDefaults);
        c.setBlindbitUrl('http://blindbit.local');
        c.setElectrumUrl('tcp://electrum.local:60001');

        await c.testBlindbit();
        await c.testElectrum();

        expect(c.state.blindbitStatus, SpConnectionStatus.failed);
        expect(c.state.blindbitStatusError, isA<SpBackendUnreachable>());
        expect(c.state.electrumStatus, SpConnectionStatus.ok);
        expect(c.state.canCreate, isFalse);

        await c.create('wallet');

        verifyNever(
          () => mockCreate.execute(
            network: any(named: 'network'),
            walletId: any(named: 'walletId'),
            blindbitUrl: any(named: 'blindbitUrl'),
            electrumUrl: any(named: 'electrumUrl'),
            scanFromNow: any(named: 'scanFromNow'),
          ),
        );
      },
    );

    test(
      'a failed electrum connection test stores the error and blocks create',
      () async {
        final c = buildSetup(
          testElectrum: ({required String url}) async =>
              throw Exception('electrum down'),
        );
        addTearDown(c.close);
        // Wait for the async regtest-defaults init to land before simulating user
        // input; otherwise the late applyDefaults resets the URLs and conn tests.
        await c.stream.firstWhere((s) => !s.isFetchingDefaults);
        c.setBlindbitUrl('http://blindbit.local');
        c.setElectrumUrl('tcp://electrum.local:60001');

        await c.testBlindbit();
        await c.testElectrum();

        expect(c.state.electrumStatus, SpConnectionStatus.failed);
        expect(c.state.electrumStatusError, isA<SpBackendUnreachable>());
        expect(c.state.blindbitStatus, SpConnectionStatus.ok);
        expect(c.state.canCreate, isFalse);

        await c.create('wallet');

        verifyNever(
          () => mockCreate.execute(
            network: any(named: 'network'),
            walletId: any(named: 'walletId'),
            blindbitUrl: any(named: 'blindbitUrl'),
            electrumUrl: any(named: 'electrumUrl'),
            scanFromNow: any(named: 'scanFromNow'),
          ),
        );
      },
    );

    test(
      'create() with untested URLs never invokes the create usecase',
      () async {
        cubit.setBlindbitUrl('http://blindbit.local');
        cubit.setElectrumUrl('tcp://electrum.local:60001');
        // No testBlindbit()/testElectrum(): the conn tests stay untested.
        expect(cubit.state.canCreate, isFalse);

        await cubit.create('wallet');

        verifyNever(
          () => mockCreate.execute(
            network: any(named: 'network'),
            walletId: any(named: 'walletId'),
            blindbitUrl: any(named: 'blindbitUrl'),
            electrumUrl: any(named: 'electrumUrl'),
            scanFromNow: any(named: 'scanFromNow'),
          ),
        );
        expect(cubit.state.created, isFalse);
      },
    );

    test(
      'fetchRegtestDefaults failure sets error and clears the fetching flag',
      () async {
        final c = buildSetup(
          regtest: const Err<SpBackendDefaults, SpFailure>(
            SpBackendUnreachable('regtest infra unreachable'),
          ),
        );
        addTearDown(c.close);

        await c.fetchRegtestDefaults();

        expect(c.state.error, isA<SpBackendUnreachable>());
        expect(c.state.isFetchingDefaults, isFalse);
      },
    );

    test(
      'a late defaults fetch keeps a url the user edited during the wait',
      () async {
        final gate = Completer<void>();
        final c = buildSetup(regtestGate: gate.future);
        addTearDown(c.close);
        await waitForDefaultTests(c);

        final networkSwitch = c.setNetwork(BitcoinNetwork.regtest);
        // The regtest fetch is blocked on the gate, so the form is still fetching
        // with empty URLs.
        expect(c.state.isFetchingDefaults, isTrue);

        // User types a blindbit URL while the fetch is in flight; electrum is left
        // untouched.
        c.setBlindbitUrl('http://user.typed.blindbit');

        // The slow fetch resolves only now.
        gate.complete();
        await networkSwitch;

        // The typed URL survives; the untouched electrum takes the fetched default.
        expect(c.state.blindbitUrl, 'http://user.typed.blindbit');
        expect(c.state.electrumUrl, 'tcp://127.0.0.1:50001');
      },
    );

    test('defaults to starting from now', () {
      expect(cubit.state.scanStart, SpScanStart.fromNow);
    });

    test('setScanStart switches the choice', () {
      cubit.setScanStart(SpScanStart.earlierBlock);
      expect(cubit.state.scanStart, SpScanStart.earlierBlock);

      cubit.setScanStart(SpScanStart.fromNow);
      expect(cubit.state.scanStart, SpScanStart.fromNow);
    });

    test('create() seeds the cursor when starting from now', () async {
      await cubit.testBlindbit();
      await cubit.testElectrum();
      await cubit.create('wallet');

      verify(
        () => mockCreate.execute(
          network: any(named: 'network'),
          walletId: any(named: 'walletId'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          scanFromNow: true,
        ),
      ).called(1);
    });

    test('create() does not seed the cursor for an import', () async {
      cubit.setScanStart(SpScanStart.earlierBlock);
      await cubit.testBlindbit();
      await cubit.testElectrum();
      await cubit.create('wallet');

      verify(
        () => mockCreate.execute(
          network: any(named: 'network'),
          walletId: any(named: 'walletId'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          scanFromNow: false,
        ),
      ).called(1);
    });
  });
}
