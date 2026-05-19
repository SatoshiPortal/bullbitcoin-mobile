import 'dart:typed_data';

import 'package:bb_mobile/core/transactions/domain/entity/bitcoin_transaction.dart';
import 'package:bb_mobile/core/transactions/domain/entity/liquid_transaction.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart' as btc_utils;
import 'package:bb_mobile/core/utils/liquid_tx.dart' as liq_utils;
import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:convert/convert.dart';

/// Maps between the existing utility classes ([BitcoinTx], [LiquidTx])
/// and the new domain entities ([BitcoinTransaction], [LiquidTransaction]).
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
      inputs: bitcoinTx.vin.map((vin) => _mapBitcoinInput(vin)).toList(),
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

  /// Convert a [liq_utils.LiquidTx] utility class to a [LiquidTransaction]
  /// domain entity.
  static LiquidTransaction fromLiquidTx(liq_utils.LiquidTx liquidTx) {
    return LiquidTransaction(
      txid: liquidTx.txid,
      version: liquidTx.version,
      vsize: liquidTx.vsize.toInt(),
      weight: liquidTx.weight.toInt(),
      locktime: liquidTx.locktime,
      feeSat: liquidTx.fee.toInt(),
      inputs: liquidTx.vin.map((vin) => _mapLiquidInput(vin)).toList(),
      outputs: liquidTx.vout
          .asMap()
          .entries
          .map((entry) => _mapLiquidOutput(entry.value, entry.key))
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

  static LiquidTxInput _mapLiquidInput(liq_utils.LiquidTxVin vin) {
    return LiquidTxInput(
      previousTxId: vin.txid,
      previousVout: vin.vout,
      sequence: vin.sequence,
      scriptSig: vin.scriptSig,
      witness: vin.witness,
      isPegin: vin.isPegin,
    );
  }

  static LiquidTxOutput _mapLiquidOutput(
    liq_utils.LiquidTxVout vout,
    int index,
  ) {
    return LiquidTxOutput(
      valueSat: vout.value?.toInt() ?? 0,
      index: index,
      scriptPubKeyHex: vout.scriptPubKey,
      asset: vout.asset,
      nonce: vout.nonce,
    );
  }
}
