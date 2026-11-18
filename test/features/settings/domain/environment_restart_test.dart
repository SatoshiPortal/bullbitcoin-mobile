import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Environment.requiresRestartWhenSwitchedFrom', () {
    test('going to or from regtest needs a restart', () {
      expect(
        Environment.regtest.requiresRestartWhenSwitchedFrom(
          Environment.mainnet,
        ),
        isTrue,
      );
      expect(
        Environment.mainnet.requiresRestartWhenSwitchedFrom(
          Environment.regtest,
        ),
        isTrue,
      );
      expect(
        Environment.testnet.requiresRestartWhenSwitchedFrom(
          Environment.regtest,
        ),
        isTrue,
      );
    });

    test('mainnet and testnet share the captured runtimes', () {
      expect(
        Environment.testnet.requiresRestartWhenSwitchedFrom(
          Environment.mainnet,
        ),
        isFalse,
      );
      expect(
        Environment.mainnet.requiresRestartWhenSwitchedFrom(
          Environment.testnet,
        ),
        isFalse,
      );
    });

    test('selecting the current environment needs no restart', () {
      for (final environment in Environment.values) {
        expect(
          environment.requiresRestartWhenSwitchedFrom(environment),
          isFalse,
        );
      }
    });
  });
}
