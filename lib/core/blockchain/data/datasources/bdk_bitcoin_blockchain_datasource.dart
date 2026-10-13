import 'dart:isolate';
import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

class BdkBitcoinBlockchainDatasource {
  const BdkBitcoinBlockchainDatasource();

  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required ElectrumConnection connection,
  }) async {
    final blockchain = await _createClient(connection);
    final psbt = bdk.Psbt(psbtBase64: finalizedPsbt);
    final tx = psbt.extractTx();
    final txId = blockchain.transactionBroadcast(tx: tx);
    return txId.toString();
  }

  Future<String> broadcastTransaction(
    Uint8List transaction, {
    required ElectrumConnection connection,
  }) async {
    final blockchain = await _createClient(connection);
    final tx = bdk.Transaction(transactionBytes: transaction);
    final txId = blockchain.transactionBroadcast(tx: tx);
    return txId.toString();
  }

  /// Whether the server knows [txId], in its mempool or in a block.
  ///
  /// One `blockchain.transaction.get` round trip instead of a wallet sync.
  /// Answers `false` only on the server's explicit "unknown transaction"
  /// reply; any other failure throws, so an unreachable server is never
  /// mistaken for an absent transaction.
  Future<bool> isTransactionKnown(
    String txId, {
    required ElectrumConnection connection,
  }) {
    final url = connection.url;
    final socks5 = connection.socks5?.isNotEmpty == true
        ? connection.socks5
        : null;
    final timeout = connection.effectiveTimeout.clamp(0, 255);
    final retry = connection.retry.clamp(0, 255);
    final validateDomain = connection.validateDomain;
    // The FFI call blocks for a full network round trip: keep it off the UI
    // isolate.
    return Isolate.run(() {
      bdk.ElectrumClient buildClient() => bdk.ElectrumClient(
        url: url,
        socks5: socks5,
        timeout: timeout,
        retry: retry,
        validateDomain: validateDomain,
      );

      late final bdk.ElectrumClient client;
      try {
        client = buildClient();
      } on bdk.CouldNotCreateConnectionElectrumException catch (error) {
        if (!error.errorMessage.contains('Failed to install CryptoProvider')) {
          rethrow;
        }
        // Concurrent BDK isolates can race while installing rustls' global
        // provider. The winner has installed it by the time this retry runs.
        client = buildClient();
      }
      try {
        client.transactionGetRaw(txid: bdk.Txid.fromString(hex: txId));
        return true;
      } on bdk.ProtocolElectrumException catch (error) {
        if (isUnknownTransactionReply(error.errorMessage)) return false;
        rethrow;
      } finally {
        client.dispose();
      }
    });
  }

  /// Recognizes the "unknown transaction" replies of the Electrum servers we
  /// ship: electrs and esplora answer `missing transaction`, Fulcrum relays
  /// bitcoind's `No such mempool or blockchain transaction`.
  static bool isUnknownTransactionReply(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('missing transaction') ||
        normalized.contains('no such mempool or blockchain transaction');
  }

  static Future<bdk.ElectrumClient> _createClient(
    ElectrumConnection connection,
  ) async {
    return bdk.ElectrumClient(
      url: connection.url,
      socks5: connection.socks5?.isNotEmpty == true ? connection.socks5 : null,
      // electrum-client caps timeout/retry at u8 (255s, 255 retries).
      timeout: connection.effectiveTimeout.clamp(0, 255),
      retry: connection.retry.clamp(0, 255),
      validateDomain: connection.validateDomain,
    );
  }
}
