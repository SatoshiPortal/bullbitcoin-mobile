import 'package:bull_exchange/src/kyc/exchange_kyc_navigation.dart';
import 'package:bull_exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = 'https://auth.example.com/kyc';
  const securityBase = 'https://auth.example.com/settings/security';
  final policy = ExchangeKycNavigation(base);
  test('authenticated navigation requires the trusted HTTPS origin', () {
    for (final url in [
      'https://foreign.invalid/kyc',
      'https://auth.example.com.evil.invalid/login',
      'https://auth.example.com@evil.invalid/verification',
      'https://user@auth.example.com/kyc',
      'http://auth.example.com/kyc',
      'https://auth.example.com:444/kyc',
    ]) {
      final uri = policy.resolve(url);
      expect(uri, isNotNull);
      expect(uri == null ? null : policy.allows(uri), isFalse, reason: url);
      expect(allowsSecurityNavigation(securityBase, url), isFalse, reason: url);
    }
    expect(
      policy.allows(Uri.parse('https://auth.example.com/kyc/step')),
      isTrue,
    );
    expect(
      policy.resolve('/login'),
      Uri.parse('https://auth.example.com/login'),
    );
    expect(
      allowsSecurityNavigation(securityBase, '/settings/security'),
      isTrue,
    );
    expect(policy.allowsAuthentication('foreign.invalid'), isFalse);
    expect(policy.allowsAuthentication('auth.example.com'), isTrue);
  });
  test('Incode links open externally only for actual HTTPS Incode domains', () {
    expect(
      policy.isIncode(Uri.parse('https://session.incodesmile.com/a')),
      isTrue,
    );
    for (final url in [
      'https://incodesmile.com.evil.invalid/a',
      'https://fakeincodesmile.com/a',
      'http://incodesmile.com/a',
      'https://user@incodesmile.com/a',
      'https://incodesmile.com:444/a',
    ]) {
      expect(policy.isIncode(Uri.parse(url)), isFalse, reason: url);
    }
  });
}
