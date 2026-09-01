import 'package:bb_mobile/core/utils/nostr_bech32.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes frozen Nostr public and private keys', () {
    expect(
      NostrBech32.npub(
        hex.decode(
          '4fb85384f3a52baadbadc3f9bcb7fd59691e323293160b58959dadd6195c7981',
        ),
      ),
      'npub1f7u98p8n55464kadc0umedlat953uv3jjvtqkky4nkkavx2u0xqsvsgq2t',
    );
    expect(
      NostrBech32.nsec(
        hex.decode(
          'f4141af5b1b85b1343cf8400a311b27fb5c16ace5537ee6fe9552e2dd97f311b',
        ),
      ),
      'nsec17s2p4ad3hpd3xs70ssq2xydj076uz6kw25m7umlf25hzmktlxydsw2t3sg',
    );
  });

  test('rejects values that are not 32 bytes', () {
    expect(() => NostrBech32.npub([0]), throwsArgumentError);
    expect(() => NostrBech32.nsec(List.filled(33, 0)), throwsArgumentError);
  });
}
