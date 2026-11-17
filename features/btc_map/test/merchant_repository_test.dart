import 'package:btc_map/src/domain/merchant_repository.dart';

import 'dart:io';
import 'dart:isolate';

import 'package:btc_map/src/map_types.dart';
import 'package:btc_map/src/data/datasources/btc_map_api_datasource.dart';
import 'package:btc_map/src/data/datasources/merchant_cache_datasource.dart';
import 'package:btc_map/src/data/models/merchant_model.dart';
import 'package:btc_map/src/data/merchant_repository_impl.dart';
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

class _FailOnceCache extends MerchantCacheDatasource {
  int writes = 0;

  _FailOnceCache(super.directory);

  @override
  Future<void> write(List<MerchantModel> places, {DateTime? cursor}) async {
    writes++;
    if (writes == 1) throw const FileSystemException('disk full');
    await super.write(places, cursor: cursor);
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

  MerchantRepository repository() => MerchantRepositoryImpl(api, cache);

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

  test(
    'retries a failed cache write even without new server changes',
    () async {
      final flakyCache = _FailOnceCache(directory);
      final repo = MerchantRepositoryImpl(api, flakyCache);
      api.respond = (_) => [_place(1, updatedAt: DateTime.utc(2026))];
      expect(ids(await repo.sync()), [1]);
      api.respond = (_) => const [];
      expect(ids(await repo.sync()), [1]);
      expect(flakyCache.writes, 2);
      expect(ids(await repository().cached()), [1]);
    },
  );

  test('persists the cursor of a deletion absent from the snapshot', () async {
    final initial = DateTime.utc(2026, 1, 1);
    final deleted = DateTime.utc(2026, 2, 1);
    await cache.write([_place(1, updatedAt: initial)], cursor: initial);
    api.respond = (_) => [_place(2, updatedAt: deleted, deletedAt: deleted)];
    expect(ids(await repository().sync()), [1]);
    expect((await cache.read()).cursor, deleted);
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

  test('the cursor moves past a deletion, even after a restart', () async {
    api.respond = (_) => [_place(1, updatedAt: DateTime.utc(2026, 1, 1))];
    expect(ids(await repository().sync()), [1]);

    // The newest change is a deletion: the place leaves the cache, but the
    // next sync must not ask for it again.
    api.respond = (_) => [
      _place(
        1,
        updatedAt: DateTime.utc(2026, 2, 1),
        deletedAt: DateTime.utc(2026, 2, 1),
      ),
    ];
    final repo = repository();
    expect(ids(await repo.sync()), isEmpty);

    api.respond = (_) => const [];
    expect(ids(await repo.sync()), isEmpty);
    expect(await repository().sync(), isA<Ok<List<Object>, BullMapFailure>>());
    expect(api.requests.sublist(2), [
      DateTime.utc(2026, 2, 1),
      DateTime.utc(2026, 2, 1),
    ]);
  });

  test('a sync with no change returns the same list', () async {
    api.respond = (_) => [_place(1, updatedAt: DateTime.utc(2026))];
    final repo = repository();
    final first = await repo.sync();
    api.respond = (_) => const [];
    final second = await repo.sync();

    expect(
      identical(
        (first as Ok<List<Object>, BullMapFailure>).value,
        (second as Ok<List<Object>, BullMapFailure>).value,
      ),
      isTrue,
    );
  });

  test('an unexpected exception is a failure, not a hang', () async {
    api.respond = (_) => throw IsolateSpawnException('no isolate');
    expect(
      await repository().sync(),
      isA<Err<Object, BullMapFailure>>().having(
        (e) => e.failure,
        'failure',
        isA<BullMapUnexpectedFailure>(),
      ),
    );
  });

  test('places the server sends again unchanged are not a change', () async {
    final place = _place(1, updatedAt: DateTime.utc(2026, 1, 1));
    // An inclusive `updated_since` would hand back the newest place again.
    api.respond = (_) => [place];
    final repo = repository();
    final first = await repo.sync();
    final cacheFile = File('${directory.path}/btc_map_places.json');
    final writtenAt = cacheFile.lastModifiedSync();

    final second = await repo.sync();

    expect(
      identical(
        (first as Ok<List<Object>, BullMapFailure>).value,
        (second as Ok<List<Object>, BullMapFailure>).value,
      ),
      isTrue,
    );
    expect(cacheFile.lastModifiedSync(), writtenAt);
  });
}
