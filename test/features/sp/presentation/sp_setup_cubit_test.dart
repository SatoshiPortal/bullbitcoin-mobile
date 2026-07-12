import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/create_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_conn_test.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCreateSpWalletUsecase extends Mock implements CreateSpWalletUsecase {}

/// Stubs the regtest-defaults + backend-test paths the setup cubit exercises;
/// the static networks come from [SpConfig] inside the real usecase.
class _FakeBackendConfigRepo implements SpBackendConfigRepository {
  _FakeBackendConfigRepo(
    this._regtest, {
    Future<int> Function({required String url})? testBlindbit,
    Future<void> Function({required String url})? testElectrum,
    Future<void>? regtestGate,
  }) : _testBlindbit = testBlindbit ?? (({required String url}) async => 0),
       _testElectrum = testElectrum ?? (({required String url}) async {}),
       _regtestGate = regtestGate ?? Future<void>.value();

  final Result<SpBackendDefaults, SpFailure> _regtest;
  final Future<int> Function({required String url}) _testBlindbit;
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
    registerFallbackValue(SpNetwork.regtest);
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
    Future<int> Function({required String url})? testBlindbit,
    Future<void> Function({required String url})? testElectrum,
    Result<SpBackendDefaults, SpFailure>? regtest,
    Future<void>? regtestGate,
  }) {
    final configRepo = _FakeBackendConfigRepo(
      regtest ?? regtestDefaults,
      testBlindbit: testBlindbit,
      testElectrum: testElectrum,
      regtestGate: regtestGate,
    );
    return SpSetupCubit(
      createSpWalletUsecase: mockCreate,
      testSpBackendUsecase: TestSpBackendUsecase(configRepository: configRepo),
      getSpBackendDefaultsUsecase: GetSpBackendDefaultsUsecase(
        configRepository: configRepo,
      ),
    );
  }

  setUp(() async {
    mockCreate = MockCreateSpWalletUsecase();

    when(
      () => mockCreate.execute(
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
      ),
    ).thenAnswer((_) async => const Ok<void, SpFailure>(null));

    cubit = buildSetup();
    // The cubit fetches regtest defaults asynchronously after construction;
    // wait for that to land so tests start from the resolved defaults.
    await cubit.stream.firstWhere((s) => !s.isFetchingDefaults);
  });

  tearDown(() => cubit.close());

  group('SpSetupCubit', () {
    test('initial state is default', () {
      expect(cubit.state.network, SpNetwork.regtest);
      expect(cubit.state.blindbitUrl, isNotEmpty);
      expect(cubit.state.electrumUrl, isNotEmpty);
      expect(cubit.state.isCreating, isFalse);
      expect(cubit.state.created, isFalse);
      expect(cubit.state.error, isNull);
    });

    test('setNetwork to bitcoin pre-fills default URLs', () async {
      await cubit.setNetwork(SpNetwork.bitcoin);

      expect(cubit.state.network, SpNetwork.bitcoin);
      expect(
        cubit.state.blindbitUrl,
        SpConfig.defaultBlindbitUrl[SpNetwork.bitcoin],
      );
      expect(
        cubit.state.electrumUrl,
        SpConfig.defaultElectrumUrl[SpNetwork.bitcoin],
      );
      expect(cubit.state.blindbitUrl, isNotEmpty);
      expect(cubit.state.electrumUrl, isNotEmpty);
    });

    test('setNetwork to signet pre-fills default URLs', () async {
      await cubit.setNetwork(SpNetwork.signet);

      expect(cubit.state.network, SpNetwork.signet);
      expect(
        cubit.state.blindbitUrl,
        SpConfig.defaultBlindbitUrl[SpNetwork.signet],
      );
      expect(
        cubit.state.electrumUrl,
        SpConfig.defaultElectrumUrl[SpNetwork.signet],
      );
    });

    test('setNetwork to testnet pre-fills default URLs', () async {
      await cubit.setNetwork(SpNetwork.testnet);

      expect(cubit.state.network, SpNetwork.testnet);
      expect(
        cubit.state.blindbitUrl,
        SpConfig.defaultBlindbitUrl[SpNetwork.testnet],
      );
      expect(
        cubit.state.electrumUrl,
        SpConfig.defaultElectrumUrl[SpNetwork.testnet],
      );
    });

    test('setNetwork to regtest pre-fills the injected regtest defaults',
        () async {
      await cubit.setNetwork(SpNetwork.bitcoin);
      expect(cubit.state.blindbitUrl, isNotEmpty);

      await cubit.setNetwork(SpNetwork.regtest);
      expect(cubit.state.network, SpNetwork.regtest);
      expect(cubit.state.blindbitUrl, 'http://127.0.0.1:8000');
      expect(cubit.state.electrumUrl, 'tcp://127.0.0.1:50001');
    });

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
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
        ),
      ).thenAnswer(
        (_) async => const Err<void, SpFailure>(SpUnexpected('boom')),
      );

      cubit.setBlindbitUrl('http://blindbit.local');
      cubit.setElectrumUrl('tcp://electrum.local:60001');
      await cubit.testBlindbit();
      await cubit.testElectrum();
      await cubit.create();
      expect(cubit.state.error, isNotNull);

      await cubit.setNetwork(SpNetwork.bitcoin);
      expect(cubit.state.error, isNull);
    });

    test('create() success: calls usecase, sets created', () async {
      cubit.setBlindbitUrl('http://blindbit.local');
      cubit.setElectrumUrl('tcp://electrum.local:60001');

      await cubit.testBlindbit();
      await cubit.testElectrum();
      await cubit.create();

      verify(
        () => mockCreate.execute(
          network: SpNetwork.regtest,
          blindbitUrl: 'http://blindbit.local',
          electrumUrl: 'tcp://electrum.local:60001',
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
            blindbitUrl: any(named: 'blindbitUrl'),
            electrumUrl: any(named: 'electrumUrl'),
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
        await cubit.create();

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
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
        ),
      ).thenAnswer(
        (_) async =>
            const Err<void, SpFailure>(SpSetupCleanupFailed('cleanup failed')),
      );

      cubit.setBlindbitUrl('http://blindbit.local');
      cubit.setElectrumUrl('tcp://electrum.local:60001');

      await cubit.testBlindbit();
      await cubit.testElectrum();
      await cubit.create();

      verify(
        () => mockCreate.execute(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
        ),
      ).called(1);
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.created, isFalse);
      expect(cubit.state.isCreating, isFalse);
    });

    test('a failed blindbit connection test stores the error and blocks create',
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

      expect(c.state.blindbitTest, SpConnTest.failed);
      expect(c.state.blindbitTestError, isA<SpBackendUnreachable>());
      expect(c.state.electrumTest, SpConnTest.ok);
      expect(c.state.canCreate, isFalse);

      await c.create();

      verifyNever(
        () => mockCreate.execute(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
        ),
      );
    });

    test('a failed electrum connection test stores the error and blocks create',
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

      expect(c.state.electrumTest, SpConnTest.failed);
      expect(c.state.electrumTestError, isA<SpBackendUnreachable>());
      expect(c.state.blindbitTest, SpConnTest.ok);
      expect(c.state.canCreate, isFalse);

      await c.create();

      verifyNever(
        () => mockCreate.execute(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
        ),
      );
    });

    test('create() with untested URLs never invokes the create usecase',
        () async {
      cubit.setBlindbitUrl('http://blindbit.local');
      cubit.setElectrumUrl('tcp://electrum.local:60001');
      // No testBlindbit()/testElectrum(): the conn tests stay untested.
      expect(cubit.state.canCreate, isFalse);

      await cubit.create();

      verifyNever(
        () => mockCreate.execute(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
        ),
      );
      expect(cubit.state.created, isFalse);
    });

    test('fetchRegtestDefaults failure sets error and clears the fetching flag',
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
    });

    test('a late defaults fetch keeps a url the user edited during the wait',
        () async {
      final gate = Completer<void>();
      final c = buildSetup(regtestGate: gate.future);
      addTearDown(c.close);
      // The constructor kicked off the regtest fetch; it is blocked on the gate,
      // so the form is still fetching with empty URLs.
      expect(c.state.isFetchingDefaults, isTrue);

      // User types a blindbit URL while the fetch is in flight; electrum is left
      // untouched.
      c.setBlindbitUrl('http://user.typed.blindbit');

      // The slow fetch resolves only now.
      gate.complete();
      await c.stream.firstWhere((s) => !s.isFetchingDefaults);

      // The typed URL survives; the untouched electrum takes the fetched default.
      expect(c.state.blindbitUrl, 'http://user.typed.blindbit');
      expect(c.state.electrumUrl, 'tcp://127.0.0.1:50001');
    });
  });
}
