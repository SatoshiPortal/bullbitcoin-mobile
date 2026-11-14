// Run explicitly against a disposable local Nigiri instance; not a unit test.
import 'package:transaction_sync/src/write/spend_gate_store_datasource.dart';
import 'package:transaction_sync/src/read/persisted_wallet_readiness.dart';
import 'package:transaction_sync/src/write/native_store_paths.dart';
import 'package:transaction_sync/src/write/native_wallet_writer_repository.dart';
import 'package:transaction_sync/src/write/revision_store_datasource.dart';
import 'package:transaction_sync/src/write/sqlite_wallet_revision_reader.dart';
import 'dart:convert';
import 'dart:io';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/read.dart';
import 'package:transaction_sync/transaction_sync.dart';

import '../test/support/connections.dart';
import '../test/support/regtest_wallet.dart';

void main() {
  test(
    'Nigiri funds, sends, syncs and reopens a Bitcoin regtest wallet',
    () async {
      final directory = Directory.systemTemp.createTempSync('nigiri-regtest-');
      final descriptor = regtestDescriptor();
      final key = descriptor.key;
      final catalog = SingleWalletCatalog(descriptor);
      final revisions = RevisionStoreDatasource.openForeground(
        revisionStorePath(directory.path),
      );
      SpendGateStoreDatasource.provision(spendGateStorePath(directory.path));
      final writer = NativeWalletWriterRepository(
        revisions: revisions,
        reader: SqliteWalletRevisionReader(revisions),
        documentsDirectory: directory.path,
        catalog: catalog,
        reservedAddresses: NoReservedAddresses(),
      );
      final sync = ElectrumSync(
        connections: FixtureConnections([
          const String.fromEnvironment(
            'NIGIRI_ELECTRUM',
            defaultValue: 'tcp://127.0.0.1:50000',
          ),
        ]),
        documentsDirectory: () async => directory.path,
        readRevision: SqliteWalletRevisionReader(revisions).read,
      );
      WalletSnapshotReader reader() => WalletSnapshotReader(
        documentsDirectory: directory.path,
        readiness: PersistedWalletReadiness(revisions),
        requiredSchemaVersion: writerSchemaVersion,
        revisions: SqliteWalletRevisionReader(revisions),
        liquidAdmission: writer,
      );
      final http = HttpClient();
      try {
        expect(await writer.create(key, expectedGeneration: 0), isA<Ok>());
        final issued = await writer.receive(key, expectedGeneration: 1);
        expect(issued, isA<Ok>());
        final address =
            (issued as Ok<ReceiveAddressIssued, TransactionSyncFailure>)
                .value
                .address;
        expect(address.startsWith('bcrt1'), isTrue);
        final request = await http.postUrl(
          Uri.parse(
            const String.fromEnvironment(
              'NIGIRI_FAUCET',
              defaultValue: 'http://127.0.0.1:3000/faucet',
            ),
          ),
        );
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'address': address, 'amount': 0.001}));
        final response = await request.close();
        await response.drain<void>();
        expect(
          response.statusCode,
          200,
          reason: 'local faucet must fund the test wallet',
        );
        // Faucet mining and Electrum indexing are asynchronous, bounded here.
        var funded = false;
        for (var attempt = 0; attempt < 20; attempt++) {
          expect(await sync.execute(descriptor, discover: true), isA<Ok>());
          final loaded = await reader().bitcoin(descriptor);
          expect(loaded, isA<Ok>());
          final wallet =
              (loaded
                      as Ok<
                        WalletReadSnapshot<bdk.Wallet>,
                        TransactionSyncFailure
                      >)
                  .value
                  .wallet;
          expect(wallet.network(), bdk.Network.regtest);
          final balance = wallet.balance();
          funded = balance.total.toSat() > 0;
          for (final amount in [
            balance.immature,
            balance.trustedPending,
            balance.untrustedPending,
            balance.confirmed,
            balance.trustedSpendable,
            balance.total,
          ]) {
            amount.dispose();
          }
          if (funded) break;
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        expect(
          funded,
          isTrue,
          reason: 'funding must be observed through the writer and reader',
        );
        // A fresh reader hydrates the persisted store, not a prior in-memory view.
        final reopened = await reader().bitcoin(descriptor);
        expect(reopened, isA<Ok>());
        final snapshot =
            (reopened
                    as Ok<
                      WalletReadSnapshot<bdk.Wallet>,
                      TransactionSyncFailure
                    >)
                .value;
        expect(snapshot.wallet.transactions(), isNotEmpty);
        expect(snapshot.stale, isFalse);
        final transactionId = _sendToSelf(snapshot.wallet, address);
        var broadcastObserved = false;
        for (var attempt = 0; attempt < 20; attempt++) {
          expect(await sync.execute(descriptor, discover: true), isA<Ok>());
          final result = await reader().bitcoin(descriptor);
          expect(result, isA<Ok>());
          final wallet =
              (result
                      as Ok<
                        WalletReadSnapshot<bdk.Wallet>,
                        TransactionSyncFailure
                      >)
                  .value
                  .wallet;
          for (final tx in wallet.transactions()) {
            final txid = tx.transaction.computeTxid();
            broadcastObserved |= txid.toString() == transactionId;
            txid.dispose();
            tx.transaction.dispose();
          }
          if (broadcastObserved) break;
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        expect(
          broadcastObserved,
          isTrue,
          reason: 'broadcast must survive a writer sync and fresh reader',
        );
        expect(
          await sync.execute(
            descriptor,
            headless: true,
            allowInitialScan: false,
          ),
          isA<Ok>(),
        );
      } finally {
        http.close(force: true);
        revisions.close();
        directory.deleteSync(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

// Test-only signer for the published vector; never opens or persists a user store.
String _sendToSelf(bdk.Wallet reader, String destination) {
  final address = bdk.Address(
    address: destination,
    network: bdk.Network.regtest,
  );
  final script = address.scriptPubkey();
  final amount = bdk.Amount.fromSat(satoshi: 10000);
  final rate = bdk.FeeRate.fromSatPerVb(satVb: 2);
  final builder = bdk.TxBuilder();
  final recipient = builder.addRecipient(script: script, amount: amount);
  final priced = recipient.feeRate(feeRate: rate);
  final psbt = priced.finish(wallet: reader);
  final mnemonic = bdk.Mnemonic.fromString(
    mnemonic:
        'abandon abandon abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon about',
  );
  final secret = bdk.DescriptorSecretKey(
    networkKind: bdk.NetworkKind.test,
    mnemonic: mnemonic,
    password: null,
  );
  final external = bdk.Descriptor.newBip84(
    secretKey: secret,
    keychainKind: bdk.KeychainKind.external_,
    networkKind: bdk.NetworkKind.test,
  );
  final internal = bdk.Descriptor.newBip84(
    secretKey: secret,
    keychainKind: bdk.KeychainKind.internal,
    networkKind: bdk.NetworkKind.test,
  );
  final persister = bdk.Persister.newInMemory();
  final signer = bdk.Wallet(
    descriptor: external,
    changeDescriptor: internal,
    network: bdk.Network.regtest,
    persister: persister,
    lookahead: 25,
  );
  try {
    expect(signer.sign(psbt: psbt, signOptions: null), isTrue);
    final tx = psbt.extractTx();
    final client = bdk.ElectrumClient(
      url: const String.fromEnvironment(
        'NIGIRI_ELECTRUM',
        defaultValue: 'tcp://127.0.0.1:50000',
      ),
      socks5: null,
      timeout: 5,
      retry: 0,
      validateDomain: false,
    );
    try {
      final txid = client.transactionBroadcast(tx: tx);
      try {
        return txid.toString();
      } finally {
        txid.dispose();
      }
    } finally {
      client.dispose();
      tx.dispose();
    }
  } finally {
    signer.dispose();
    persister.dispose();
    external.dispose();
    internal.dispose();
    secret.dispose();
    mnemonic.dispose();
    psbt.dispose();
    priced.dispose();
    recipient.dispose();
    builder.dispose();
    rate.dispose();
    amount.dispose();
    script.dispose();
    address.dispose();
  }
}
