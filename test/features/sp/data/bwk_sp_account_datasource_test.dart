import 'dart:io';

import 'package:bb_mobile/features/sp/data/datasources/bwk_sp_account_datasource.dart';
import 'package:bull_sdk/bull_sdk.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter_test/flutter_test.dart';

import '../sp_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(BullSdk.init);
  tearDownAll(BullSdk.dispose);

  test('dispose releases the account directory for immediate reopening', () async {
    final scratch = await Directory.systemTemp.createTemp('bull_sp_lifecycle_');
    final datasource = BwkSpAccountDatasource();
    addTearDown(() async {
      await datasource.dispose();
      await scratch.delete(recursive: true);
    });
    // Existing public, funds-free BIP39 fixture; installs the platform fake
    // and imports through the real Secrets implementation.
    final secret = await spSecret();

    Future<void> open() => datasource.createFromSecret(
      network: SpNetwork.signet,
      secret: secret,
      blindbitUrl: 'http://127.0.0.1:1',
      electrumUrl: '',
      dataDir: scratch.path,
      fetchConcurrencyFactor: 1,
      matchConcurrencyFactor: 1,
      headerCheckpoint: null,
    );

    await open();
    final address = datasource.spAddress();
    await datasource.dispose();
    expect(datasource.hasSession, isFalse);

    // No repository lock-file deletion, sleep, GC request, or retry: reopening
    // must be safe as soon as the public datasource disposal completes.
    await open();
    expect(datasource.hasSession, isTrue);
    expect(datasource.spAddress() == address, isTrue);
  });
}
