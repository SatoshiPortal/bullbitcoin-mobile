import 'dart:async' show TimeoutException;
import 'dart:io';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'cbf_spike_support.dart';

const _mnemonicDefine = String.fromEnvironment('CBF_SPIKE_MNEMONIC');
const _runIdDefine = String.fromEnvironment(
  'CBF_SPIKE_RUN_ID',
  defaultValue: 'default',
);
const _runSpikeDefine = bool.fromEnvironment('RUN_CBF_SPIKE');
const _useRecoveryDefine = bool.fromEnvironment(
  'CBF_SPIKE_RECOVERY',
  defaultValue: true,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final runSpike =
      _runSpikeDefine ||
      Platform.environment['RUN_CBF_SPIKE']?.toLowerCase() == 'true';

  testWidgets(
    'syncs a testnet wallet with compact block filters',
    (tester) async {
      final mnemonic = _mnemonicDefine.isNotEmpty
          ? _mnemonicDefine
          : Platform.environment['CBF_SPIKE_MNEMONIC'];
      if (mnemonic == null || mnemonic.isEmpty) {
        fail(
          'CBF_SPIKE_MNEMONIC is required. Use a dedicated testnet mnemonic; '
          'never use or commit a production secret.',
        );
      }

      final runId = _safeRunId(
        _runIdDefine.isNotEmpty
            ? _runIdDefine
            : Platform.environment['CBF_SPIKE_RUN_ID'] ?? 'default',
      );
      final root = Directory(
        '${Directory.systemTemp.path}/bull-cbf-spike-$runId',
      );
      final cbfDataDir = Directory('${root.path}/filters');
      await cbfDataDir.create(recursive: true);

      final (:wallet, :persister) = await _loadOrCreateWallet(
        mnemonic: mnemonic,
        databasePath: '${root.path}/wallet.sqlite',
      );
      final scanType = _useRecoveryDefine
          ? bdk.RecoveryScanType(
              usedScriptIndex: 100,
              checkpoint: bdk.SegwitActivationRecoveryPoint(),
            )
          : bdk.SyncScanType();
      final components = bdk.CbfBuilder()
          .connections(connections: 2)
          .dataDir(dataDir: cbfDataDir.path)
          .scanType(scanType: scanType)
          .build(wallet: wallet);
      final shutdown = CbfShutdownGuard(components.client.shutdown);
      var receivedInfo = false;

      components.node.run();
      final infoReader = _readInfo(
        components.client,
        onInfo: (event) {
          receivedInfo = true;
          // Only stage, height and percentage are emitted. No wallet or peer data.
          // ignore: avoid_print
          print(
            'CBF_INFO stage=${event.stage.name} '
            'height=${event.chainHeight ?? '-'} '
            'filters=${event.filtersDownloadedPercent ?? '-'}',
          );
        },
      );
      final warningReader = _readWarnings(components.client);

      try {
        final update = await components.client.update().timeout(
          const Duration(minutes: 30),
        );
        wallet.applyUpdate(update: update);
        wallet.persist(persister: persister);

        expect(receivedInfo, isTrue);
        expect(wallet.latestCheckpoint().height, greaterThan(0));
      } finally {
        shutdown.shutdown();
        try {
          await Future.wait([
            infoReader,
            warningReader,
          ]).timeout(const Duration(seconds: 30));
        } on TimeoutException {
          // Upstream peer tasks may outlive CbfNode.shutdown(). The process owns
          // final cleanup; the spike records this as a lifecycle limitation.
        }
      }
    },
    skip: !runSpike,
    timeout: const Timeout(Duration(minutes: 35)),
  );
}

Future<({bdk.Wallet wallet, bdk.Persister persister})> _loadOrCreateWallet({
  required String mnemonic,
  required String databasePath,
}) async {
  final secretKey = bdk.DescriptorSecretKey(
    networkKind: bdk.NetworkKind.test,
    mnemonic: bdk.Mnemonic.fromString(mnemonic: mnemonic),
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
  final walletExists = await File(databasePath).exists();
  final persister = bdk.Persister.newSqlite(path: databasePath);

  if (walletExists) {
    return (
      wallet: bdk.Wallet.load(
        descriptor: external,
        changeDescriptor: internal,
        persister: persister,
        lookahead: 25,
      ),
      persister: persister,
    );
  }

  return (
    wallet: bdk.Wallet(
      descriptor: external,
      changeDescriptor: internal,
      network: bdk.Network.testnet,
      persister: persister,
      lookahead: 25,
    ),
    persister: persister,
  );
}

Future<void> _readInfo(
  bdk.CbfClient client, {
  required void Function(CbfSpikeEvent event) onInfo,
}) async {
  try {
    while (client.isRunning()) {
      onInfo(mapCbfSpikeInfo(await client.nextInfo()));
    }
  } on bdk.NodeStoppedCbfException {
    // Expected when the test shuts down the native node.
  }
}

Future<void> _readWarnings(bdk.CbfClient client) async {
  try {
    while (client.isRunning()) {
      final code = mapCbfSpikeWarning(await client.nextWarning());
      // Warning payloads may contain peer or transaction data; emit code only.
      // ignore: avoid_print
      print('CBF_WARNING code=$code');
    }
  } on bdk.NodeStoppedCbfException {
    // Expected when the test shuts down the native node.
  }
}

String _safeRunId(String value) {
  final sanitized = value.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
  return sanitized.isEmpty ? 'default' : sanitized;
}
