import 'package:transaction_sync/src/write/native_store_paths.dart';
import 'package:transaction_sync/src/write/revision_store_datasource.dart';
import 'dart:io';

import 'package:bull_sdk/bull_sdk.dart' show BullSdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

import '../test/support/connections.dart';
import '../test/support/electrum_fixture.dart';

// Explicit native integration suite: requires bull_sdk's host shared library on the loader path. It is not built by flutter test's BDK native asset hook.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Liquid worker uses direct access despite SOCKS and stops fallback after open',
    () async {
      await BullSdk.init();
      final dir = Directory.systemTemp.createTempSync('liquid_writer_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final fixture = await ElectrumFixture.start({
        for (var index = 0; index < 6; index++) 'ext$index': '51',
        for (var index = 0; index < 3; index++) 'int$index': '51',
      });
      addTearDown(fixture.close);
      await fixture.load('S10-no-change', 0);
      final key = WalletKey(
        id: 'liquid-fixture',
        network: LiquidNetwork.testnet,
      );
      final nativeDescriptor = await lwk.Descriptor.newConfidential(
        network: lwk.LiquidNetwork.testnet,
        mnemonic:
            'abandon abandon abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon about',
      );
      final native = await lwk.Wallet.init(
        network: lwk.LiquidNetwork.testnet,
        dbpath: nativeWalletStoragePath(dir.path, key),
        descriptor: nativeDescriptor,
      );
      native.dispose();
      final liquid = LiquidWalletDescriptor(
        key: key,
        scriptType: ScriptType.bip84,
        origin: 'fixture',
        combinedCtDescriptor: nativeDescriptor.ctDescriptor,
      );
      final connections = FixtureConnections([
        'tcp://127.0.0.1:0',
        fixture.url,
        fixture.url,
      ], socks5: '127.0.0.1:1');
      final sync = foregroundSync(dir.path, connections);
      final metadata = RevisionStoreDatasource.openForeground(
        revisionStorePath(dir.path),
      );
      metadata.close();
      // The Bitcoin fixture deliberately cannot serve Liquid headers. The error must occur inside sync_, after successful worker initialization.
      final result = await sync.execute(liquid);
      expect(result, isA<Err<SyncCompletion, TransactionSyncFailure>>());
      if (result case Err(:final failure)) {
        expect(failure, isA<TransactionSyncConnectionFailure>());
      }
      expect(connections.attempts, 2);
    },
  );
}
