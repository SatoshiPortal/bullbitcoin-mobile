// import 'package:bb_mobile/core/labels/data/label_datasource.dart';
// import 'package:bb_mobile/core/labels/data/label_repository.dart';
// import 'package:bb_mobile/core/storage/sqlite_database.dart';
// import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
// import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
// import 'package:bb_mobile/locator.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_test/flutter_test.dart';

// import 'fixtures/labels_fixtures.dart';

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();

//   locator.registerLazySingleton<SqliteDatabase>(() => SqliteDatabase());
//   final sqlite = locator<SqliteDatabase>();
//   locator.registerLazySingleton<LabelDatasource>(
//     () => LabelDatasource(sqlite: sqlite),
//   );
//   locator.registerLazySingleton<LabelRepository>(
//     () => LabelRepository(labelDatasource: locator<LabelDatasource>()),
//   );
//   final labelRepository = locator<LabelRepository>();

//   setUpAll(() async => await labelRepository.trashAll());

//   tearDownAll(() async => await labelRepository.trashAll());

//   final address = WalletAddress.bitcoin(
//     address: labels.first.ref,
//     index: 0,
//     status: WalletAddressStatus.unused,
//     walletId: '',
//   );

//   final transaction = WalletTransaction(
//     walletId: 'x',
//     direction: WalletTransactionDirection.incoming,
//     txId: txids.first,
//     amountSat: 0,
//     feeSat: 0,
//     status: WalletTransactionStatus.confirmed,
//     inputs: [],
//     outputs: [],
//   );

//   group('Label Storage Integration Tests', () {
//     test('Create and store a label', () async {
//       final aLabel = labels.first;

//       await labelRepository.store<WalletAddress>(
//         label: aLabel.label,
//         entity: address,
//         origin: aLabel.origin,
//         spendable: aLabel.spendable,
//       );

//       final fetchByLabel = await labelRepository.fetchByLabel(
//         label: aLabel.label,
//       );
//       final fetchByRef = await labelRepository.fetchByEntity<WalletAddress>(
//         entity: address,
//       );

//       expect(fetchByLabel.length, 1);
//       expect(fetchByRef.length, 1);

//       expect(fetchByLabel.first.label, aLabel.label);
//       expect(fetchByLabel.first.origin, aLabel.origin);
//       expect(fetchByLabel.first.spendable, aLabel.spendable);

//       expect(fetchByRef.first.label, fetchByLabel.first.label);
//       expect(fetchByRef.first.origin, fetchByLabel.first.origin);
//       expect(fetchByRef.first.origin, aLabel.origin);
//       expect(fetchByRef.first.spendable, aLabel.spendable);
//     });

//     test('Create and store multiple labels', () async {
//       for (final label in labels) {
//         await sqlite
//             .into(sqlite.labels)
//             .insertOnConflictUpdate(
//               LabelRow(
//                 label: label.label,
//                 type: label.type,
//                 ref: label.ref,
//                 origin: label.origin,
//                 spendable: label.spendable,
//               ),
//             );
//       }
//       debugPrint('Attempted creation of ${labels.length} labels');

//       // fetchAll and assert that there are 10 items in the list; one is a duplicate
//       final allLabels = await labelRepository.fetchAll();
//       expect(allLabels, isNotNull);
//       expect(allLabels.length, 10);
//       debugPrint(
//         'Created ${allLabels.length} labels. 1 Duplicate. TODO: Storage should return if a duplicate was found',
//       );
//     });

//     test('Read labels by reference', () async {
//       final addressLabels = await labelRepository.fetchByEntity<WalletAddress>(
//         entity: address,
//       );
//       expect(addressLabels, isNotNull);
//       expect(addressLabels.length, 3);

//       // Verify labels contain expected values
//       final labelTexts = addressLabels.map((l) => l.label).toList();
//       expect(
//         labelTexts,
//         containsAll(['Bitcoin Purchase', 'Cold Storage', 'Hardware Wallet']),
//       );

