import 'package:primitives/primitives.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

void main() {
  test(
    'backup and restore diagnostics contain no identity or derivation path',
    () async {
      FakeSecureStoragePlatform().install();
      final secrets = Secrets(scratchDirectory: () async => '.');
      final secret =
          (await secrets.import(words: '${'abandon ' * 11}about'.split(' '))
                  as Ok<Secret, SecretFailure>)
              .value;
      final messages = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) messages.add(message);
      };
      try {
        final backup =
            (await secret.backup.recoverbull()
                    as Ok<
                      ({EncryptedVault vault, VaultKey key}),
                      SecretFailure
                    >)
                .value;
        expect(
          await secrets.recoverbull.restore(
            vault: backup.vault,
            key: backup.key,
          ),
          isA<Ok>(),
        );
        await Future<void>.delayed(Duration.zero);
        expect(messages, isNotEmpty);
        expect(messages.join('\n'), isNot(contains(secret.id.hex)));
        expect(messages.join('\n'), isNot(contains("1608'/")));
      } finally {
        debugPrint = previous;
      }
    },
  );
}
