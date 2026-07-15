import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_setup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts valid commitment metadata', () {
    final setup = AutomaticFallbackSetup(
      btcAddress: 'bc1qfallback',
      commitmentVersion: 1,
      signedAtUnix: 0,
      registeredNow: false,
    );

    expect(setup.btcAddress, 'bc1qfallback');
  });

  test('rejects an empty address', () {
    expect(
      () => AutomaticFallbackSetup(
        btcAddress: '',
        commitmentVersion: 1,
        signedAtUnix: 0,
        registeredNow: false,
      ),
      throwsArgumentError,
    );
  });

  test('rejects invalid commitment metadata', () {
    expect(
      () => AutomaticFallbackSetup(
        btcAddress: 'bc1qfallback',
        commitmentVersion: 0,
        signedAtUnix: 0,
        registeredNow: false,
      ),
      throwsArgumentError,
    );
    expect(
      () => AutomaticFallbackSetup(
        btcAddress: 'bc1qfallback',
        commitmentVersion: 1,
        signedAtUnix: -1,
        registeredNow: false,
      ),
      throwsArgumentError,
    );
  });
}
