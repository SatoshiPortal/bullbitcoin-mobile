import 'dart:io';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/electrum_sync_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PublicBdkWalletModel wallet;
  late BdkWalletDatasource datasource;
  late ElectrumSyncServer server;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bdk_sync_cache_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async {
            return call.method == 'getApplicationDocumentsDirectory'
                ? directory.path
                : null;
          },
        );
    final key = bdk.DescriptorSecretKey(
      networkKind: bdk.NetworkKind.test,
      mnemonic: bdk.Mnemonic.fromString(mnemonic: testMnemonic),
      password: null,
    );
    wallet =
        WalletModel.publicBdk(
              id: 'sync-cache-test',
              externalDescriptor: bdk.Descriptor.newBip84(
                secretKey: key,
                keychainKind: bdk.KeychainKind.external_,
                networkKind: bdk.NetworkKind.test,
              ).toString(),
              internalDescriptor: bdk.Descriptor.newBip84(
                secretKey: key,
                keychainKind: bdk.KeychainKind.internal,
                networkKind: bdk.NetworkKind.test,
              ).toString(),
              isTestnet: true,
            )
            as PublicBdkWalletModel;
    final bdkWallet = await BdkFacade.createWallet(wallet);
    // Leave index 5 unrevealed: only a discovery scan can find its history.
    final receivingScript = bdkWallet
        .peekAddress(keychain: bdk.KeychainKind.external_, index: 5)
        .address
        .scriptPubkey();
    await BdkFacade.saveWallet(bdkWallet, wallet.hexId);
    server = await ElectrumSyncServer.start(receivingScript);
    datasource = BdkWalletDatasource();
  });

  tearDown(() async {
    await datasource.dispose();
    await server.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await directory.delete(recursive: true);
  });

  Future<void> sync() =>
      datasource.sync(wallet: wallet, electrumServer: server.connection);

  test(
    'a recreated database is rediscovered during an automatic sync',
    () async {
      await sync();
      final database = File(await BdkFacade.databasePathFor(wallet.hexId));
      await database.writeAsString('corrupt SQLite fixture', flush: true);
      server.requestedScripts.clear();
      await sync().timeout(const Duration(seconds: 10));
      expect(server.requestedScripts, contains(server.scriptHash));
      final restored = await BdkFacade.createWallet(wallet);
      try {
        expect(
          restored.listOutput().map(
            (output) => output.outpoint.txid.toString(),
          ),
          contains(server.txid),
        );
      } finally {
        restored.dispose();
      }
    },
  );

  test(
    'explicit discovery scans unrevealed scripts after a warm sync',
    () async {
      await sync();
      final restored = await BdkFacade.createWallet(wallet);
      late String unused;
      try {
        unused = scriptHashFor(
          restored
              .peekAddress(keychain: bdk.KeychainKind.external_, index: 8)
              .address
              .scriptPubkey(),
        );
      } finally {
        restored.dispose();
      }
      server.requestedScripts.clear();
      await sync();
      expect(server.requestedScripts, isNot(contains(unused)));
      await datasource.sync(
        wallet: wallet,
        electrumServer: server.connection,
        fullDiscovery: true,
      );
      expect(server.requestedScripts, contains(unused));
      server.requestedScripts.clear();
      await sync();
      expect(server.requestedScripts, isNot(contains(unused)));
    },
  );

  test(
    'a stop gap change repeats discovery before returning to incremental sync',
    () async {
      await sync();
      final initial = server.connection;
      final restored = await BdkFacade.createWallet(wallet);
      try {
        for (final gap in [40, 10]) {
          final unused = scriptHashFor(
            restored
                .peekAddress(
                  keychain: bdk.KeychainKind.external_,
                  index: gap == 40 ? 30 : 8,
                )
                .address
                .scriptPubkey(),
          );
          final changed = ElectrumConnection(
            url: initial.url,
            retry: initial.retry,
            timeout: initial.timeout,
            stopGap: gap,
            validateDomain: initial.validateDomain,
            isCustom: initial.isCustom,
            socks5: initial.socks5,
          );
          server.requestedScripts.clear();
          await datasource.sync(wallet: wallet, electrumServer: changed);
          expect(
            server.requestedScripts,
            contains(unused),
            reason: 'Changing the stop gap must trigger fresh discovery',
          );
          server.requestedScripts.clear();
          await datasource.sync(wallet: wallet, electrumServer: changed);
          expect(
            server.requestedScripts,
            isNot(contains(unused)),
            reason: 'An unchanged stop gap must return to incremental sync',
          );
        }
      } finally {
        restored.dispose();
      }
    },
  );
}
