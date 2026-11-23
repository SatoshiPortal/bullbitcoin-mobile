import 'dart:io';

import 'package:silent/src/data/datasources/bwk_sp_account_datasource.dart';
import 'package:rust_bindings/rust_bindings.dart';
import 'package:rust_bindings/bwk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show SecretFailure;

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

    Future<Result<void, SecretFailure>> open() => datasource.createFromSecret(
      network: SpNetwork.signet,
      secret: secret,
      blindbitUrl: 'http://127.0.0.1:1',
      electrumUrl: '',
      dataDir: scratch.path,
      fetchConcurrencyFactor: 1,
      matchConcurrencyFactor: 1,
      headerCheckpoint: null,
    );

    expect(await open(), isA<Ok<void, SecretFailure>>());
    final address = datasource.spAddress();
    await datasource.dispose();
    expect(datasource.hasSession, isFalse);

    // No repository lock-file deletion, sleep, GC request, or retry: reopening
    // must be safe as soon as the public datasource disposal completes.
    expect(await open(), isA<Ok<void, SecretFailure>>());
    expect(datasource.hasSession, isTrue);
    expect(datasource.spAddress() == address, isTrue);
  });
}
