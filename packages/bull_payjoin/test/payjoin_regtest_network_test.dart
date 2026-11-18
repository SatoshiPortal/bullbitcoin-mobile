import 'dart:typed_data';

import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_payjoin/src/engine/payjoin_ownership.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

class _Codec extends Fake implements PayjoinCodecPort {
  final networks = <BitcoinNetwork>[];
  @override
  Uint8List? addressScript(String address, BitcoinNetwork network) {
    networks.add(network);
    return Uint8List.fromList([0x51]);
  }
}

void main() {
  test('regtest ownership and amounts never ask the codec for testnet', () {
    final codec = _Codec();
    final tx = PayjoinTransaction(
      txid: 'public-id',
      inputs: [],
      outputs: [
        PayjoinTransactionOutput(
          value: Sats.fromInt(10000),
          scriptPubkey: Uint8List.fromList([0x51]),
        ),
      ],
    );
    expect(
      amountReceived(
        tx,
        codec: codec,
        address: 'bcrt1fixture',
        isTestnet: true,
        networkOverride: BitcoinNetwork.regtest,
      ),
      10000,
    );
    expect(
      paymentScriptFromBip21(
        'bitcoin:bcrt1fixture?pj=https://localhost:8040',
        codec: codec,
        isTestnet: true,
        networkOverride: BitcoinNetwork.regtest,
      ),
      [0x51],
    );
    expect(codec.networks, [BitcoinNetwork.regtest, BitcoinNetwork.regtest]);
  });
}
