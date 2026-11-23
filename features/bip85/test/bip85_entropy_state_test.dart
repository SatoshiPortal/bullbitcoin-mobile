import 'package:secrets/bip85.dart';
import 'package:bip85/src/presentation/bip85_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _Derivation extends Fake implements Bip85Derivation {
  @override
  final String path;
  @override
  final String? alias;
  @override
  final Bip85Status status;
  @override
  final Bip85Application application;

  _Derivation({
    required this.path,
    required this.alias,
    required this.status,
    required this.application,
  });
}

void main() {
  test('toString names no BIP85 child', () {
    const entropy = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
    final state = Bip85EntropyState(
      derivations: [
        (
          derivation: _Derivation(
            path: "128169'/16'/0'",
            alias: null,
            status: Bip85Status.active,
            application: Bip85Application.hex,
          ),
          entropy: entropy,
        ),
      ],
    );

    expect(state.toString(), isNot(contains(entropy)));
    expect(state.toString(), contains('derivations: 1'));
  });
}
