import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:secrets/src/widgets/painted_text.dart'
    show PaintedPassphrase, debugPaintedTextOf;

void main() {
  const words =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  const publicKey =
      'c071c9b02afd19a9d9b240ea9eed3f8ba80f89474953b752471f3d006b63a332';
  const nsec =
      'nsec17s2p4ad3hpd3xs70ssq2xydj076uz6kw25m7umlf25hzmktlxydsw2t3sg';
  late Secret secret;
  late FakeSecureStoragePlatform storage;
  final copied = <String>[];
  Future<void> ready(WidgetTester tester) async {
    storage = FakeSecureStoragePlatform()..install();
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    await tester.runAsync(() async {
      secret =
          (await secrets.import(words: words.split(' '))
                  as Ok<Secret, SecretFailure>)
              .value;
    });
    copied.clear();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();
  }

  Widget host({
    int identity = 1,
    String expected = publicKey,
    void Function(Future<void> Function())? captureCopy,
  }) => MaterialApp(
    home: Scaffold(
      body: secret.widgets.nostrKey(
        identity: identity,
        publicKey: expected,
        qrForeground: Colors.black,
        qrBackground: Colors.white,
        failureBuilder: (_, failure, retry) =>
            Text(failure.runtimeType.toString()),
        builder: (context, text, qr, copy) {
          captureCopy?.call(copy);
          return Column(
            children: [
              text,
              SizedBox(width: 200, child: qr),
              TextButton(onPressed: copy, child: const Text('copy')),
            ],
          );
        },
      ),
    ),
  );

  testWidgets(
    'nsec text and QR stay sealed; copy requires the supplied action',
    (tester) async {
      await ready(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host());
      await settle(tester);
      expect(
        debugPaintedTextOf(tester.element(find.byType(PaintedPassphrase))),
        nsec,
      );
      expect(find.textContaining('nsec1'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('nsec1')), findsNothing);
      expect(copied, isEmpty);
      await tester.tap(find.text('copy'));
      expect(copied, [nsec]);
      semantics.dispose();
    },
  );

  testWidgets(
    'changing the public record removes old text and invalidates its copy action',
    (tester) async {
      await ready(tester);
      late Future<void> Function() oldCopy;
      await tester.pumpWidget(host(captureCopy: (copy) => oldCopy = copy));
      await settle(tester);
      await tester.pumpWidget(host(expected: '11' * 32));
      expect(find.byType(PaintedPassphrase), findsNothing);
      await oldCopy();
      expect(copied, isEmpty);
      await settle(tester);
      expect(find.byType(PaintedPassphrase), findsNothing);
      expect(find.text('UseSecretFailure'), findsOneWidget);
    },
  );

  testWidgets('locked storage cannot reveal an nsec', (tester) async {
    await ready(tester);
    storage.locked = true;
    await tester.pumpWidget(host());
    await settle(tester);
    expect(find.byType(PaintedPassphrase), findsNothing);
    expect(find.text('KeystoreLockedFailure'), findsOneWidget);
    expect(copied, isEmpty);
  });

  testWidgets('both system keys use the backup credential root', (
    tester,
  ) async {
    await ready(tester);
    late BackupCredential credential;
    await tester.runAsync(() async {
      credential =
          (await secret.backup.data() as Ok<BackupCredential, SecretFailure>)
              .value;
    });
    for (final (identity, key) in [
      (100, credential.artifactPublicKey),
      (101, credential.serverPublicKey),
    ]) {
      await tester.pumpWidget(host(identity: identity, expected: key));
      await settle(tester);
      expect(find.byType(PaintedPassphrase), findsOneWidget);
      await tester.tap(find.text('copy'));
      expect(copied.last, startsWith('nsec1'));
    }
    expect(copied.toSet(), hasLength(2));
  });
}
