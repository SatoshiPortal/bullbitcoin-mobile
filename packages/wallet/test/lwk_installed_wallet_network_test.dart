import 'dart:io';

import 'package:bull_sdk/bull_sdk.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:wallet/wallet.dart';

import 'support/fakes.dart';

// Public BIP39 vector, never used for funds.
const _mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'a copied LWK installation reopens locally and persists another sync',
    () async {
      await BullSdk.init();
      final temp = await Directory.systemTemp.createTemp('lwk_installation_');
      addTearDown(() => temp.delete(recursive: true));
      final endpoint =
          Platform.environment['LWK_FIXTURE_ELECTRUM_URL'] ??
          'ssl://blockstream.info:465';
      final derived = await lwk.Descriptor.newConfidential(
        network: lwk.LiquidNetwork.testnet,
        mnemonic: _mnemonic,
      );
      // Use a distinct public test branch, not the commonly reused vector's
      // default account. Drop its checksum after changing the derivation path.
      expect(derived.ctDescriptor, contains('/<0;1>/*'));
      final descriptor = lwk.Descriptor(
        ctDescriptor: derived.ctDescriptor
            .split('#')
            .first
            .replaceAll('/<0;1>/*', '/3058/<0;1>/*'),
      );
      const walletId = 'installed-liquid-wallet';
      final original = WalletStoragePaths.inDocuments(
        documentsDirectory: '${temp.path}/original',
        walletId: walletId,
      );
      final copied = WalletStoragePaths.inDocuments(
        documentsDirectory: '${temp.path}/copied',
        walletId: walletId,
      );
      final reference = await lwk.Wallet.init(
        network: lwk.LiquidNetwork.testnet,
        dbpath: original.lwkRoot,
        descriptor: descriptor,
      );
      late final String address;
      try {
        await reference.sync_(
          electrumUrl: endpoint,
          validateDomain: true,
          timeout: 5,
        );
        address = (await reference.addressLastUnused()).confidential;
      } finally {
        reference.dispose();
      }
      final before = await _files(original.lwkRoot);
      expect(
        before,
        isNotEmpty,
        reason: 'the fixture must contain native state',
      );
      for (final name in before.keys) {
        final destination = File('${copied.lwkRoot}/$name');
        await destination.parent.create(recursive: true);
        await File('${original.lwkRoot}/$name').copy(destination.path);
      }
      expect(await _files(copied.lwkRoot), before);
      final registration = WalletSourceRegistration.withFingerprint(
        key: const WalletNetworkKey(walletId, 'liquid', 'testnet'),
        sourceKind: 'lwk_electrum',
        configuration: LwkElectrumConfiguration(
          confidentialPublicDescriptor: descriptor.ctDescriptor,
          isTestnet: true,
          electrumUrls: [endpoint],
          validateDomain: true,
          databaseRootPath: copied.lwkRoot,
          timeout: 5,
        ),
      );
      final facade = WalletTransactionSyncFacade(
        metadata: RecordingMetadata(),
        coordinator: InMemoryWalletSourceOperationCoordinator(),
        source: WalletLocator.lwkElectrum(),
      );
      addTearDown(facade.dispose);

      final local = okValue(
        await facade.refreshLocalSnapshot(
          RefreshLocalSnapshotRequest(registration),
        ),
      );
      expect(local.snapshot.transactions, isEmpty);

      final synced = okValue(
        await facade.synchronizeWallet(SynchronizeWalletRequest(registration)),
      );

      expect(synced.snapshot.transactions, isEmpty);
      expect(await _files(copied.lwkRoot), isNotEmpty);
      final reopened = await lwk.Wallet.init(
        network: lwk.LiquidNetwork.testnet,
        dbpath: copied.lwkRoot,
        descriptor: descriptor,
      );
      try {
        expect((await reopened.addressLastUnused()).confidential, address);
        expect(await reopened.txs(), isEmpty);
      } finally {
        reopened.dispose();
      }
      expect(
        await _files(original.lwkRoot),
        before,
        reason: 'only the installation copy may change',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: Platform.environment['RUN_LWK_NETWORK_FIXTURE'] != '1'
        ? 'Set RUN_LWK_NETWORK_FIXTURE=1 with the pinned bull_sdk native library'
        : false,
  );
}

Future<Map<String, String>> _files(String root) async => {
  await for (final entry in Directory(root).list(recursive: true))
    if (entry is File)
      entry.path.substring(root.length + 1): sha256
          .convert(await entry.readAsBytes())
          .toString(),
};
