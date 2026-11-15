import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bb_mobile/features/transactions/data/explored_transaction_mapper.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;
import 'package:flutter_test/flutter_test.dart';

final _txid = 'ab' * 32;

void main() {
  test('maps a parsed transaction and decodes the output addresses', () {
    final tx = BitcoinTx(
      txid: _txid,
      version: 2,
      size: BigInt.from(222),
      vsize: BigInt.from(141),
      locktime: 800000,
      vin: const [
        TxVin(sequence: 1, txid: 'prev', vout: 0, scriptSig: null),
        TxVin(sequence: 1, txid: 'prev', vout: 1, scriptSig: null),
      ],
      vout: [
        TxVout(
          value: BigInt.from(1500),
          n: 0,
          scriptPubKey: const TxScriptSig(bytes: [1]),
        ),
        TxVout(
          value: BigInt.from(500),
          n: 1,
          scriptPubKey: const TxScriptSig(bytes: [2]),
        ),
      ],
    );
    final decoded = <Network>[];

    final transaction = ExploredTransactionMapper.fromBitcoinTx(
      tx,
      network: Network.bitcoinTestnet,
      decodeAddress: (script, network) {
        decoded.add(network);
        return script.first == 1 ? 'address-one' : null;
      },
    );

    expect(transaction.txid, _txid);
    expect(transaction.network, Network.bitcoinTestnet);
    expect(transaction.version, 2);
    expect(transaction.sizeBytes, 222);
    expect(transaction.virtualSizeBytes, 141);
    expect(transaction.locktime, 800000);
    expect(transaction.inputCount, 2);
    expect(transaction.totalOutputSat, 2000);
    expect(transaction.outputs.map((output) => output.index), [0, 1]);
    expect(transaction.outputs.map((output) => output.amountSat), [1500, 500]);
    expect(transaction.outputs.map((output) => output.address), [
      'address-one',
      null,
    ]);
    expect(decoded, [Network.bitcoinTestnet, Network.bitcoinTestnet]);
  });
}
