import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_tor_route.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_vault_key_from_server_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/store_vault_key_into_server_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements RecoverBullRepository {}

class _Ensure extends Mock implements EnsureRecoverBullTorSessionUsecase {}

class _Vault extends Mock implements EncryptedVault {}

void main() {
  late _Repository repository;
  late _Ensure ensure;
  late _Vault vault;
  late RecoverBullTorRoute route;
  late int closed;

  setUp(() {
    repository = _Repository();
    ensure = _Ensure();
    vault = _Vault();
    when(() => vault.id).thenReturn('id');
    when(() => vault.salt).thenReturn('salt');
    closed = 0;
    route = RecoverBullTorRoute(
      TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
        evidence: TorReadinessEvidence.embeddedBootstrap,
        transport: TorTransport.direct,
      ),
      () async => closed++,
    );
    when(() => ensure.execute()).thenAnswer((_) async => Ok(route));
  });

  for (final borrowed in [false, true]) {
    test('store ${borrowed ? 'borrows' : 'owns'} its route', () async {
      when(
        () => repository.storeVaultKey(
          'id',
          'password',
          'salt',
          'key',
          route.endpoint,
        ),
      ).thenAnswer((_) async => const Ok(null));
      final usecase = StoreVaultKeyIntoServerUsecase(repository, ensure);

      final result = await usecase.execute(
        password: 'password',
        vault: vault,
        vaultKey: 'key',
        route: borrowed ? route : null,
      );

      expect(result, isA<Ok<Null, RecoverBullCoreFailure>>());
      verify(
        () => repository.storeVaultKey(
          'id',
          'password',
          'salt',
          'key',
          route.endpoint,
        ),
      ).called(1);
      if (borrowed) {
        verifyNever(() => ensure.execute());
      } else {
        verify(() => ensure.execute()).called(1);
      }
      expect(closed, borrowed ? 0 : 1);
    });

    test(
      'fetch ${borrowed ? 'borrows' : 'owns'} its route even on failure',
      () async {
        when(
          () => repository.fetchVaultKey(
            'id',
            'password',
            'salt',
            route.endpoint,
          ),
        ).thenAnswer((_) async => const Err(KeyServerUnavailableFailure()));
        final usecase = FetchVaultKeyFromServerUsecase(repository, ensure);

        final result = await usecase.execute(
          password: 'password',
          vault: vault,
          route: borrowed ? route : null,
        );

        expect(result, isA<Err<String, RecoverBullCoreFailure>>());
        verify(
          () => repository.fetchVaultKey(
            'id',
            'password',
            'salt',
            route.endpoint,
          ),
        ).called(1);
        if (borrowed) {
          verifyNever(() => ensure.execute());
        } else {
          verify(() => ensure.execute()).called(1);
        }
        expect(closed, borrowed ? 0 : 1);
      },
    );
  }
}
