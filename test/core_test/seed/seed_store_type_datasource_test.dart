import 'dart:convert';

import 'package:bb_mobile/core/seed/data/datasources/seed_store_type_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_store_type_model.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed_store_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SeedStoreTypeDatasource datasource;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    datasource = const SeedStoreTypeDatasource();
  });

  group('SeedStoreTypeDatasource', () {
    test('read returns null on fresh install (no value stored)', () async {
      final result = await datasource.read();

      final prefs = await SharedPreferences.getInstance();
      final rawValue = prefs.getString('seed_store_type');

      print('--- fresh install ---');
      print('key:   seed_store_type');
      print('value: $rawValue');
      print('result: $result');

      expect(result, isNull);
    });

    test('write fss10 then read returns fss10', () async {
      final model = SeedStoreTypeModel.fromEntity(
        const SeedStoreType(storageLibrary: SeedStorageLibrary.fss10),
      );

      await datasource.write(model);

      final prefs = await SharedPreferences.getInstance();
      final rawValue = prefs.getString('seed_store_type');
      final decoded = jsonDecode(rawValue!) as Map<String, dynamic>;

      print('--- write fss10 ---');
      print('key:   seed_store_type');
      print('value: $rawValue');
      print('decoded: $decoded');

      final result = await datasource.read();
      final entity = result!.toEntity();

      print('entity.storageLibrary: ${entity.storageLibrary}');

      expect(decoded['storageLibrary'], 'fss10');
      expect(entity.storageLibrary, SeedStorageLibrary.fss10);
    });

    test('write fss9 then read returns fss9', () async {
      final model = SeedStoreTypeModel.fromEntity(
        const SeedStoreType(storageLibrary: SeedStorageLibrary.fss9),
      );

      await datasource.write(model);

      final prefs = await SharedPreferences.getInstance();
      final rawValue = prefs.getString('seed_store_type');
      final decoded = jsonDecode(rawValue!) as Map<String, dynamic>;

      print('--- write fss9 ---');
      print('key:   seed_store_type');
      print('value: $rawValue');
      print('decoded: $decoded');

      final result = await datasource.read();
      final entity = result!.toEntity();

      print('entity.storageLibrary: ${entity.storageLibrary}');

      expect(decoded['storageLibrary'], 'fss9');
      expect(entity.storageLibrary, SeedStorageLibrary.fss9);
    });

    test('overwrite replaces the stored value — no duplicates', () async {
      await datasource.write(
        SeedStoreTypeModel.fromEntity(
          const SeedStoreType(storageLibrary: SeedStorageLibrary.fss9),
        ),
      );
      await datasource.write(
        SeedStoreTypeModel.fromEntity(
          const SeedStoreType(storageLibrary: SeedStorageLibrary.fss10),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final seedStoreKeys =
          allKeys.where((k) => k == 'seed_store_type').toList();
      final rawValue = prefs.getString('seed_store_type');

      print('--- overwrite fss9 -> fss10 ---');
      print('all keys in store: $allKeys');
      print('seed_store_type key count: ${seedStoreKeys.length}');
      print('key:   seed_store_type');
      print('value: $rawValue');

      final result = await datasource.read();
      final entity = result!.toEntity();

      print('entity.storageLibrary: ${entity.storageLibrary}');

      expect(seedStoreKeys.length, 1, reason: 'only one seed_store_type entry must exist');
      expect(entity.storageLibrary, SeedStorageLibrary.fss10);
    });
  });
}
