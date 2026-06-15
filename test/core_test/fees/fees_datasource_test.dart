import 'package:bb_mobile/core/fees/data/fees_datasource.dart';
import 'package:bb_mobile/core/mempool/application/usecases/get_active_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_settings.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _MockSettingsRepo extends Mock implements MempoolSettingsRepository {}

class _MockActiveServerUsecase extends Mock
    implements GetActiveMempoolServerUsecase {}

const _precise = ApiServiceConstants.mempoolPreciseFeesPath;
const _recommended = ApiServiceConstants.mempoolRecommendedFeesPath;

Response<dynamic> _ok(String path, Map<String, dynamic> body) => Response(
  requestOptions: RequestOptions(path: path),
  statusCode: 200,
  data: body,
);

Response<dynamic> _status(String path, int code) => Response(
  requestOptions: RequestOptions(path: path),
  statusCode: code,
);

DioException _dioError(String path, {int? statusCode}) => DioException(
  requestOptions: RequestOptions(path: path),
  response: statusCode == null
      ? null
      : Response(requestOptions: RequestOptions(path: path), statusCode: statusCode),
);

void main() {
  late _MockDio dio;
  late _MockSettingsRepo settingsRepo;
  late _MockActiveServerUsecase activeServer;
  late FeesDatasource datasource;

  setUpAll(() {
    registerFallbackValue(
      MempoolServerNetwork.fromEnvironment(isTestnet: false, isLiquid: false),
    );
  });

  setUp(() {
    dio = _MockDio();
    settingsRepo = _MockSettingsRepo();
    activeServer = _MockActiveServerUsecase();
    datasource = FeesDatasource(
      getActiveMempoolServerUsecase: activeServer,
      mempoolSettingsRepository: settingsRepo,
      dioBuilder: (_) => dio,
    );
    // Use BB's mempool (no custom server) so the active-server usecase isn't
    // involved — keeps the test focused on the precise/recommended fallback.
    when(() => settingsRepo.fetchByNetwork(any())).thenAnswer(
      (_) async => MempoolSettings.existing(
        network: MempoolServerNetwork.fromEnvironment(
          isTestnet: false,
          isLiquid: false,
        ),
        useForFeeEstimation: false,
      ),
    );
  });

  group('FeesDatasource.fetchBitcoinNetworkFees', () {
    test('uses precise endpoint when it returns 200 with decimals', () async {
      when(() => dio.get<dynamic>(_precise)).thenAnswer(
        (_) async => _ok(_precise, {
          'fastestFee': 1.203,
          'halfHourFee': 0.92,
          'hourFee': 0.65,
          'economyFee': 0.2,
          'minimumFee': 0.1,
        }),
      );

      final fees = await datasource.fetchBitcoinNetworkFees(isTestnet: false);

      expect(fees.fastestFee, 1.203);
      expect(fees.hourFee, 0.65);
      expect(fees.economyFee, 0.2);
      verifyNever(() => dio.get<dynamic>(_recommended));
    });

    test('falls back to recommended when precise 404s', () async {
      when(
        () => dio.get<dynamic>(_precise),
      ).thenThrow(_dioError(_precise, statusCode: 404));
      when(() => dio.get<dynamic>(_recommended)).thenAnswer(
        (_) async => _ok(_recommended, {
          'fastestFee': 3,
          'halfHourFee': 2,
          'hourFee': 1,
          'economyFee': 1,
          'minimumFee': 1,
        }),
      );

      final fees = await datasource.fetchBitcoinNetworkFees(isTestnet: false);

      expect(fees.fastestFee, 3.0);
      expect(fees.hourFee, 1.0);
      verify(() => dio.get<dynamic>(_recommended)).called(1);
    });

    test('falls back on a transient precise error (500)', () async {
      when(
        () => dio.get<dynamic>(_precise),
      ).thenThrow(_dioError(_precise, statusCode: 500));
      when(() => dio.get<dynamic>(_recommended)).thenAnswer(
        (_) async => _ok(_recommended, {
          'fastestFee': 2,
          'halfHourFee': 2,
          'hourFee': 1,
          'economyFee': 1,
          'minimumFee': 1,
        }),
      );

      final fees = await datasource.fetchBitcoinNetworkFees(isTestnet: false);
      expect(fees.fastestFee, 2.0);
    });

    test('falls back when precise returns a non-200 (e.g. 204)', () async {
      when(
        () => dio.get<dynamic>(_precise),
      ).thenAnswer((_) async => _status(_precise, 204));
      when(() => dio.get<dynamic>(_recommended)).thenAnswer(
        (_) async => _ok(_recommended, {
          'fastestFee': 4,
          'halfHourFee': 3,
          'hourFee': 2,
          'economyFee': 1,
          'minimumFee': 1,
        }),
      );

      final fees = await datasource.fetchBitcoinNetworkFees(isTestnet: false);
      expect(fees.fastestFee, 4.0);
    });

    test('falls back when precise 200 body is missing a fee field', () async {
      // A 200 with a partial body makes MempoolFeesModel.fromJson throw;
      // that must trigger the recommended fallback, not fail the fetch.
      when(
        () => dio.get<dynamic>(_precise),
      ).thenAnswer((_) async => _ok(_precise, {'fastestFee': 2.0}));
      when(() => dio.get<dynamic>(_recommended)).thenAnswer(
        (_) async => _ok(_recommended, {
          'fastestFee': 3,
          'halfHourFee': 2,
          'hourFee': 1,
          'economyFee': 1,
          'minimumFee': 1,
        }),
      );

      final fees = await datasource.fetchBitcoinNetworkFees(isTestnet: false);
      expect(fees.fastestFee, 3.0);
      verify(() => dio.get<dynamic>(_recommended)).called(1);
    });

    test('throws MempoolFeesException when both endpoints fail', () async {
      when(
        () => dio.get<dynamic>(_precise),
      ).thenThrow(_dioError(_precise, statusCode: 404));
      when(
        () => dio.get<dynamic>(_recommended),
      ).thenThrow(_dioError(_recommended, statusCode: 404));

      expect(
        () => datasource.fetchBitcoinNetworkFees(isTestnet: false),
        throwsA(isA<MempoolFeesException>()),
      );
    });
  });
}
