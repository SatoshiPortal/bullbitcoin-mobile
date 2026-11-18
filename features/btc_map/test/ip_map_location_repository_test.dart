import 'package:btc_map/src/data/ip_map_location_repository.dart';
import 'package:btc_map/src/domain/bull_map_failure.dart';
import 'package:btc_map/src/domain/entities/geo_point.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

Object locationResponse(
  Object? latitude,
  Object? longitude, {
  Object? geoReference = 1,
  Object? latitudeReference = 2,
}) => {
  'type': 'data',
  'nodes': [
    {
      'type': 'data',
      'data': [null],
    },
    {
      'type': 'data',
      'data': [
        {'geo': geoReference, 'merchantOgImage': 4},
        {'lat': latitudeReference, 'lng': 3},
        latitude,
        longitude,
        null,
      ],
    },
  ],
};

void main() {
  IpMapLocationRepository repository(Object? body, {int status = 200}) {
    final client = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.uri.host, 'btcmap.org');
            expect(options.uri.path, '/map/__data.json');
            expect(options.uri.scheme, 'https');
            expect(options.queryParameters, isEmpty);
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
      final result = await repository(locationResponse(45.5, -73.6)).locate();
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

  test('zero coordinates remain valid', () async {
    expect(
      await repository(locationResponse(0, 0)).locate(),
      isA<Ok<GeoPoint, BullMapFailure>>().having(
        (r) => r.value,
        'position',
        GeoPoint(latitude: 0, longitude: 0),
      ),
    );
  });

  test('rejects failures, malformed bodies and invalid coordinates', () async {
    for (final body in <Object?>[
      null,
      [],
      {'latitude': 1, 'longitude': 2},
      locationResponse('1', 2),
      locationResponse(91, 2),
      locationResponse(1, double.nan),
      locationResponse(1, double.infinity),
      locationResponse(1, 2, geoReference: -1),
      locationResponse(1, 2, geoReference: 999),
      locationResponse(1, 2, geoReference: '1'),
      locationResponse(1, 2, latitudeReference: -1),
      locationResponse(1, 2, latitudeReference: 999),
      locationResponse(1, 2, latitudeReference: 2.0),
      locationResponse(null, 2),
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
