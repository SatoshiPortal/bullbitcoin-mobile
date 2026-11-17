import 'dart:io';

import 'package:bull_map/bull_map.dart';
import 'package:bull_map/src/data/datasources/btc_map_api_datasource.dart';
import 'package:bull_map/src/data/datasources/merchant_cache_datasource.dart';
import 'package:bull_map/src/data/models/merchant_model.dart';
import 'package:bull_map/src/data/merchant_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

class _FakeApi implements BtcMapApiDatasource {
  final List<DateTime?> requests = [];
  List<MerchantModel> Function(DateTime? since) respond = (_) => const [];

  @override
  Future<List<MerchantModel>> fetchPlaces({DateTime? updatedSince}) async {
    requests.add(updatedSince);
    return respond(updatedSince);
  }
}

MerchantModel _place(
  int id, {
  required DateTime updatedAt,
  DateTime? deletedAt,
}) => MerchantModel.fromJson({
  'id': id,
  'lat': 10,
  'lon': 20,
  'name': 'Place $id',
  'updated_at': updatedAt.toIso8601String(),
  if (deletedAt != null) 'deleted_at': deletedAt.toIso8601String(),
});

void main() {
  late Directory directory;
  late _FakeApi api;
  late MerchantCacheDatasource cache;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('merchant_map_test');
    api = _FakeApi();
    cache = MerchantCacheDatasource(directory);
  });

  tearDown(() => directory.delete(recursive: true));

  MerchantRepository repository() => MerchantRepository(api, cache);

  List<int> ids(Result<List<Object>, BullMapFailure> result) =>
      switch (result) {
        Ok(:final value) => [
          for (final m in value) (m as dynamic).id as int,
        ]..sort(),
        Err(:final failure) => fail('Expected Ok, got $failure'),
      };

  test('the first sync downloads everything and persists it', () async {
    api.respond = (_) => [
      _place(1, updatedAt: DateTime.utc(2026, 1, 1)),
      _place(2, updatedAt: DateTime.utc(2026, 1, 2)),
    ];

    expect(ids(await repository().sync()), [1, 2]);
    expect(api.requests, [null]);
    // A new repository (app restart) reads the same places from disk.
    expect(ids(await repository().cached()), [1, 2]);
  });

  test('later syncs ask only for changes since the newest place, and evict deletions', () async {
    api.respond = (_) => [
      _place(1, updatedAt: DateTime.utc(2026, 1, 1)),
      _place(2, updatedAt: DateTime.utc(2026, 1, 2)),
    ];
    final repo = repository();
    expect(ids(await repo.sync()), [1, 2]);

    api.respond = (_) => [
      _place(
        2,
        updatedAt: DateTime.utc(2026, 2, 1),
        deletedAt: DateTime.utc(2026, 2, 1),
      ),
      _place(3, updatedAt: DateTime.utc(2026, 2, 2)),
    ];
    expect(ids(await repo.sync()), [1, 3]);
    expect(api.requests.last, DateTime.utc(2026, 1, 2));
    expect(ids(await repository().cached()), [1, 3]);
  });

  test('a network error is a network failure and keeps the cache', () async {
    api.respond = (_) => [_place(1, updatedAt: DateTime.utc(2026))];
    final repo = repository();
    expect(ids(await repo.sync()), [1]);

    api.respond = (_) => throw DioException.connectionTimeout(
      timeout: const Duration(seconds: 1),
      requestOptions: RequestOptions(),
    );
    expect(
      await repo.sync(),
      isA<Err<Object, BullMapFailure>>().having(
        (e) => e.failure,
        'failure',
        isA<BullMapNetworkFailure>(),
      ),
    );
    expect(ids(await repo.cached()), [1]);
  });

  test('an unexpected body is an invalid-response failure', () async {
    api.respond = (_) => throw const FormatException('not an array');
    expect(
      await repository().sync(),
      isA<Err<Object, BullMapFailure>>().having(
        (e) => e.failure,
        'failure',
        isA<BullMapUnexpectedFailure>(),
      ),
    );
  });

  test(
    'a corrupt cache fails cached() but is rebuilt by a full sync',
    () async {
      await File('${directory.path}/btc_map_places.json')
          .writeAsString('{oops');
      final repo = repository();

      expect(
        await repo.cached(),
        isA<Err<Object, BullMapFailure>>().having(
          (e) => e.failure,
          'failure',
          isA<BullMapUnexpectedFailure>(),
        ),
      );

      api.respond = (_) => [_place(5, updatedAt: DateTime.utc(2026))];
      expect(ids(await repo.sync()), [5]);
      expect(api.requests, [null]);
    },
  );

  test('concurrent syncs share one download', () async {
    api.respond = (_) => [_place(1, updatedAt: DateTime.utc(2026))];
    final repo = repository();
    await Future.wait([repo.sync(), repo.sync()]);
    expect(api.requests, hasLength(1));
  });
}
