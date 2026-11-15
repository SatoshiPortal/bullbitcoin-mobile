import 'dart:typed_data';

import 'package:bitcoin_base/bitcoin_base.dart' as btc;
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

/// A pure-Dart [PayjoinCodecPort] for protocol tests. The app serves the port
/// from sync; this double keeps the package's tests free of native wallet code.
final class TestPayjoinCodec implements PayjoinCodecPort {
  const TestPayjoinCodec();

  @override
  PayjoinTransaction decodeTransaction(Uint8List bytes) {
    final btc.BtcTransaction transaction;
    try {
      transaction = btc.BtcTransaction.deserialize(bytes);
    } catch (_) {
      throw const FormatException('Not a Bitcoin transaction');
    }
    return _map(transaction);
  }

  @override
  PayjoinTransaction decodePsbt(String psbt) {
    final btc.BtcTransaction transaction;
    try {
      transaction = btc.Psbt.fromBase64(psbt).global.entries
          .whereType<btc.PsbtGlobalUnsignedTransaction>()
          .single
          .transaction;
    } catch (_) {
      throw const FormatException('Not a PSBT');
    }
    return _map(transaction);
  }

  @override
  Uint8List? addressScript(String address, BitcoinNetwork network) {
    final native = switch (network) {
      BitcoinNetwork.mainnet => btc.BitcoinNetwork.mainnet,
      BitcoinNetwork.testnet => btc.BitcoinNetwork.testnet,
      BitcoinNetwork.signet || BitcoinNetwork.regtest => null,
    };
    if (native == null) return null;
    try {
      return Uint8List.fromList(
        btc.BitcoinAddress(
          address,
          network: native,
        ).baseAddress.toScriptPubKey().toBytes(),
      );
    } catch (_) {
      return null;
    }
  }

  static PayjoinTransaction _map(btc.BtcTransaction transaction) =>
      PayjoinTransaction(
        txid: transaction.txId(),
        inputs: [
          for (final input in transaction.inputs)
            (txId: input.txId, vout: input.txIndex),
        ],
        outputs: [
          for (final output in transaction.outputs)
            PayjoinTransactionOutput(
              value: Sats(output.amount),
              scriptPubkey: Uint8List.fromList(output.scriptPubKey.toBytes()),
            ),
        ],
      );
}
