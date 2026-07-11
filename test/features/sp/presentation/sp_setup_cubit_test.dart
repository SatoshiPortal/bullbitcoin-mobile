import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/create_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCreateSpWalletUsecase extends Mock implements CreateSpWalletUsecase {}

/// Stubs only the regtest-defaults path the setup cubit exercises; the static
/// networks come from [SpConfig] inside the real usecase.
class _FakeBackendConfigRepo implements SpBackendConfigRepository {
  _FakeBackendConfigRepo(this._regtest);

  final SpBackendDefaults _regtest;

  @override
  SpBackendDefaults fetchRegtestDefaults() => _regtest;

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

  const regtestDefaults = SpBackendDefaults.ok(
    blindbitUrl: 'http://127.0.0.1:8000',
    electrumUrl: 'tcp://127.0.0.1:50001',
  );

  SpSetupCubit buildSetup({
    Future<int> Function({required String url})? testBlindbit,
    Future<void> Function({required String url})? testElectrum,
    SpBackendDefaults? regtest,
  }) => SpSetupCubit(
    createSpWalletUsecase: mockCreate,
    testSpBackendUsecase: TestSpBackendUsecase(
      testBlindbit: testBlindbit ?? (({required String url}) async => 0),
      testElectrum: testElectrum ?? (({required String url}) async {}),
    ),
    getSpBackendDefaultsUsecase: GetSpBackendDefaultsUsecase(
      configRepository: _FakeBackendConfigRepo(regtest ?? regtestDefaults),
    ),
  );

  setUp(() {
    mockCreate = MockCreateSpWalletUsecase();

    when(
      () => mockCreate.execute(
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
      ),
    ).thenAnswer((_) async => const Ok<void, SpFailure>(null));

    cubit = buildSetup();
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
        regtest: SpBackendDefaults.failed(
          const SpBackendUnreachable('regtest infra unreachable'),
        ),
      );
      addTearDown(c.close);

      await c.fetchRegtestDefaults();

      expect(c.state.error, isA<SpBackendUnreachable>());
      expect(c.state.isFetchingDefaults, isFalse);
    });
  });
}
