import 'dart:typed_data';

import 'package:bb_mobile/core/transactions/domain/entities/bitcoin_transaction.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart' as btc_utils;
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:convert/convert.dart';

/// Maps the BDK utility class [btc_utils.BitcoinTx] to the domain entity
/// [BitcoinTransaction].
class TransactionMapper {
  /// Convert a [btc_utils.BitcoinTx] utility class to a [BitcoinTransaction]
  /// domain entity.
  ///
  /// When [isTestnet] is provided, scriptPubKey bytes are decoded to a
  /// human-readable address via `bdk.Address.fromScript`. If decoding fails
  /// (e.g. non-standard script), the address field is left `null`.
  static BitcoinTransaction fromBitcoinTx(
    btc_utils.BitcoinTx bitcoinTx, {
    bool isTestnet = false,
  }) {
    return BitcoinTransaction(
      txid: bitcoinTx.txid,
      version: bitcoinTx.version,
      size: bitcoinTx.size.toInt(),
      vsize: bitcoinTx.vsize.toInt(),
      locktime: bitcoinTx.locktime,
      inputs: bitcoinTx.vin.map(_mapBitcoinInput).toList(),
      outputs: bitcoinTx.vout
          .asMap()
          .entries
          .map(
            (entry) =>
                _mapBitcoinOutput(entry.value, entry.key, isTestnet: isTestnet),
          )
          .toList(),
    );
  }

  static BitcoinTxInput _mapBitcoinInput(btc_utils.TxVin vin) {
    return BitcoinTxInput(
      previousTxId: vin.txid,
      previousVout: vin.vout,
      sequence: vin.sequence,
      scriptSigBytes: vin.scriptSig?.bytes,
    );
  }

  static BitcoinTxOutput _mapBitcoinOutput(
    btc_utils.TxVout vout,
    int index, {
    bool isTestnet = false,
  }) {
    String? address;
    try {
      address = bdk.Address.fromScript(
        script: bdk.Script(
          rawOutputScript: Uint8List.fromList(vout.scriptPubKey.bytes),
        ),
        network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
      ).toString();
    } catch (_) {
      // Non-standard or unrecognized script — address left null
    }

    return BitcoinTxOutput(
      valueSat: vout.value.toInt(),
      index: index,
      address: address,
      scriptPubKeyHex: hex.encode(vout.scriptPubKey.bytes),
      scriptPubKeyBytes: vout.scriptPubKey.bytes,
    );
  }
}
