import 'package:sync/sync.dart' show BitcoinTx, TxVout, TxScriptSig;
import 'package:bb_mobile/features/broadcast_signed_tx/domain/transaction_review_mapper.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final p2wpkh = [0, 20, ...List.filled(20, 0x22)];
  final opReturn = [0x6a, 0x01, 0x00];
  final tx = BitcoinTx(
    txid: 'ab' * 32,
    version: 2,
    size: BigInt.from(100),
    vsize: BigInt.from(100),
    locktime: 0,
    vin: const [],
    vout: [
      TxVout(
        value: BigInt.from(1000),
        n: 0,
        scriptPubKey: TxScriptSig(bytes: p2wpkh),
      ),
      TxVout(
        value: BigInt.zero,
        n: 1,
        scriptPubKey: TxScriptSig(bytes: opReturn),
      ),
    ],
  );

  test('outputs are named by their address on the given network', () {
    for (final (network, prefix) in [
      (BitcoinNetwork.mainnet, 'bc1q'),
      (BitcoinNetwork.testnet, 'tb1q'),
      (BitcoinNetwork.regtest, 'bcrt1q'),
    ]) {
      final mapped = TransactionReviewMapper.fromBitcoinTx(
        tx,
        network: network,
      );
      expect(mapped.outputs.first.address, startsWith(prefix));
      expect(mapped.outputs.first.valueSat, 1000);
    }
  });

  test('a non-standard script has no address', () {
    final mapped = TransactionReviewMapper.fromBitcoinTx(
      tx,
      network: BitcoinNetwork.mainnet,
    );
    expect(mapped.outputs.last.address, isNull);
    expect(mapped.outputs.last.scriptPubKeyHex, '6a0100');
  });

  test('a Liquid network names no Bitcoin address', () {
    final mapped = TransactionReviewMapper.fromBitcoinTx(tx, network: null);
    expect(
      mapped.outputs.map((output) => output.address),
      everyElement(isNull),
    );
  });
}