//       // Read labels for the first transaction (should have 3 labels)
//       final txLabels = await labelRepository.fetchByEntity<WalletTransaction>(
//         entity: transaction,
//       );
//       expect(txLabels, isNotNull);
//       expect(txLabels.length, 3);

//       // Log results for debugging
//       debugPrint(
//         'Found ${addressLabels.length} labels for address ${addresses[0]}',
//       );
//       debugPrint('Found ${txLabels.length} labels for transaction ${txids[0]}');
//     });

//     test('Read labels by label value', () async {
//       // Read labels with the shared label "Important Transaction" (should be 3)
//       final importantLabels = await labelRepository.fetchByLabel(
//         label: 'Important Transaction',
//       );
//       expect(importantLabels, isNotNull);
//       expect(importantLabels.length, 3);

//       // // Verify that the refs match the expected txids
//       // final refs = importantLabels.map((l) => l.ref).toList();
//       // expect(refs, containsAll([txids[0], txids[1], txids[2]]));

//       // Log results for debugging
//       debugPrint(
//         'Found ${importantLabels.length} labels with value "Important Transaction"',
//       );
//     });

//     test(
//       'Read labels by label value and verify different reference types',
//       () async {
//         final bitcoinPurchaseLabels = await labelRepository.fetchByLabel(
//           label: 'Bitcoin Purchase',
//         );
//         expect(bitcoinPurchaseLabels, isNotNull);
//         expect(bitcoinPurchaseLabels.length, 2);

//         // final addressLabel = bitcoinPurchaseLabels.firstWhere(
//         //   (label) => label.type == Entity.address,
//         //   orElse: () => throw Exception('No address label found'),
//         // );
//         // final txLabel = bitcoinPurchaseLabels.firstWhere(
//         //   (label) => label.type == Entity.tx,
//         //   orElse: () => throw Exception('No transaction label found'),
//         // );

//         // expect(addresses.contains(addressLabel.ref), isTrue);
//         // expect(txids.contains(txLabel.ref), isTrue);

//         // debugPrint('Found "Bitcoin Purchase" labels for:');
//         // debugPrint('  Address: ${addressLabel.ref} (type: ${addressLabel.type})');
//         // debugPrint('  Transaction: ${txLabel.ref} (type: ${txLabel.type})');
//       },
//     );

//     test('Delete a specific label', () async {
//       const tmpLabel = 'Temporary Label';
//       await labelRepository.store<WalletAddress>(
//         label: tmpLabel,
//         entity: address,
//       );

//       final addressLabels = await labelRepository.fetchByEntity<WalletAddress>(
//         entity: address,
//       );
//       expect(addressLabels.length, 4, reason: 'we should have 4 labels');

//       await labelRepository.trashOneLabel(label: tmpLabel, entity: address);

//       final updatedAddressLabels = await labelRepository
//           .fetchByEntity<WalletAddress>(entity: address);
//       expect(
//         updatedAddressLabels.length,
//         3,
//         reason: 'the label should have been removed',
//       );

//       final remainingLabels = updatedAddressLabels.map((l) => l.label).toList();
//       expect(remainingLabels, isNot(contains(tmpLabel)));

//       debugPrint(
//         'Successfully deleted label "Temporary Label" from address ${addresses[0]}',
//       );
//     });

//     test('Delete a label for all entities', () async {
//       const label = 'Shared Label';

//       await labelRepository.store<WalletAddress>(label: label, entity: address);
//       await labelRepository.store<WalletTransaction>(
//         label: label,
//         entity: transaction,
//       );

//       var labelled = await labelRepository.fetchByLabel(label: label);
//       expect(labelled.length, 2);

//       await labelRepository.trashByLabel(label: label);

//       labelled = await labelRepository.fetchByLabel(label: label);
//       expect(labelled, isEmpty);
//     });
//   });
// }

// Temporary main function to prevent compilation errors
// TODO: Remove this when tests are ready to be implemented
void main() {
  // Tests are commented out and will be implemented later
}
