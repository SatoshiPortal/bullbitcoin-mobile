import 'package:mempool/src/domain/usecases/load_mempool_server_data_usecase.dart';
import 'package:mempool/src/domain/usecases/set_custom_mempool_server_usecase.dart';
import 'package:mempool/src/domain/entities/mempool_server.dart';
import 'package:mempool/src/domain/mempool_failure.dart';
import 'package:mempool/src/domain/ports/mempool_server_validator_port.dart';
import 'package:mempool/src/domain/repositories/mempool_server_repository.dart';
import 'package:mempool/src/domain/value_objects/mempool_server_network.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockServerRepository extends Mock implements MempoolServerRepository {}

class _MockValidator extends Mock implements MempoolServerValidatorPort {}

void main() {
  setUpAll(() {
    registerFallbackValue(MempoolServerNetwork.bitcoinMainnet);
    registerFallbackValue(
      MempoolServer.existing(
        url: 'mempool.example.com',
        network: BitcoinNetwork.mainnet,
        isCustom: true,
      ),
    );
  });

  test('rejects a malformed custom URL before creating a server', () {
    final result = MempoolServer.tryCreateCustom(
      url: 'no-dot-host',
      network: BitcoinNetwork.mainnet,
    );
    expect(
      result,
      isA<Err<MempoolServer, MempoolFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<MempoolInvalidUrlFailure>(),
      ),
    );
  });

  group('SetCustomMempoolServerUsecase', () {
    late _MockServerRepository repo;
    late _MockValidator validator;
    late SetCustomMempoolServerUsecase usecase;

    final custom = MempoolServer.tryCreateCustom(
      url: 'mempool.example.com',
      network: BitcoinNetwork.mainnet,
    ).fold((server) => server, (_) => throw StateError('Invalid test server'));
    const network = MempoolServerNetwork.bitcoinMainnet;

    setUp(() {
      repo = _MockServerRepository();
      validator = _MockValidator();
      usecase = SetCustomMempoolServerUsecase(
        serverRepository: repo,
        validator: validator,
      );
      // Default fetch fails → use-case folds it to null → comparison skipped.
      when(() => repo.fetchDefaultServer(any())).thenAnswer(
        (_) async =>
            const Err(MempoolLoadFailure(MempoolServerKind.defaultServer)),
      );
    });

    test('propagates the validation failure as a typed variant', () async {
      when(
        () => validator.validateServer(
          url: any(named: 'url'),
          network: any(named: 'network'),
          enableSsl: any(named: 'enableSsl'),
        ),
      ).thenAnswer((_) async => const Err(MempoolValidationTimeoutFailure()));

      final result = await usecase.execute(custom, network: network);

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<MempoolValidationTimeoutFailure>());
      verifyNever(() => repo.save(any()));
    });

    test('propagates the save failure when persisting fails', () async {
      when(
        () => validator.validateServer(
          url: any(named: 'url'),
          network: any(named: 'network'),
          enableSsl: any(named: 'enableSsl'),
        ),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => repo.save(any()),
      ).thenAnswer((_) async => const Err(MempoolSaveFailure('raw db error')));

      final result = await usecase.execute(custom, network: network);

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<MempoolSaveFailure>());
    });

    test(
      'returns SameAsDefault failure when custom URL matches the default',
      () async {
        when(() => repo.fetchDefaultServer(any())).thenAnswer(
          (_) async => Ok(
            MempoolServer.existing(
              url: 'mempool.example.com',
              network: BitcoinNetwork.mainnet,
              isCustom: false,
            ),
          ),
        );

        final result = await usecase.execute(custom, network: network);

        expect(result, isA<Err>());
        expect(
          (result as Err).failure,
          isA<MempoolServerSameAsDefaultFailure>(),
        );
        verifyNever(() => repo.save(any()));
      },
    );
  });

  group('LoadMempoolServerDataUsecase', () {
    late _MockServerRepository repo;
    late LoadMempoolServerDataUsecase usecase;

    final defaultServer = MempoolServer.existing(
      url: 'mempool.space',
      network: BitcoinNetwork.mainnet,
      isCustom: false,
    );

    setUp(() {
      repo = _MockServerRepository();
      usecase = LoadMempoolServerDataUsecase(serverRepository: repo);
    });

    test('propagates the failure when fetchDefaultServer fails', () async {
      when(() => repo.fetchDefaultServer(any())).thenAnswer(
        (_) async => const Err(
          MempoolLoadFailure(MempoolServerKind.defaultServer, 'raw db error'),
        ),
      );
      when(() => repo.fetchCustomServer(any()))
          .thenAnswer((_) async => const Ok(null));

      final result = await usecase.execute(MempoolServerNetwork.bitcoinMainnet);

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<MempoolLoadFailure>());
    });

    test('propagates the failure when fetchCustomServer fails', () async {
      when(() => repo.fetchDefaultServer(any()))
          .thenAnswer((_) async => Ok(defaultServer));
      when(() => repo.fetchCustomServer(any())).thenAnswer(
        (_) async => const Err(
          MempoolLoadFailure(MempoolServerKind.custom, 'custom server error'),
        ),
      );

      final result = await usecase.execute(MempoolServerNetwork.bitcoinMainnet);

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<MempoolLoadFailure>());
    });
  });
}
