import 'package:bb_mobile/features/electrum_settings/domain/electrum_url_parser.dart';
import 'package:test/test.dart';

void main() {
  test('preserves the address and resolves the SSL preference', () {
    const cases = {
      ' Example.net:050002 ': ('Example.net:050002', true, false),
      'example.net:50001:t': ('example.net:50001', false, true),
      'hidden.onion:50001': ('hidden.onion:50001', false, true),
      'hidden.onion:50002:s': ('hidden.onion:50002', true, true),
      'hidden.ONION:50001': ('hidden.ONION:50001', true, false),
    };

    for (final MapEntry(key: input, value: expected) in cases.entries) {
      final parsed = ElectrumUrlParser.parse(input);
      expect(
        (parsed.cleanUrl, parsed.enableSsl, parsed.sslExplicit),
        expected,
        reason: input,
      );
    }
  });

  test('distinguishes empty input, a protocol prefix and malformed input', () {
    const cases = {
      ' ': ElectrumUrlValidationError.empty,
      'ssl://example.net:50002': ElectrumUrlValidationError.hasProtocol,
      'example.net': ElectrumUrlValidationError.invalidFormat,
      'example.net:50002:S': ElectrumUrlValidationError.invalidFormat,
    };

    for (final MapEntry(key: input, value: expected) in cases.entries) {
      expect(() => ElectrumUrlParser.parse(input), throwsA(expected));
      expect(ElectrumUrlParser.tryParse(input), isNull);
    }
  });
}
