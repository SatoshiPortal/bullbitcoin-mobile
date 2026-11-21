import 'package:sync/sync.dart' show BitcoinTx;
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';

// Version 2, one input (txid 0x01..0x20 reversed, vout 0, sequence
// 0xfffffffd) carrying a 100200 sat witness UTXO, one 100000 sat P2WPKH
// output.
const _psbt =
    'cHNidP8BAFICAAAAAQECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gAAAAAAD9////'
    'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
    'MzMzMzMzMzMzMzMzMzMzMzMAAA==';

final _unsignedHex =
    '0200000001${hex.encode(List.generate(32, (i) => i + 1))}00000000'
    '00fdffffff01a086010000000000160014${'22' * 20}00000000';

void main() {
  test('a PSBT and its transaction decode to the same skeleton', () async {
    final fromPsbt = await BitcoinTx.fromPsbt(_psbt);
    final fromBytes = await BitcoinTx.fromBytes(hex.decode(_unsignedHex));

    for (final tx in [fromPsbt, fromBytes]) {
      expect(tx.version, 2);
      expect(tx.locktime, 0);
      expect(tx.size, BigInt.from(_unsignedHex.length ~/ 2));
      expect(tx.vin.single.txid, hex.encode(List.generate(32, (i) => 32 - i)));
      expect(tx.vin.single.vout, 0);
      expect(tx.vin.single.sequence, 0xfffffffd);
      expect(tx.vout.single.value, BigInt.from(100000));
      expect(tx.vout.single.n, 0);
      expect(hex.encode(tx.vout.single.scriptPubKey.bytes), '0014${'22' * 20}');
    }
    expect(fromPsbt.txid, fromBytes.txid);
  });

  test('bytes that are not a transaction throw a FormatException', () {
    expect(
      BitcoinTx.fromBytes(const [1, 2, 3]),
      throwsA(isA<FormatException>()),
    );
  });

  test('text that is neither a PSBT nor base64 throws', () {
    expect(BitcoinTx.fromPsbt('not a psbt'), throwsA(isA<Exception>()));
  });
}
