// Runtime proof of the BDK source adapter against a REAL in-process BDK
// wallet — no network, no mocks around the SDK. The wallet is seeded offline
// by hand-crafting a raw funding transaction and applying it through
// `applyUnconfirmedTxs`, the standard deterministic way to fund a BDK wallet
// in tests (same technique as the app's bdk_wallet_datasource_test).
import 'dart:io';
import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

import 'support/fakes.dart';

// The canonical BIP39 test mnemonic. Public knowledge, no funds.
const _testMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

const _fundingLargeSat = 200000;
const _fundingSmallSat = 30000;

Uint8List _leUint32(int value) {
  final bytes = ByteData(4)..setUint32(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}

Uint8List _leUint64(int value) {
  final bytes = ByteData(8)..setUint64(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}

Uint8List _varInt(int value) {
  if (value < 0xfd) return Uint8List.fromList([value]);
  throw UnimplementedError('larger varints not needed here');
}

/// Minimal legacy-serialized transaction with one throwaway input and the
/// given outputs; `applyUnconfirmedTxs` does not validate inputs.
Uint8List _buildFundingTx(List<({bdk.Script script, int amountSat})> outputs) {
  final bytes = BytesBuilder();
  bytes.add(_leUint32(2)); // version
  bytes.add(_varInt(1)); // input count
  bytes.add(Uint8List(32)); // prev txid (null)
  bytes.add(_leUint32(0xffffffff)); // prev vout
  bytes.add(_varInt(0)); // empty scriptSig
  bytes.add(_leUint32(0xffffffff)); // sequence
  bytes.add(_varInt(outputs.length));
  for (final output in outputs) {
    bytes.add(_leUint64(output.amountSat));
    final script = output.script.toBytes();
    bytes.add(_varInt(script.length));
    bytes.add(script);
  }
  bytes.add(_leUint32(0)); // locktime
  return bytes.toBytes();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late BdkElectrumConfiguration configuration;
  late WalletSourceRegistration registration;
  late String fundingTxid;

  const key = WalletNetworkKey('bdk-adapter-test', 'bitcoin', 'testnet');
  // Must match the adapter's persister naming contract.
  const persisterFileName = 'bdk-adapter-test_bitcoin_testnet_bdk_dart';

  (String, String) deriveDescriptors() {
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
    return (external.toString(), internal.toString());
  }

  /// Creates and funds the persisted wallet exactly where the adapter will
  /// open it, through an independent BDK instance (cross-instance
  /// persistence is part of what this proves).
  Future<String> seedFundedWallet() async {
    final persister = bdk.Persister.newSqlite(
      path: '${tempDir.path}/$persisterFileName',
    );
    final external = bdk.Descriptor(
      descriptor: configuration.externalPublicDescriptor,
      networkKind: bdk.NetworkKind.test,
    );
    final internal = bdk.Descriptor(
      descriptor: configuration.internalPublicDescriptor,
      networkKind: bdk.NetworkKind.test,
    );
    final wallet = bdk.Wallet(
      descriptor: external,
      changeDescriptor: internal,
      network: bdk.Network.testnet,
      persister: persister,
      lookahead: configuration.stopGap,
    );
    final addr0 = wallet.revealNextAddress(
      keychain: bdk.KeychainKind.external_,
    );
    final addr1 = wallet.revealNextAddress(
      keychain: bdk.KeychainKind.external_,
    );
    final fundingTx = bdk.Transaction(
      transactionBytes: _buildFundingTx([
        (script: addr0.address.scriptPubkey(), amountSat: _fundingLargeSat),
        (script: addr1.address.scriptPubkey(), amountSat: _fundingSmallSat),
      ]),
    );
    final txid = fundingTx.computeTxid().toString();
    wallet.applyUnconfirmedTxs(
      unconfirmedTxs: [
        bdk.UnconfirmedTx(
          tx: fundingTx,
          lastSeen: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        ),
      ],
    );
    expect(wallet.listUnspent(), hasLength(2), reason: 'seeding failed');
    wallet.persist(
      persister: bdk.Persister.newSqlite(
        path: '${tempDir.path}/$persisterFileName',
      ),
    );
    wallet.dispose();
    return txid;
  }

  WalletTransactionSyncFacade buildBdkFacade(RecordingMetadata metadata) =>
      WalletTransactionSyncFacade.bdkElectrum(
        metadata: metadata,
        coordinator: InMemoryWalletSourceOperationCoordinator(),
      );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wts_bdk_adapter_');
    final (external, internal) = deriveDescriptors();
    configuration = BdkElectrumConfiguration(
      externalPublicDescriptor: external,
      internalPublicDescriptor: internal,
      isTestnet: true,
      electrumUrls: const [],
      stopGap: 20,
      validateDomain: true,
      databaseRootPath: tempDir.path,
    );
    registration = WalletSourceRegistration.withFingerprint(
      key: key,
      sourceKind: 'bdk_electrum',
      configuration: configuration,
    );
    fundingTxid = await seedFundedWallet();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test(
    'refreshLocal maps a real persisted BDK wallet through the facade',
    () async {
      final facade = buildBdkFacade(RecordingMetadata());
      final outcome = okValue(
        await facade.refreshLocalSnapshot(
          RefreshLocalSnapshotRequest(registration),
        ),
      );
      final snapshot = outcome.snapshot;
      expect(snapshot.revision, 1);
      expect(snapshot.evidenceLevel, WalletEvidenceLevel.localSourceState);
      expect(snapshot.transactions, hasLength(1));

      final transaction = snapshot.transactions.single;
      expect(transaction.txid, fundingTxid);
      expect(transaction.position, isA<UnconfirmedPosition>());
      expect(transaction.amountSats, _fundingLargeSat + _fundingSmallSat);
      expect(transaction.outputs, hasLength(2));
      expect(
        transaction.outputs.map((output) => output.valueSats),
        containsAll([_fundingLargeSat, _fundingSmallSat]),
      );
      expect(transaction.inputs, hasLength(1));

      final observation = okValue(
        await facade.lookupLocal(
          LookupLocalTransactionRequest(key, fundingTxid),
        ),
      );
      expect(observation!.transaction.txid, fundingTxid);
    },
  );

  test(
    'two local refreshes produce the same fingerprint and revision',
    () async {
      final facade = buildBdkFacade(RecordingMetadata());
      final first = okValue(
        await facade.refreshLocalSnapshot(
          RefreshLocalSnapshotRequest(registration),
        ),
      );
      final second = okValue(
        await facade.refreshLocalSnapshot(
          RefreshLocalSnapshotRequest(registration),
        ),
      );
      expect(
        second.snapshot.contentFingerprint,
        first.snapshot.contentFingerprint,
      );
      expect(second.snapshot.revision, first.snapshot.revision);
    },
  );

  test('deleteWallet removes the persister file idempotently', () async {
    final facade = buildBdkFacade(RecordingMetadata());
    okValue(
      await facade.refreshLocalSnapshot(
        RefreshLocalSnapshotRequest(registration),
      ),
    );
    final file = File('${tempDir.path}/$persisterFileName');
    expect(await file.exists(), isTrue);

    okValue(await facade.deleteWallet(key));
    expect(await file.exists(), isFalse);
    okValue(await facade.deleteWallet(key));
  });

  test('a missing persisted wallet is a typed missing-state failure', () async {
    await File('${tempDir.path}/$persisterFileName').delete();
    final facade = buildBdkFacade(RecordingMetadata());
    expect(
      errFailure(
        await facade.refreshLocalSnapshot(
          RefreshLocalSnapshotRequest(registration),
        ),
      ),
      isA<WalletSourceStateMissingFailure>(),
    );
  });

  test(
    'changing a descriptor changes the fingerprint and mismatches the key',
    () async {
      final metadata = RecordingMetadata();
      metadata.values[key] = WalletSyncMetadata(registration: registration);
      final facade = buildBdkFacade(metadata);

      final otherConfiguration = BdkElectrumConfiguration(
        externalPublicDescriptor: configuration.internalPublicDescriptor,
        internalPublicDescriptor: configuration.externalPublicDescriptor,
        isTestnet: true,
        electrumUrls: const [],
        stopGap: 20,
        validateDomain: true,
        databaseRootPath: tempDir.path,
      );
      final replacement = WalletSourceRegistration.withFingerprint(
        key: key,
        sourceKind: 'bdk_electrum',
        configuration: otherConfiguration,
      );
      expect(
        replacement.configurationFingerprint,
        isNot(registration.configurationFingerprint),
      );
      expect(
        errFailure(
          await facade.refreshLocalSnapshot(
            RefreshLocalSnapshotRequest(replacement),
          ),
        ),
        isA<WalletRegistrationMismatchFailure>(),
      );
    },
  );

  test(
    'backend and storage settings do not affect the identity fingerprint',
    () {
      final movedConfiguration = BdkElectrumConfiguration(
        externalPublicDescriptor: configuration.externalPublicDescriptor,
        internalPublicDescriptor: configuration.internalPublicDescriptor,
        isTestnet: true,
        electrumUrls: const ['ssl://other.example:50002'],
        stopGap: 50,
        validateDomain: false,
        databaseRootPath: '/somewhere/else',
      );
      expect(movedConfiguration.fingerprint, configuration.fingerprint);
    },
  );

  test('registration and configuration never print descriptors', () {
    final printed = '$registration ${registration.configuration}';
    expect(
      printed,
      isNot(contains(configuration.externalPublicDescriptor.substring(0, 20))),
    );
    expect(printed, isNot(contains('tpub')));
  });
}
