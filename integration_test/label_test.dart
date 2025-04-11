import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/labels/data/label_storage_datasource.dart';
import 'package:bb_mobile/core/labels/domain/label_entity.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/shared_preferences_datasource_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/labels.dart';

void main() {
  late LabelStorageDatasource labelStorageDatasource;

  setUpAll(() async {
    labelStorageDatasource = LabelStorageDatasource(
      labelStorage: SharedPreferencesDatasourceImpl(SharedPreferencesAsync()),
    );

    await labelStorageDatasource.trashAll();
  });

  group('Label Storage Integration Tests', () {
    test('Create and store multiple labels', () async {
      for (final label in labels) {
        await labelStorageDatasource.store(LabelModel.fromEntity(label));
      }
      debugPrint('Attempted creation of ${labels.length} labels');
      // fetchAll and assert that there are 10 items in the list; one is a duplicate
      final allLabels = await labelStorageDatasource.fetchAll();
      expect(allLabels, isNotNull);
      expect(allLabels.length, 10);
      debugPrint(
        'Created ${allLabels.length} labels. 1 Duplicate. TODO: Storage should return if a duplicate was found',
      );
    });

    test('Read labels by reference', () async {
      final addressLabels = await labelStorageDatasource.fetchByEntity(
          Prefix.address, addresses[0]);
      expect(addressLabels, isNotNull);
      expect(addressLabels.length, 3);

      // Verify labels contain expected values
      final labelTexts = addressLabels.map((l) => l.label).toList();
      expect(
        labelTexts,
        containsAll(
          ['Bitcoin Purchase', 'Cold Storage', 'Hardware Wallet'],
        ),
      );

      // Read labels for the first transaction (should have 3 labels)
      final txLabels =
          await labelStorageDatasource.fetchByEntity(Prefix.tx, txids[0]);
      expect(txLabels, isNotNull);
      expect(txLabels.length, 3);

      // Log results for debugging
      debugPrint(
        'Found ${addressLabels.length} labels for address ${addresses[0]}',
      );
      debugPrint(
        'Found ${txLabels.length} labels for transaction ${txids[0]}',
      );
    });

    test('Read labels by label value', () async {
      // Read labels with the shared label "Important Transaction" (should be 3)
      final importantLabels =
          await labelStorageDatasource.fetchByLabel('Important Transaction');
      expect(importantLabels, isNotNull);
      expect(importantLabels.length, 3);

      // Verify that the refs match the expected txids
      final refs = importantLabels.map((l) => l.ref).toList();
      expect(refs, containsAll([txids[0], txids[1], txids[2]]));

      // Log results for debugging
      debugPrint(
        'Found ${importantLabels.length} labels with value "Important Transaction"',
      );
    });

    test('Read labels by label value and verify different reference types',
        () async {
      final bitcoinPurchaseLabels =
          await labelStorageDatasource.fetchByLabel('Bitcoin Purchase');
      expect(bitcoinPurchaseLabels, isNotNull);
      expect(bitcoinPurchaseLabels.length, 2);

      final addressLabel = bitcoinPurchaseLabels.firstWhere(
        (label) => label.type == 'address',
        orElse: () => throw Exception('No address label found'),
      );
      final txLabel = bitcoinPurchaseLabels.firstWhere(
        (label) => label.type == 'tx',
        orElse: () => throw Exception('No transaction label found'),
      );

      expect(addresses.contains(addressLabel.ref), isTrue);
      expect(txids.contains(txLabel.ref), isTrue);

      debugPrint('Found "Bitcoin Purchase" labels for:');
      debugPrint('  Address: ${addressLabel.ref} (type: ${addressLabel.type})');
      debugPrint('  Transaction: ${txLabel.ref} (type: ${txLabel.type})');
    });

    test('Delete a specific label', () async {
      final labelToDelete = Label(
        type: LabelType.address,
        ref: addresses[0],
        label: 'Temporary Label',
      );

      await labelStorageDatasource.store(LabelModel.fromEntity(labelToDelete));

      final addressLabels = await labelStorageDatasource.fetchByEntity(
        Prefix.address,
        addresses[0],
      );
      expect(addressLabels.length, 4); // Now should have 4 labels

      await labelStorageDatasource.trash(LabelModel.fromEntity(labelToDelete));

      final updatedAddressLabels = await labelStorageDatasource.fetchByEntity(
        Prefix.address,
        addresses[0],
      );
      expect(updatedAddressLabels.length, 3); // Back to 3 labels

      final remainingLabels = updatedAddressLabels.map((l) => l.label).toList();
      expect(remainingLabels, isNot(contains('Temporary Label')));

      debugPrint(
        'Successfully deleted label "Temporary Label" from address ${addresses[0]}',
      );
    });
  });

  tearDownAll(() async {
    await labelStorageDatasource.trashAll();
    debugPrint('All labels deleted as part of test cleanup');
  });
}
