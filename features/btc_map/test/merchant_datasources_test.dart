import 'dart:io';

import 'package:btc_map/src/data/datasources/btc_map_api_datasource.dart';
import 'package:btc_map/src/data/datasources/merchant_cache_datasource.dart';
import 'package:btc_map/src/data/models/merchant_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Dio that records each request and answers it with [body], offline.
(Dio, List<RequestOptions>) _recordingDio(String body) {
  final requests = <RequestOptions>[];
  final dio = Dio(BaseOptions(responseType: ResponseType.plain))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response<String>(
              requestOptions: options,
              statusCode: 200,
              data: body,
            ),
          );
        },
      ),
    );
  return (dio, requests);
}

void main() {
  group('BtcMapApiDatasource', () {
    test('a full sync does not ask for deleted places', () async {
      final (dio, requests) = _recordingDio('[{"id": 1}]');
      final places = await BtcMapApiDatasource(dio: dio).fetchPlaces();

      expect(places.single.id, 1);
      final query = requests.single.queryParameters;
      expect(query['fields'], MerchantModel.apiFields);
      expect(query.containsKey('updated_since'), isFalse);
      expect(query.containsKey('include_deleted'), isFalse);
    });

    test('an incremental sync asks for deletions since the cursor', () async {
      final (dio, requests) = _recordingDio('[]');
      await BtcMapApiDatasource(dio: dio)
          .fetchPlaces(updatedSince: DateTime.utc(2026, 11, 1, 12));

      final query = requests.single.queryParameters;
      expect(query['fields'], MerchantModel.syncFields);
      expect(query['updated_since'], '2026-11-01T12:00:00.000Z');
      expect(query['include_deleted'], 'true');
    });

    test('a body that is not a list is a format error', () async {
      final (dio, _) = _recordingDio('{"error": "nope"}');
      await expectLater(
        BtcMapApiDatasource(dio: dio).fetchPlaces(),
        throwsFormatException,
      );
    });
  });

  group('MerchantCacheDatasource', () {
    late Directory directory;
    late MerchantCacheDatasource cache;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('merchant_cache');
      cache = MerchantCacheDatasource(directory);
    });

    tearDown(() => directory.delete(recursive: true));

    test('is empty before the first write', () async {
      expect((await cache.read()).places, isEmpty);
    });

    test(
      'overlapping writes leave one complete file and no leftovers',
      () async {
        // The map closed and reopened mid-download: two syncs write at once.
        await Future.wait([
          cache.write([
            MerchantModel.fromJson({'id': 1, 'name': 'First'}),
          ]),
          cache.write([
            MerchantModel.fromJson({'id': 1, 'name': 'Second'}),
            MerchantModel.fromJson({'id': 2}),
          ]),
        ]);

        final stored = (await cache.read()).places;
        expect(stored, anyOf(hasLength(1), hasLength(2)));
        final leftovers = directory.listSync().where(
          (entry) => entry.path.endsWith('.tmp'),
        );
        expect(leftovers, isEmpty);
      },
    );

    test('keeps the cursor next to the places', () async {
      await cache.write([
        MerchantModel.fromJson({'id': 1}),
      ], cursor: DateTime.utc(2026, 3, 1));
      final stored = await cache.read();
      expect(stored.places.single.id, 1);
      expect(stored.cursor, DateTime.utc(2026, 3, 1));
    });

    test('a write sweeps temporary files a killed write left', () async {
      final stale = File('${directory.path}/btc_map_places.json.1.tmp')
        ..writeAsStringSync('partial');
      stale.setLastModifiedSync(
        DateTime.now().subtract(const Duration(hours: 1)),
      );
      final fresh = File('${directory.path}/btc_map_places.json.2.tmp')
        ..writeAsStringSync('another write in progress');

      await cache.write([
        MerchantModel.fromJson({'id': 1}),
      ]);

      expect(stale.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue);
    });
  });
}
