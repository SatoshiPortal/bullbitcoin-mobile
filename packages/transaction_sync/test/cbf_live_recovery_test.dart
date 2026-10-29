// Public watch-only BIP84 account fixture. Opt-in only: this test deliberately compares CBF with Electrum; production CBF routing never calls Electrum.
import 'dart:convert';
import 'dart:io';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'public account recovery equals Electrum above a recent checkpoint',
    () async {
      final fixture = File('test/fixtures/cbf_public_descriptors.json');
      final descriptors =
          jsonDecode(
                await (fixture.existsSync()
                        ? fixture
                        : File(
                            'packages/transaction_sync/test/fixtures/cbf_public_descriptors.json',
                          ))
                    .readAsString(),
              )
              as Map<String, dynamic>;
      final directory = await Directory.systemTemp.createTemp(
        'cbf-live-public-',
      );
      final metadata = await SqliteWalletSyncMetadataStore.open(
        databasePath: '${directory.path}/metadata.sqlite',
      );
      final coordinator = DurableWalletSourceOperationCoordinator(
        databasePath: '${directory.path}/coordination.sqlite',
      );
      final facade = WalletTransactionSyncFacade.bdkElectrum(
        metadata: metadata,
        coordinator: coordinator,
      );
      final checkpoint = BitcoinSyncCheckpoint(
        height: 970580,
        blockHash:
            '00000000000000000001a1d86e430271dbad29d3e9693098f9b378d0eb1c9aeb',
      );
      const key = WalletNetworkKey(
        'public-bip84-account-zero',
        'bitcoin',
        'mainnet',
      );
      final configuration = BdkCbfConfiguration(
        externalPublicDescriptor: descriptors['external'] as String,
        internalPublicDescriptor: descriptors['internal'] as String,
        isTestnet: false,
        databaseFilePath: '${directory.path}/wallet.sqlite',
        checkpoint: checkpoint,
        deadline: DateTime.now().toUtc().add(const Duration(minutes: 4)),
      );
      final registration = WalletSourceRegistration.withFingerprint(
        key: key,
        sourceKind: 'bdk_electrum',
        configuration: configuration,
      );
      final timer = Stopwatch()..start();
      try {
        final result = await facade.synchronizeWallet(
          SynchronizeWalletRequest(registration),
        );
        final outcome = switch (result) {
          Ok(:final value) => value,
          Err(:final failure) => throw StateError(
            'Public CBF test failed: ${failure.runtimeType}',
          ),
        };
        final cbfSeconds = timer.elapsedMilliseconds / 1000;
        final cbfIds = outcome.snapshot.transactions
            .where((tx) => tx.position is AnchoredPosition)
            .map((tx) => tx.txid)
            .toSet();
        expect(
          await metadata.isCbfDiscoveryComplete(
            key,
            configuration.scanPolicyFingerprint,
          ),
          isTrue,
        );
        final external = bdk.Descriptor(
          descriptor: configuration.externalPublicDescriptor,
          networkKind: bdk.NetworkKind.main,
        );
        final internal = bdk.Descriptor(
          descriptor: configuration.internalPublicDescriptor,
          networkKind: bdk.NetworkKind.main,
        );
        final persister = bdk.Persister.newInMemory();
        final wallet = bdk.Wallet(
          descriptor: external,
          changeDescriptor: internal,
          network: bdk.Network.bitcoin,
          persister: persister,
          lookahead: 1000,
        );
        final client = bdk.ElectrumClient(
          url: 'ssl://wes.bullbitcoin.com:50002',
          socks5: null,
          timeout: 20,
          retry: 1,
          validateDomain: true,
        );
        try {
          final builder = wallet.startFullScan();
          final request = builder.build();
          try {
            final update = client.fullScan(
              request: request,
              stopGap: 1000,
              batchSize: 1000,
              fetchPrevTxouts: true,
            );
            try {
              wallet.applyUpdate(update: update);
            } finally {
              update.dispose();
            }
          } finally {
            request.dispose();
            builder.dispose();
          }
          final expected = <String>{};
          for (final tx in wallet.transactions()) {
            if (tx.chainPosition case bdk.ConfirmedChainPosition(
              :final confirmationBlockTime,
            )) {
              if (confirmationBlockTime.blockId.height > checkpoint.height) {
                final txid = tx.transaction.computeTxid();
                try {
                  expected.add(txid.toString());
                } finally {
                  txid.dispose();
                }
              }
            }
          }
          // On failure, print counts only; never emit the transaction set.
          expect(cbfIds.difference(expected).length, 0);
          expect(expected.difference(cbfIds).length, 0);
          expect(expected.isNotEmpty, isTrue);
          // ignore: avoid_print
          print(
            'CBF_LIVE recovery_seconds=$cbfSeconds cbf_tx_count=${cbfIds.length} electrum_range_tx_count=${expected.length} matched=true checkpoint_height=${checkpoint.height}',
          );
          // Same persisted state must now admit background catch-up.
          final warm = await facade.synchronizeWallet(
            SynchronizeWalletRequest(registration, allowInitialScan: false),
          );
          expect(
            warm
                is Ok<
                  WalletTransactionSyncOutcome,
                  WalletTransactionSyncFailure
                >,
            isTrue,
          );
        } finally {
          client.dispose();
          wallet.dispose();
          persister.dispose();
          external.dispose();
          internal.dispose();
        }
      } finally {
        await facade.dispose();
        await metadata.close();
        await directory.delete(recursive: true);
      }
    },
    skip: Platform.environment['CBF_LIVE_TESTS'] != '1',
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
