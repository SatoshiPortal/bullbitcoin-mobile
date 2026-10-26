import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/features/bip85_entropy/presentation/state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toString names no BIP85 child', () {
    const entropy = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
    final state = Bip85EntropyState(
      derivations: [
        (
          derivation: Bip85DerivationEntity(
            path: "128169'/16'/0'",
            xprvFingerprint: '73c5da0a',
            alias: null,
            status: Bip85Status.active,
            application: Bip85Application.hex,
            index: 0,
          ),
          entropy: entropy,
        ),
      ],
    );

    expect(state.toString(), isNot(contains(entropy)));
    expect(state.toString(), contains('derivations: 1'));
  });
}
