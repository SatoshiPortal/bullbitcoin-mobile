import 'dart:io';

import 'package:btc_map/src/bull_map.dart';
import 'package:btc_map/src/data/datasources/merchant_cache_datasource.dart';
import 'package:btc_map/src/data/models/merchant_model.dart';
import 'package:btc_map/src/domain/entities/merchant.dart';
import 'package:btc_map/src/domain/bull_map_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test('reopening shares decoded merchants; init replaces the cache', () async {
    final directory = await Directory.systemTemp.createTemp('map_session');
    final other = await Directory.systemTemp.createTemp('map_session_empty');
    addTearDown(() async {
      await directory.delete(recursive: true);
      await other.delete(recursive: true);
    });
    await MerchantCacheDatasource(directory).write([
      MerchantModel.fromJson({
        'id': 1,
        'lat': 10,
        'lon': 20,
        'name': 'Shop',
        'updated_at': '2026-11-17T00:00:00Z',
      }),
    ]);
    BullMap.init(cacheDirectory: directory.path);
    final results = await Future.wait([
      BullMap.open().cachedMerchants(),
      BullMap.open().cachedMerchants(),
    ]);
    final first = (results[0] as Ok<List<Merchant>, BullMapFailure>).value;
    final second = (results[1] as Ok<List<Merchant>, BullMapFailure>).value;
    expect(first.single.id, 1);
    expect(identical(first, second), isTrue);

    BullMap.init(cacheDirectory: other.path);
    final empty = await BullMap.open().cachedMerchants();
    expect((empty as Ok<List<Merchant>, BullMapFailure>).value, isEmpty);
  });
}
