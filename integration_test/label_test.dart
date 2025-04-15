import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/labels/data/label_storage_datasource.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/labels.dart';

void main() {
  final labelStorage = LabelStorageDatasource();

  setUpAll(() async => await labelStorage.trashAll());

  tearDownAll(() async => await labelStorage.trashAll());

  group('Label Storage Integration Tests', () {
    test('Create and store a label', () async {
      final aLabel = labels.first;

      await labelStorage.store(aLabel);

      final fetchByLabel = await labelStorage.fetchByLabel(aLabel.label);
      final fetchByRef = await labelStorage.fetchByRef(aLabel.type, aLabel.ref);

      expect(fetchByLabel.length, 1);
      expect(fetchByRef.length, 1);

      expect(fetchByLabel.first.type, aLabel.type);
      expect(fetchByLabel.first.label, aLabel.label);
      expect(fetchByLabel.first.ref, aLabel.ref);
      expect(fetchByLabel.first.origin, aLabel.origin);
      expect(fetchByLabel.first.spendable, aLabel.spendable);

      expect(fetchByRef.first.type, aLabel.type);
      expect(fetchByRef.first.label, fetchByLabel.first.label);
      expect(fetchByRef.first.ref, fetchByLabel.first.ref);
      expect(fetchByRef.first.origin, fetchByLabel.first.origin);
      expect(fetchByRef.first.origin, aLabel.origin);
      expect(fetchByRef.first.spendable, aLabel.spendable);
    });

    test('Create and store multiple labels', () async {
      for (final label in labels) {
        await labelStorage.store(label);
      }
      debugPrint('Attempted creation of ${labels.length} labels');

      // fetchAll and assert that there are 10 items in the list; one is a duplicate
      final allLabels = await labelStorage.fetchAll();
      expect(allLabels, isNotNull);
      expect(allLabels.length, 10);
      debugPrint(
        'Created ${allLabels.length} labels. 1 Duplicate. TODO: Storage should return if a duplicate was found',
      );
    });

    test('Read labels by reference', () async {
      final addressLabels =
          await labelStorage.fetchByRef(Entity.address, addresses[0]);
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
      final txLabels = await labelStorage.fetchByRef(Entity.tx, txids[0]);
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
          await labelStorage.fetchByLabel('Important Transaction');
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
          await labelStorage.fetchByLabel('Bitcoin Purchase');
      expect(bitcoinPurchaseLabels, isNotNull);
      expect(bitcoinPurchaseLabels.length, 2);

      final addressLabel = bitcoinPurchaseLabels.firstWhere(
        (label) => label.type == Entity.address,
        orElse: () => throw Exception('No address label found'),
      );
      final txLabel = bitcoinPurchaseLabels.firstWhere(
        (label) => label.type == Entity.tx,
        orElse: () => throw Exception('No transaction label found'),
      );

      expect(addresses.contains(addressLabel.ref), isTrue);
      expect(txids.contains(txLabel.ref), isTrue);

      debugPrint('Found "Bitcoin Purchase" labels for:');
      debugPrint('  Address: ${addressLabel.ref} (type: ${addressLabel.type})');
      debugPrint('  Transaction: ${txLabel.ref} (type: ${txLabel.type})');
    });

    test('Delete a specific label', () async {
      const label = 'Temporary Label';
      final labelToDelete = LabelModel(
        type: Entity.address,
        ref: addresses[0],
        label: label,
      );

      await labelStorage.store(labelToDelete);

      final addressLabels = await labelStorage.fetchByRef(
        Entity.address,
        addresses[0],
      );
      expect(addressLabels.length, 4, reason: 'we should have 4 labels');

      await labelStorage.trash(labelToDelete.label);

      final updatedAddressLabels = await labelStorage.fetchByRef(
        Entity.address,
        addresses[0],
      );
      expect(updatedAddressLabels.length, 3,
          reason: 'the label should have been removed');

      final remainingLabels = updatedAddressLabels.map((l) => l.label).toList();
      expect(remainingLabels, isNot(contains(label)));

      debugPrint(
        'Successfully deleted label "Temporary Label" from address ${addresses[0]}',
      );
    });

    test('Delete a label for all entities', () async {
      const label = 'Shared Label';

      final labelOnAddress = LabelModel(
        type: Entity.address,
        ref: addresses[0],
        label: label,
      );

      final labelOnTx = LabelModel(
        type: Entity.tx,
        ref: txids[0],
        label: label,
      );

      await labelStorage.store(labelOnAddress);
      await labelStorage.store(labelOnTx);

      var labelled = await labelStorage.fetchByLabel(label);
      expect(labelled.length, 2);

      await labelStorage.trash(label);

      labelled = await labelStorage.fetchByLabel(label);
      expect(labelled, isEmpty);
    });
  });
}
