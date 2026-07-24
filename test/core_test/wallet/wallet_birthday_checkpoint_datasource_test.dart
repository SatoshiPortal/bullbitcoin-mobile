import 'package:bb_mobile/core/mempool/application/usecases/get_active_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_birthday_checkpoint_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _MockActiveServerUsecase extends Mock
    implements GetActiveMempoolServerUsecase {}

const _path = '/api/v1/mining/blocks/timestamp/1231006505';

Response<dynamic> _ok(Object? body) => Response(
  requestOptions: RequestOptions(path: _path),
  statusCode: 200,
  data: body,
);

void main() {
  late _MockDio dio;
  late _MockActiveServerUsecase activeServer;
  late WalletBirthdayCheckpointDatasource datasource;

  setUpAll(() {
    registerFallbackValue(
      MempoolServerNetwork.fromEnvironment(isTestnet: false, isLiquid: false),
    );
  });

  setUp(() {
    dio = _MockDio();
    activeServer = _MockActiveServerUsecase();
    datasource = WalletBirthdayCheckpointDatasource(
      getActiveMempoolServerUsecase: activeServer,
      dioBuilder: (_) => dio,
    );
    when(
      () => activeServer.execute(
        isTestnet: any(named: 'isTestnet'),
        isLiquid: any(named: 'isLiquid'),
      ),
    ).thenAnswer(
      (_) async => Ok(
        MempoolServer.existing(
          url: 'mempool.space',
          network: MempoolServerNetwork.fromEnvironment(
            isTestnet: false,
            isLiquid: false,
          ),
          isCustom: false,
        ),
      ),
    );
  });

  test('resolves the active server with isLiquid: false always', () async {
    when(() => dio.get<dynamic>(_path)).thenAnswer(
      (_) async => _ok({
        'height': 0,
        'hash': '0' * 64,
        'timestamp': '2009-01-03T18:15:05.000Z',
      }),
    );

    await datasource.fetchBlockAtOrBeforeTimestamp(
      isTestnet: false,
      unixSeconds: 1231006505,
    );

    verify(
      () => activeServer.execute(isTestnet: false, isLiquid: false),
    ).called(1);
  });

  test('parses a well-formed JSON object body', () async {
    when(() => dio.get<dynamic>(_path)).thenAnswer(
      (_) async => _ok({
        'height': 0,
        'hash': '0' * 64,
        'timestamp': '2009-01-03T18:15:05.000Z',
      }),
    );

    final response = await datasource.fetchBlockAtOrBeforeTimestamp(
      isTestnet: false,
      unixSeconds: 1231006505,
    );

    expect(response.height, 0);
    expect(response.hash, '0' * 64);
    expect(response.timestamp, DateTime.utc(2009, 1, 3, 18, 15, 5));
  });

  test('parses a body that arrived as a JSON-encoded string (misconfigured '
      'self-hosted server serving text/plain)', () async {
    when(() => dio.get<dynamic>(_path)).thenAnswer(
      (_) async => _ok(
        '{"height":0,"hash":"${'0' * 64}","timestamp":"2009-01-03T18:15:05.000Z"}',
      ),
    );

    final response = await datasource.fetchBlockAtOrBeforeTimestamp(
      isTestnet: false,
      unixSeconds: 1231006505,
    );

    expect(response.height, 0);
  });

  test('throws FormatException on a non-object body', () async {
    when(
      () => dio.get<dynamic>(_path),
    ).thenAnswer((_) async => _ok('<html>maintenance</html>'));

    expect(
      () => datasource.fetchBlockAtOrBeforeTimestamp(
        isTestnet: false,
        unixSeconds: 1231006505,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('throws when no active mempool server can be resolved', () async {
    when(
      () => activeServer.execute(
        isTestnet: any(named: 'isTestnet'),
        isLiquid: any(named: 'isLiquid'),
      ),
    ).thenAnswer((_) async => const Err(MempoolLoadFailure('no server')));

    expect(
      () => datasource.fetchBlockAtOrBeforeTimestamp(
        isTestnet: false,
        unixSeconds: 1231006505,
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('propagates a DioException from the transport', () async {
    when(
      () => dio.get<dynamic>(_path),
    ).thenThrow(DioException(requestOptions: RequestOptions(path: _path)));

    expect(
      () => datasource.fetchBlockAtOrBeforeTimestamp(
        isTestnet: false,
        unixSeconds: 1231006505,
      ),
      throwsA(isA<DioException>()),
    );
  });
}
