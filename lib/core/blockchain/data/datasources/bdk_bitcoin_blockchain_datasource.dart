import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/utils/bitcoin_signer_result.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

class BdkBitcoinBlockchainDatasource {
  const BdkBitcoinBlockchainDatasource();

  Future<({int height, int medianTimePast})> getChainTip({
    required ElectrumConnection connection,
  }) => Isolate.run(() {
    bdk.ElectrumClient buildClient() => bdk.ElectrumClient(
      url: connection.url,
      socks5: connection.socks5?.isNotEmpty == true ? connection.socks5 : null,
      timeout: connection.effectiveTimeout.clamp(0, 255),
      retry: connection.retry.clamp(0, 255),
      validateDomain: connection.validateDomain,
    );

    late final bdk.ElectrumClient blockchain;
    try {
      blockchain = buildClient();
    } on bdk.CouldNotCreateConnectionElectrumException catch (error) {
      if (!error.errorMessage.contains('Failed to install CryptoProvider')) {
        rethrow;
      }
      blockchain = buildClient();
    }
    try {
      final tip = blockchain.blockHeadersSubscribe();
      final timestamps = <int>[];
      for (
        var height = max(0, tip.height - 10);
        height < tip.height;
        height++
      ) {
        timestamps.add(blockchain.blockHeader(height: height).time);
      }
      timestamps.add(tip.header.time);
      timestamps.sort();
      return (
        height: tip.height,
        medianTimePast: timestamps[timestamps.length ~/ 2],
      );
    } finally {
      blockchain.dispose();
    }
  });

  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required ElectrumConnection connection,
  }) async {
    final blockchain = await _createClient(connection);
    final psbt = bdk.Psbt(psbtBase64: normalizeBitcoinPsbt(finalizedPsbt));
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

  static Future<bdk.ElectrumClient> _createClient(
    ElectrumConnection connection,
  ) async => bdk.ElectrumClient(
    url: connection.url,
    socks5: connection.socks5?.isNotEmpty == true ? connection.socks5 : null,
    // electrum-client caps timeout/retry at u8 (255s, 255 retries).
    timeout: connection.effectiveTimeout.clamp(0, 255),
    retry: connection.retry.clamp(0, 255),
    validateDomain: connection.validateDomain,
  );
}
