import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart' show Secret;

import '../../sp_fakes.dart';

class _MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

void main() {
  late MockSpAccountRepository repository;
  late _MockSpBackendConfigRepository configRepository;
  late MockGetSpSecretUsecase getSpSecretUsecase;
  late Secret secret;
  late EnsureSpSessionUsecase usecase;

  setUpAll(() async {
    registerFallbackValue(BitcoinNetwork.regtest);
    registerFallbackValue(await spSecret());
  });

  setUp(() async {
    secret = await spSecret();
    repository = MockSpAccountRepository();
    configRepository = _MockSpBackendConfigRepository();
    getSpSecretUsecase = MockGetSpSecretUsecase();
    usecase = EnsureSpSessionUsecase(
      repository: repository,
      files: repository,
      configRepository: configRepository,
      getSpSecretUsecase: getSpSecretUsecase,
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
      () => getSpSecretUsecase.execute(any()),
    ).thenAnswer((_) async => Ok(secret));
    when(
      () => repository.createFromSecret(
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
        secret: any(named: 'secret'),
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
        () => repository.createFromSecret(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          secret: any(named: 'secret'),
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
      verifyNever(() => getSpSecretUsecase.execute(any()));
    });

    test('a secret read throw returns Err with no exception detail', () async {
      when(
        () => getSpSecretUsecase.execute(any()),
      ).thenThrow(Exception('keystore locked'));

      final result = await usecase.execute();

      final failure = (result as Err).failure;
      expect(failure, isA<SpUnexpected>());
      expect(
        failure.logMessage,
        'SP session establish failed',
        reason:
            'the block reads the secret, so nothing caught may be '
            'written to the exportable log',
      );
    });

    test('forwards a passphrase refusal and never creates', () async {
      when(
        () => getSpSecretUsecase.execute(any()),
      ).thenAnswer((_) async => const Err(SpPassphraseUnsupported()));

      final result = await usecase.execute();

      expect((result as Err).failure, isA<SpPassphraseUnsupported>());
      verifyNever(
        () => repository.createFromSecret(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          secret: any(named: 'secret'),
        ),
      );
    });

    test('reconstructs via createFromSecret from the stored config', () async {
      final result = await usecase.execute();

      expect((result as Ok<SpWallet?, SpFailure>).value, isNotNull);
      verify(
        () => repository.createFromSecret(
          network: BitcoinNetwork.regtest,
          blindbitUrl: 'http://blindbit.example',
          electrumUrl: 'tcp://electrum.example:50001',
          secret: secret,
        ),
      ).called(1);
    });

    test('returns null while a teardown is in progress (no create)', () async {
      when(() => repository.teardownInProgress).thenReturn(true);

      final result = await usecase.execute();

      expect((result as Ok<SpWallet?, SpFailure>).value, isNull);
      verifyNever(() => configRepository.fetch());
      verifyNever(
        () => repository.createFromSecret(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          secret: any(named: 'secret'),
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
          () => repository.createFromSecret(
            network: any(named: 'network'),
            blindbitUrl: any(named: 'blindbitUrl'),
            electrumUrl: any(named: 'electrumUrl'),
            secret: any(named: 'secret'),
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
      when(() => getSpSecretUsecase.execute(any())).thenAnswer((_) async {
        tearingDown = true;
        return Ok(secret);
      });

      final result = await usecase.execute();

      expect((result as Ok<SpWallet?, SpFailure>).value, isNull);
      verifyNever(
        () => repository.createFromSecret(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          secret: any(named: 'secret'),
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
      'serializes concurrent establishment into one createFromSecret',
      () async {
        final results = await Future.wait([
          usecase.execute(),
          usecase.execute(),
        ]);

        expect((results[0] as Ok<SpWallet?, SpFailure>).value, isNotNull);
        expect((results[1] as Ok<SpWallet?, SpFailure>).value, isNotNull);
        verify(
          () => repository.createFromSecret(
            network: any(named: 'network'),
            blindbitUrl: any(named: 'blindbitUrl'),
            electrumUrl: any(named: 'electrumUrl'),
            secret: any(named: 'secret'),
          ),
        ).called(1);
      },
    );
  });
}
