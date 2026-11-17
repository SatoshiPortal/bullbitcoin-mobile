import 'package:btc_map/src/data/ip_map_location_repository.dart';
import 'package:btc_map/src/domain/bull_map_failure.dart';
import 'package:btc_map/src/domain/entities/geo_point.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  IpMapLocationRepository repository(Object? body, {int status = 200}) {
    final client = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.uri.host, 'ipwho.is');
            expect(options.uri.scheme, 'https');
            expect(options.queryParameters, {
              'fields': 'success,latitude,longitude',
            });
            expect(options.headers, isEmpty);
            if (status != 200) {
              handler.reject(
                DioException.badResponse(
                  statusCode: status,
                  requestOptions: options,
                  response: Response<Object?>(
                    requestOptions: options,
                    statusCode: status,
                  ),
                ),
              );
            } else {
              handler.resolve(
                Response<Object?>(requestOptions: options, data: body),
              );
            }
          },
        ),
      );
    return IpMapLocationRepository(createClient: () => client);
  }

  test(
    'looks up the caller connection without app or wallet identifiers',
    () async {
      final result = await repository({
        'success': true,
        'latitude': 45.5,
        'longitude': -73.6,
      }).locate();
      expect(
        result,
        isA<Ok<GeoPoint, BullMapFailure>>().having(
          (r) => r.value,
          'position',
          GeoPoint(latitude: 45.5, longitude: -73.6),
        ),
      );
    },
  );

  test('rejects failures, malformed bodies and invalid coordinates', () async {
    for (final body in <Object?>[
      null,
      [],
      {'success': false, 'latitude': 1, 'longitude': 2},
      {'latitude': 1, 'longitude': 2},
      {'success': true, 'latitude': '1', 'longitude': 2},
      {'success': true, 'latitude': 91, 'longitude': 2},
      {'success': true, 'latitude': 1, 'longitude': double.nan},
    ]) {
      expect(
        await repository(body).locate(),
        isA<Err<GeoPoint, BullMapFailure>>(),
      );
    }
  });

  test('rate limits and server errors are recoverable failures', () async {
    for (final status in [429, 503]) {
      expect(
        await repository(null, status: status).locate(),
        isA<Err<GeoPoint, BullMapFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<BullMapNetworkFailure>(),
        ),
      );
    }
  });

  testWidgets(
    'an unresponsive service times out without holding the map open',
    (tester) async {
      final client = Dio()
        ..interceptors.add(InterceptorsWrapper(onRequest: (_, _) {}));
      final result = IpMapLocationRepository(createClient: () => client)
          .locate();
      await tester.pump(const Duration(seconds: 4));
      expect(await result, isA<Err<GeoPoint, BullMapFailure>>());
    },
  );

  test('connection failures do not escape', () async {
    final client = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException.connectionError(
                requestOptions: options,
                reason: 'offline',
              ),
            );
          },
        ),
      );
    expect(
      await IpMapLocationRepository(createClient: () => client).locate(),
      isA<Err<GeoPoint, BullMapFailure>>(),
    );
  });
}
