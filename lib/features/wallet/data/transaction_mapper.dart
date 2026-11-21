import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/transactions/domain/entities/bitcoin_transaction.dart';
import 'package:sync/sync.dart' as btc_utils show BitcoinTx, TxVin, TxVout;
import 'package:primitives/primitives.dart' show BitcoinNetwork, Err, Ok;
import 'package:sync/sync.dart' show bitcoinScriptAddress;
import 'package:convert/convert.dart';

/// Maps the BDK utility class [btc_utils.BitcoinTx] to the domain entity
/// [BitcoinTransaction].
class TransactionMapper {
  /// Convert a [btc_utils.BitcoinTx] utility class to a [BitcoinTransaction]
  /// domain entity.
  ///
  /// When [network] is provided, scriptPubKey bytes are decoded to a
  /// human-readable address via sync's `bitcoinScriptAddress`. If decoding fails
  /// (e.g. non-standard script), the address field is left `null`.
  static BitcoinTransaction fromBitcoinTx(
    btc_utils.BitcoinTx bitcoinTx, {
    required Network network,
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
                _mapBitcoinOutput(entry.value, entry.key, network: network),
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
    required Network network,
  }) {
    final bitcoinNetwork = switch (network) {
      Network.bitcoinMainnet => BitcoinNetwork.mainnet,
      Network.bitcoinTestnet => BitcoinNetwork.testnet,
      Network.bitcoinRegtest => BitcoinNetwork.regtest,
      _ => null,
    };
    // A non-standard script, or a network without Bitcoin addresses, has none.
    final address = bitcoinNetwork == null
        ? null
        : switch (bitcoinScriptAddress(
            vout.scriptPubKey.bytes,
            bitcoinNetwork,
          )) {
            Ok(:final value) => value,
            Err() => null,
          };

    return BitcoinTxOutput(
      valueSat: vout.value.toInt(),
      index: index,
      address: address,
      scriptPubKeyHex: hex.encode(vout.scriptPubKey.bytes),
      scriptPubKeyBytes: vout.scriptPubKey.bytes,
    );
  }
}
