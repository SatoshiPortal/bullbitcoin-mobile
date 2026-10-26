import 'dart:async';
import 'dart:io';

import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';
import 'package:wallet_transaction_sync/src/testing/sqlite_wallet_sync_metadata_store_test_support.dart';

Future<void> main(List<String> args) async {
  final path = args[0];
  final role = args[1];
  final barrier = Directory(args[2]);
  barrier.createSync(recursive: true);
  File(
    '${barrier.path}/$role-ready',
  ).writeAsStringSync(DateTime.now().microsecondsSinceEpoch.toString());
  if (role == 'b') {
    await _waitFor(File('${barrier.path}/a-gate-held'));
    final attempt = File('${barrier.path}/b-operation-attempt')
      ..createSync(exclusive: true);
    attempt.writeAsStringSync(DateTime.now().microsecondsSinceEpoch.toString());
  }
  final store = role == 'a'
      ? await SqliteWalletSyncMetadataStoreTestSupport.open(
          databasePath: path,
          gateHoldCommand: 'registration',
          gateHeldFile: '${barrier.path}/a-gate-held',
          gateReleaseFile: '${barrier.path}/a-release',
        )
      : await SqliteWalletSyncMetadataStore.open(databasePath: path);
  File(
    '${barrier.path}/$role-open',
  ).writeAsStringSync(DateTime.now().microsecondsSinceEpoch.toString());
  for (var i = 0; i < 8; i++) {
    await store.writeRegistration(
      WalletSourceRegistration(
        key: WalletNetworkKey('$role-$i', 'bitcoin', 'testnet'),
        sourceKind: 'subprocess',
        configurationFingerprint: '$role-config-$i',
      ),
    );
  }
  await store.close();
  File(
    '${barrier.path}/$role-complete',
  ).writeAsStringSync(DateTime.now().microsecondsSinceEpoch.toString());
}

Future<void> _waitFor(File file) async {
  for (var i = 0; i < 2000; i++) {
    if (file.existsSync()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError('subprocess barrier timed out');
}
