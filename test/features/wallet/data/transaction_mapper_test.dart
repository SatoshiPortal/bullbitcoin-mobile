import 'package:sync/sync.dart' show BitcoinTx, TxVout, TxScriptSig;
import 'package:bb_mobile/features/wallet/data/transaction_mapper.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
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
      (Network.bitcoinMainnet, 'bc1q'),
      (Network.bitcoinTestnet, 'tb1q'),
      (Network.bitcoinRegtest, 'bcrt1q'),
    ]) {
      final mapped = TransactionMapper.fromBitcoinTx(tx, network: network);
      expect(mapped.outputs.first.address, startsWith(prefix));
      expect(mapped.outputs.first.valueSat, 1000);
    }
  });

  test('a non-standard script has no address', () {
    final mapped = TransactionMapper.fromBitcoinTx(
      tx,
      network: Network.bitcoinMainnet,
    );
    expect(mapped.outputs.last.address, isNull);
    expect(mapped.outputs.last.scriptPubKeyHex, '6a0100');
  });

  test('a Liquid network names no Bitcoin address', () {
    final mapped = TransactionMapper.fromBitcoinTx(
      tx,
      network: Network.liquidMainnet,
    );
    expect(
      mapped.outputs.map((output) => output.address),
      everyElement(isNull),
    );
  });
}
