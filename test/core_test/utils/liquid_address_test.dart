import 'package:bb_mobile/core/utils/liquid_address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isConfidentialLiquidAddress', () {
    test('blech32 confidential addresses are confidential', () {
      // Real mainnet confidential address (used elsewhere in the codebase).
      expect(
        isConfidentialLiquidAddress(
          'lq1pqvxwxl7pckz6p4vq0dh7dv8ae3lha97w4wjqls8p508xc2jus85sf3xgkzdkm3qdgmckph0a303qvnfyxsffyszy8s2w5ev5ys93xx0we046p4uqlt24',
        ),
        isTrue,
      );
      expect(
        isConfidentialLiquidAddress(
          'tlq1qq2xvpcvfup5j8zpfjq2xvp3y4s5n6l7k8j9h0g1f2d3s4a5p6o7i8u9y0t1r2e3w4q5a6s7d8f9g0h1j2k3l4',
        ),
        isTrue,
      );
    });

    test('bech32 unconfidential addresses are not confidential', () {
      expect(
        isConfidentialLiquidAddress(
          'ex1qq000000000000000000000000000000000000000',
        ),
        isFalse,
      );
      expect(
        isConfidentialLiquidAddress(
          'tex1qq000000000000000000000000000000000000000',
        ),
        isFalse,
      );
    });

    test('short base58 addresses are not confidential', () {
      // 25-byte Base58Check payload → ~34 chars (mainnet p2pkh starts 'Q').
      expect(
        isConfidentialLiquidAddress('QaTrEsT1234567890abcdefgh1234567'),
        isFalse,
      );
    });

    test('long base58 addresses are confidential', () {
      // A confidential Base58Check address embeds a 33-byte blinding key on
      // top of the 25-byte payload → ~76 chars.
      expect(
        isConfidentialLiquidAddress(
          'VJh7sMeQvYkKzB3nJ2mP9xQ4wR8tY6uI5oP1aS3dF7gH0jL4zX6cV2bN9mQ1wE4rT7yU9',
        ),
        isTrue,
      );
    });
  });
}
