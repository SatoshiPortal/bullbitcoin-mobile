import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bb_mobile/features/transactions/domain/entities/explored_transaction.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;

typedef ScriptAddressDecoder =
    String? Function(List<int> scriptPubkey, Network network);

abstract final class ExploredTransactionMapper {
  static ExploredTransaction fromBitcoinTx(
    BitcoinTx tx, {
    required Network network,
    required ScriptAddressDecoder decodeAddress,
  }) => ExploredTransaction(
    txid: tx.txid,
    network: network,
    version: tx.version,
    sizeBytes: tx.size.toInt(),
    virtualSizeBytes: tx.vsize.toInt(),
    locktime: tx.locktime,
    inputCount: tx.vin.length,
    outputs: [
      for (final (index, output) in tx.vout.indexed)
        ExploredTransactionOutput(
          index: index,
          amountSat: output.value.toInt(),
          address: decodeAddress(output.scriptPubKey.bytes, network),
        ),
    ],
  );
}
