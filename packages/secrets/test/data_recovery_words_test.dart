import 'package:recoverbull/recoverbull.dart';
import 'dart:convert';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:convert/convert.dart';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:secrets/src/widgets/painted_text.dart'
    show PaintedMnemonic, debugPaintedTextOf;

void main() {
  const words =
      'broccoli great coffee gym action camera repair tilt august purity peanut harbor';
  test('recovery words encrypt with the independent BIP85 key vector', () {
    final credential = BackupCredential.fromWords(words);
    final plaintext = utf8.encode('public wallet metadata');
    expect(
      RecoverBull.restoreBackup(
        backupKey: hex.decode(
          '3bb61deff48bde89d721d5a10585b9887240dc9651ec89be69abaee2318d1f4e',
        ),
        backup: BullBackup(
          createdAt: 0,
          id: const [],
          salt: const [],
          ciphertext: credential.encrypt(plaintext),
        ),
      ),
      plaintext,
    );
  });
  testWidgets(
    'recovery words are sealed and a locked retry cannot retain them',
    (tester) async {
      final bytes = Uint8List.fromList(List.filled(32, 99));
      final id = Fingerprint(
        hex.encode(bip32.Bip32Keys.fromSeed(bytes).fingerprint),
      );
      final storage = FakeSecureStoragePlatform(
        entries: {
          'seed_${id.hex}': jsonEncode({
            'bytes': bytes.toList(),
            'runtimeType': 'bytes',
          }),
        },
      )..install();
      final secrets = Secrets(scratchDirectory: () async => '/tmp');
      late Secret secret;
      await tester.runAsync(() async {
        secret = (await secrets.fetch(id) as Ok<Secret, SecretFailure>).value;
      });
      Widget host(int generation) => Directionality(
        textDirection: TextDirection.ltr,
        child: secret.widgets.dataRecoveryWords(
          key: ValueKey(generation),
          placeholder: const Text('reading'),
          failureBuilder: (_, failure, retry) => const Text('unavailable'),
        ),
      );
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(0));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();
      final painted = tester.element(find.byType(PaintedMnemonic));
      expect(debugPaintedTextOf(painted), words);
      expect(find.textContaining(words), findsNothing);
      expect(find.bySemanticsLabel(RegExp('broccoli|harbor')), findsNothing);
      storage.locked = true;
      await tester.pumpWidget(host(1));
      expect(find.byType(PaintedMnemonic), findsNothing);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();
      expect(find.text('unavailable'), findsOneWidget);
      expect(find.byType(PaintedMnemonic), findsNothing);
      semantics.dispose();
    },
  );
}
