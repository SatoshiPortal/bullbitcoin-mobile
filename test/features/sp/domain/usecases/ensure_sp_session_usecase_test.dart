import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_fakes.dart';

class _MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

BytesSeed _bytesSeed() => BytesSeed(
  bytes: Uint8List.fromList(List.filled(64, 1)),
  masterFingerprint: 'f23f9fd2',
);

void main() {
  late MockSpAccountRepository repository;
  late _MockSpBackendConfigRepository configRepository;
  late MockGetDefaultSeedUsecase getDefaultSeedUsecase;
  late EnsureSpSessionUsecase usecase;

  setUpAll(() {
    registerFallbackValue(SpNetwork.regtest);
  });

  setUp(() {
    repository = MockSpAccountRepository();
    configRepository = _MockSpBackendConfigRepository();
    getDefaultSeedUsecase = MockGetDefaultSeedUsecase();
    usecase = EnsureSpSessionUsecase(
      repository: repository,
      configRepository: configRepository,
      getDefaultSeedUsecase: getDefaultSeedUsecase,
    );

    when(() => repository.hasSession).thenReturn(false);
    when(() => repository.teardownInProgress).thenReturn(false);
    when(() => repository.hasRevokedSentinel()).thenAnswer((_) async => false);
    when(() => repository.dispose()).thenAnswer((_) async {});
    when(() => repository.snapshot()).thenReturn(spWallet());
    when(() => configRepository.fetch()).thenAnswer(
      (_) async => Ok<SpBackendConfig?, SpFailure>(spBackendConfig()),
    );
    when(
      () => getDefaultSeedUsecase.execute(),
    ).thenAnswer((_) async => spMnemonicSeed());
    when(
      () => repository.createFromMnemonic(
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
        mnemonic: any(named: 'mnemonic'),
      ),
    ).thenAnswer((_) async {});
  });

  group('EnsureSpSessionUsecase', () {
    test('reuses the live session without reconstructing', () async {
      when(() => repository.hasSession).thenReturn(true);

      final result = await usecase.execute();

      expect(result, isNotNull);
      verify(() => repository.snapshot()).called(1);
      verifyNever(
        () => repository.createFromMnemonic(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          mnemonic: any(named: 'mnemonic'),
        ),
      );
    });

    test('returns null when a .revoked sentinel is present', () async {
      when(() => repository.hasRevokedSentinel()).thenAnswer((_) async => true);

      final result = await usecase.execute();

      expect(result, isNull);
      verifyNever(() => configRepository.fetch());
    });

    test('returns null when no backend config is stored', () async {
      when(
        () => configRepository.fetch(),
      ).thenAnswer((_) async => const Ok<SpBackendConfig?, SpFailure>(null));

      final result = await usecase.execute();

      expect(result, isNull);
      verifyNever(() => getDefaultSeedUsecase.execute());
    });

    test('throws when the default seed is not mnemonic-backed', () async {
      when(
        () => getDefaultSeedUsecase.execute(),
      ).thenAnswer((_) async => _bytesSeed());

      await expectLater(usecase.execute(), throwsA(isA<StateError>()));
    });

    test(
      'reconstructs via createFromMnemonic from the stored config',
      () async {
        final result = await usecase.execute();

        expect(result, isNotNull);
        verify(
          () => repository.createFromMnemonic(
            network: SpNetwork.regtest,
            blindbitUrl: 'http://blindbit.example',
            electrumUrl: 'tcp://electrum.example:50001',
            mnemonic:
                'abandon abandon abandon abandon abandon abandon abandon '
                'abandon abandon abandon abandon abandon',
          ),
        ).called(1);
      },
    );

    test('returns null while a teardown is in progress (no create)', () async {
      when(() => repository.teardownInProgress).thenReturn(true);

      final result = await usecase.execute();

      expect(result, isNull);
      verifyNever(() => configRepository.fetch());
      verifyNever(
        () => repository.createFromMnemonic(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          mnemonic: any(named: 'mnemonic'),
        ),
      );
    });

    test('a teardown that begins after the entry checks but before create '
        'aborts the create (TOCTOU)', () async {
      // teardownInProgress is false through the entry/establish checks; a
      // revoke/recreate flips it while the seed read is in flight, so the
      // re-check right before create must abort instead of racing a live
      // session.
      var tearingDown = false;
      when(() => repository.teardownInProgress).thenAnswer((_) => tearingDown);
      when(() => getDefaultSeedUsecase.execute()).thenAnswer((_) async {
        tearingDown = true;
        return spMnemonicSeed();
      });

      final result = await usecase.execute();

      expect(result, isNull);
      verifyNever(
        () => repository.createFromMnemonic(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          mnemonic: any(named: 'mnemonic'),
        ),
      );
    });

    test('disposes a live session and returns null when the sentinel appeared '
        'after the session was established (T1.3 zombie)', () async {
      // A revoke wrote the sentinel while a session was still live; ensure must
      // not keep serving it.
      when(() => repository.hasSession).thenReturn(true);
      when(() => repository.hasRevokedSentinel()).thenAnswer((_) async => true);

      final result = await usecase.execute();

      expect(result, isNull);
      verify(() => repository.dispose()).called(1);
      verifyNever(() => repository.snapshot());
    });

    test(
      'serializes concurrent establishment into one createFromMnemonic',
      () async {
        final results = await Future.wait([
          usecase.execute(),
          usecase.execute(),
        ]);

        expect(results[0], isNotNull);
        expect(results[1], isNotNull);
        verify(
          () => repository.createFromMnemonic(
            network: any(named: 'network'),
            blindbitUrl: any(named: 'blindbitUrl'),
            electrumUrl: any(named: 'electrumUrl'),
            mnemonic: any(named: 'mnemonic'),
          ),
        ).called(1);
      },
    );
  });
}
