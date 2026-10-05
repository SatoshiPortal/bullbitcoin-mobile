import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:primitives/primitives.dart';
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
    registerFallbackValue(BitcoinNetwork.regtest);
  });

  setUp(() {
    repository = MockSpAccountRepository();
    configRepository = _MockSpBackendConfigRepository();
    getDefaultSeedUsecase = MockGetDefaultSeedUsecase();
    usecase = EnsureSpSessionUsecase(
      repository: repository,
      files: repository,
      configRepository: configRepository,
      getDefaultSeedUsecase: getDefaultSeedUsecase,
    );

    when(() => repository.hasSession).thenReturn(false);
    when(() => repository.teardownInProgress).thenReturn(false);
    when(
      () => repository.adoptNewestBackup(),
    ).thenAnswer((_) async => const Ok(false));
    when(
      () => repository.hasRevokedSentinel(),
    ).thenAnswer((_) async => const Ok(false));
    when(() => repository.dispose()).thenAnswer((_) async => const Ok(null));
    when(() => repository.snapshot()).thenReturn(Ok(spWallet()));
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
    ).thenAnswer((_) async => const Ok(null));
  });

  group('EnsureSpSessionUsecase', () {
    test('reuses the live session without reconstructing', () async {
      when(() => repository.hasSession).thenReturn(true);

      final result = await usecase.execute();

      expect((result as Ok<SpWallet?, SpFailure>).value, isNotNull);
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
      when(
        () => repository.hasRevokedSentinel(),
      ).thenAnswer((_) async => const Ok(true));

      final result = await usecase.execute();

      expect((result as Ok<SpWallet?, SpFailure>).value, isNull);
      verifyNever(() => configRepository.fetch());
    });

    test('returns null when no backend config is stored', () async {
      when(
        () => configRepository.fetch(),
      ).thenAnswer((_) async => const Ok<SpBackendConfig?, SpFailure>(null));

      final result = await usecase.execute();

      expect((result as Ok<SpWallet?, SpFailure>).value, isNull);
      verifyNever(() => getDefaultSeedUsecase.execute());
    });

    test('a seed read throw returns Err with no exception detail', () async {
      when(
        () => getDefaultSeedUsecase.execute(),
      ).thenThrow(Exception('keystore locked'));

      final result = await usecase.execute();

      final failure = (result as Err).failure;
      expect(failure, isA<SpUnexpected>());
      expect(
        failure.logMessage,
        'SP session establish failed',
        reason:
            'the block derives the mnemonic, so nothing caught may be '
            'written to the exportable log',
      );
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

        expect((result as Ok<SpWallet?, SpFailure>).value, isNotNull);
        verify(
          () => repository.createFromMnemonic(
            network: BitcoinNetwork.regtest,
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

      expect((result as Ok<SpWallet?, SpFailure>).value, isNull);
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

    test(
      'allowDuringTeardown establishes while the teardown is still held',
      () async {
        // The one caller that owns the teardown it runs inside: a failed recreate
        // rolling back has to bring the previous session back before releasing.
        when(() => repository.teardownInProgress).thenReturn(true);

        final result = await usecase.execute(allowDuringTeardown: true);

        expect((result as Ok<SpWallet?, SpFailure>).value, isNotNull);
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

      expect((result as Ok<SpWallet?, SpFailure>).value, isNull);
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
        'after the session was established (a zombie session)', () async {
      // A revoke wrote the sentinel while a session was still live; ensure must
      // not keep serving it.
      when(() => repository.hasSession).thenReturn(true);
      when(
        () => repository.hasRevokedSentinel(),
      ).thenAnswer((_) async => const Ok(true));

      final result = await usecase.execute();

      expect((result as Ok<SpWallet?, SpFailure>).value, isNull);
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

        expect((results[0] as Ok<SpWallet?, SpFailure>).value, isNotNull);
        expect((results[1] as Ok<SpWallet?, SpFailure>).value, isNotNull);
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
