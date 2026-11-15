import 'package:bb_mobile/features/address_view/data/electrum_scripthash.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('electrumScripthash is the byte-reversed sha256 of the script', () {
    final script = hex.decode(
      '76a91462e907b15cbf27d5425399ebf6f0fb50ebb88f1888ac',
    );

    expect(
      electrumScripthash(script),
      '8b01df4e368ea28f8dc0423bcf7a4923e3a12d307c875e47a0cfbf90b5c39161',
    );
  });
}
