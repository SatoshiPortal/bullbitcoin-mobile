// Opt-in real-network proof of the BDK adapter: full discovery of the
// canonical public testnet wallet through the facade, against real Electrum
// servers, with timing measurements for the plan's section 20 protocol.
//
// Run manually with:
//   WTS_NETWORK_TESTS=1 fvm flutter test test/bdk_network_discovery_test.dart
@Timeout(Duration(minutes: 20))
library;

import 'dart:io';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

import 'support/fakes.dart';

const _testMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

const _electrumUrls = [
  'ssl://wes.bullbitcoin.com:60002',
  'ssl://electrum.blockstream.info:60002',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final enabled = Platform.environment['WTS_NETWORK_TESTS'] == '1';

  test(
    'full discovery of the canonical testnet wallet through the package',
    skip: enabled ? false : 'network test, set WTS_NETWORK_TESTS=1',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('wts_bdk_net_');
      addTearDown(() => tempDir.delete(recursive: true));

      final mnemonic = bdk.Mnemonic.fromString(mnemonic: _testMnemonic);
      final secretKey = bdk.DescriptorSecretKey(
        networkKind: bdk.NetworkKind.test,
        mnemonic: mnemonic,
        password: null,
      );
      final external = bdk.Descriptor.newBip84(
        secretKey: secretKey,
        keychainKind: bdk.KeychainKind.external_,
        networkKind: bdk.NetworkKind.test,
      );
      final internal = bdk.Descriptor.newBip84(
        secretKey: secretKey,
        keychainKind: bdk.KeychainKind.internal,
        networkKind: bdk.NetworkKind.test,
      );
      final configuration = BdkElectrumConfiguration(
        externalPublicDescriptor: external.toString(),
        internalPublicDescriptor: internal.toString(),
        isTestnet: true,
        electrumUrls: _electrumUrls,
        stopGap: 20,
        validateDomain: true,
        databaseRootPath: tempDir.path,
      );
      const key = WalletNetworkKey('canonical-testnet', 'bitcoin', 'testnet');
      final registration = WalletSourceRegistration.withFingerprint(
        key: key,
        sourceKind: 'bdk_electrum',
        configuration: configuration,
      );
      final facade = WalletTransactionSyncFacade.bdkElectrum(
        metadata: RecordingMetadata(),
        coordinator: InMemoryWalletSourceOperationCoordinator(),
      );

      final discoverWatch = Stopwatch()..start();
      final discoverResult = await facade.discoverWalletHistory(
        DiscoverWalletHistoryRequest(registration),
      );
      expect(
        errFailureOrNull(discoverResult),
        isNull,
        reason: 'discovery must succeed through the configured servers',
      );
      final discovered = okValue(discoverResult);
      discoverWatch.stop();

      final transactionCount = discovered.snapshot.transactions.length;
      final anchored = discovered.snapshot.transactions
          .where((transaction) => transaction.position is AnchoredPosition)
          .length;
      expect(transactionCount, greaterThan(0));
      expect(anchored, greaterThan(0));
      expect(
        discovered.snapshot.evidenceLevel,
        WalletEvidenceLevel.walletSourceReported,
      );
      expect(discovered.snapshot.sourceTip, isNotNull);

      final listWatch = Stopwatch()..start();
      final page = okValue(
        await facade.listLocal(
          ListLocalTransactionsRequest(key, pageSize: 1000),
        ),
      );
      listWatch.stop();
      expect(page.items, hasLength(transactionCount));

      final lookupWatch = Stopwatch()..start();
      final observation = okValue(
        await facade.lookupLocal(
          LookupLocalTransactionRequest(
            key,
            discovered.snapshot.transactions.first.txid,
          ),
        ),
      );
      lookupWatch.stop();
      expect(observation, isNotNull);

      // Cold local reconstruction (new facade = new process simulation).
      final rebuildFacade = WalletTransactionSyncFacade.bdkElectrum(
        metadata: RecordingMetadata(),
        coordinator: InMemoryWalletSourceOperationCoordinator(),
      );
      final rebuildWatch = Stopwatch()..start();
      final rebuilt = okValue(
        await rebuildFacade.refreshLocalSnapshot(
          RefreshLocalSnapshotRequest(registration),
        ),
      );
      rebuildWatch.stop();
      expect(rebuilt.snapshot.transactions, hasLength(transactionCount));
      expect(
        rebuilt.snapshot.contentFingerprint,
        discovered.snapshot.contentFingerprint,
        reason: 'local reconstruction must reproduce the discovered content',
      );

      final incrementalWatch = Stopwatch()..start();
      final synced = okValue(
        await rebuildFacade.synchronizeWallet(
          SynchronizeWalletRequest(registration),
        ),
      );
      incrementalWatch.stop();
      expect(synced.snapshot.transactions.length, transactionCount);

      // Measurement report (plan section 20). Host-VM numbers, not device
      // numbers — Pixel measurements follow separately.
      // ignore: avoid_print
      print(
        'WTS-MEASURE host-vm corpus=$transactionCount txs '
        'discover=${discoverWatch.elapsedMilliseconds}ms '
        'listLocal=${listWatch.elapsedMilliseconds}ms '
        'lookupLocal=${lookupWatch.elapsedMilliseconds}ms '
        'coldLocalRebuild=${rebuildWatch.elapsedMilliseconds}ms '
        'incrementalSync=${incrementalWatch.elapsedMilliseconds}ms '
        'anchored=$anchored',
      );
    },
  );
}
