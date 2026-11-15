import 'dart:convert';

import 'package:bb_mobile/core/bbqr/bbqr.dart';
import 'package:flutter_test/flutter_test.dart';

const _psbt =
    'cHNidP8BAFICAAAAAQECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gAAAAAAD9////'
    'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
    'MzMzMzMzMzMzMzMzMzMzMzMAAA==';

void main() {
  for (final (name, input) in [
    ('text', 'not a psbt'),
    ('base64 that is not a PSBT', base64.encode(utf8.encode('psbt'))),
    ('a truncated PSBT', _psbt.substring(0, 40)),
  ]) {
    test('refuses $name before any QR part is made', () {
      expect(Bbqr.splitPsbt(input), throwsA(isA<FormatException>()));
    });
  }
}
