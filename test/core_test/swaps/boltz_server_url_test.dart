import 'package:bb_mobile/core/swaps/domain/entity/boltz_server_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoltzServerUrl', () {
    test('normalizes a root endpoint to the v2 API', () {
      expect(
        BoltzServerUrl.parse('https://boltz.example.com/').toString(),
        'https://boltz.example.com/v2',
      );
    });

    test('preserves a custom API path and removes its trailing slash', () {
      expect(
        BoltzServerUrl.parse(
          'https://boltz.example.com:8443/custom/v2/',
        ).toString(),
        'https://boltz.example.com:8443/custom/v2',
      );
    });

    test('rejects endpoints that are unsafe or ambiguous', () {
      for (final value in [
        'http://boltz.example.com/v2',
        'https:///v2',
        'https://user:pass@boltz.example.com/v2',
        'https://boltz.example.com/v2?token=secret',
        'https://boltz.example.com/v2#fragment',
      ]) {
        expect(
          () => BoltzServerUrl.parse(value),
          throwsA(isA<FormatException>()),
          reason: value,
        );
      }
    });

    test('has value equality after normalization', () {
      expect(
        BoltzServerUrl.parse('https://boltz.example.com'),
        BoltzServerUrl.parse('https://boltz.example.com/v2'),
      );
    });
  });
}
