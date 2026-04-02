import 'dart:typed_data';

import 'package:bb_mobile/core/transactions/domain/entity/bitcoin_transaction.dart';
import 'package:bb_mobile/core/transactions/domain/entity/liquid_transaction.dart';
import 'package:bb_mobile/core/transactions/domain/entity/transaction.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart' as btc_utils;
import 'package:bb_mobile/core/utils/liquid_tx.dart' as liq_utils;
import 'package:bb_mobile/core/wallet/domain/entities/transaction_input.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
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
    bool? isTestnet,
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

  /// Convert a [WalletTransaction] to a domain [Transaction].
  ///
  /// Uses the wallet's local data (inputs, outputs, vsize, fee) to construct
  /// a [BitcoinTransaction] or [LiquidTransaction] depending on the network.
  ///
  /// Note: The resulting transaction has input values populated from the
  /// wallet's data, and output addresses from the wallet's output entities.
  static Transaction fromWalletTransaction(WalletTransaction walletTx) {
    if (walletTx.isBitcoin) {
      return _walletTxToBitcoin(walletTx);
    } else {
      return _walletTxToLiquid(walletTx);
    }
  }

  static BitcoinTransaction _walletTxToBitcoin(WalletTransaction walletTx) {
    final inputs = walletTx.inputs.map((input) {
      final valueSat = switch (input) {
        BitcoinTransactionInput(:final value) => value?.toInt(),
        LiquidTransactionInput(:final value) => value.toInt(),
      };
      return BitcoinTxInput(
        previousTxId: input.previousTxId,
        previousVout: input.previousTxVout,
        valueSat: valueSat,
        sequence: 0, // Not available from WalletTransaction
        scriptSigBytes: switch (input) {
          BitcoinTransactionInput(:final scriptSig) => scriptSig?.toList(),
          LiquidTransactionInput() => null,
        },
      );
    }).toList();

    final outputs = walletTx.outputs.asMap().entries.map((entry) {
      final i = entry.key;
      final output = entry.value;
      final valueSat = switch (output) {
        BitcoinTransactionOutput(:final value) => value?.toInt() ?? 0,
        LiquidTransactionOutput(:final value) => value.toInt(),
      };
      return BitcoinTxOutput(
        valueSat: valueSat,
        index: i,
        address: switch (output) {
          BitcoinTransactionOutput(:final address) => address,
          LiquidTransactionOutput(:final address) => address,
        },
        scriptPubKeyHex: switch (output) {
          BitcoinTransactionOutput(:final scriptPubkey) => hex.encode(
            scriptPubkey,
          ),
          LiquidTransactionOutput(:final scriptPubkey) => scriptPubkey,
        },
        scriptPubKeyBytes: switch (output) {
          BitcoinTransactionOutput(:final scriptPubkey) =>
            scriptPubkey.toList(),
          LiquidTransactionOutput(:final scriptPubkey) => hex.decode(
            scriptPubkey,
          ),
        },
      );
    }).toList();

    return BitcoinTransaction(
      txid: walletTx.txId,
      version: 2,
      size: walletTx.vsize, // Approximate; exact raw size not available
      vsize: walletTx.vsize,
      locktime: 0,
      inputs: inputs,
      outputs: outputs,
    );
  }

  static LiquidTransaction _walletTxToLiquid(WalletTransaction walletTx) {
    final inputs = walletTx.inputs.map((input) {
      final valueSat = switch (input) {
        BitcoinTransactionInput(:final value) => value?.toInt(),
        LiquidTransactionInput(:final value) => value.toInt(),
      };
      return LiquidTxInput(
        previousTxId: input.previousTxId,
        previousVout: input.previousTxVout,
        valueSat: valueSat,
        sequence: 0,
        scriptSig: '',
        witness: const [],
        isPegin: false,
      );
    }).toList();

    final outputs = walletTx.outputs.asMap().entries.map((entry) {
      final i = entry.key;
      final output = entry.value;
      final valueSat = switch (output) {
        BitcoinTransactionOutput(:final value) => value?.toInt() ?? 0,
        LiquidTransactionOutput(:final value) => value.toInt(),
      };
      return LiquidTxOutput(
        valueSat: valueSat,
        index: i,
        address: switch (output) {
          BitcoinTransactionOutput(:final address) => address,
          LiquidTransactionOutput(:final address) => address,
        },
        scriptPubKeyHex: switch (output) {
          BitcoinTransactionOutput(:final scriptPubkey) => hex.encode(
            scriptPubkey,
          ),
          LiquidTransactionOutput(:final scriptPubkey) => scriptPubkey,
        },
      );
    }).toList();

    return LiquidTransaction(
      txid: walletTx.txId,
      version: 2,
      vsize: walletTx.vsize,
      weight: walletTx.vsize * 4, // Approximate
      locktime: 0,
      feeSat: walletTx.feeSat,
      inputs: inputs,
      outputs: outputs,
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
    bool? isTestnet,
  }) {
    String? address;
    if (isTestnet != null) {
      try {
        address = bdk.Address.fromScript(
          script: bdk.Script(
            rawOutputScript: Uint8List.fromList(vout.scriptPubKey.bytes),
          ),
          network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
        ).toString();
      } catch (_) {
        // Non-standard script — leave address null
      }
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
