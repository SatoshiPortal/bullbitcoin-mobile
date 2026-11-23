import 'package:bull_ui/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scanning/scanning.dart';

void main() {
  testWidgets('does not surface foreign errors or deliver a payload', (
    tester,
  ) async {
    const channel = MethodChannel('flutter_nfc_kit/method');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'fixture', message: 'private payload');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final payloads = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: ScanningLocalizations.supportedLocales,
        localizationsDelegates: const [
          ScanningLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: ThemeData(extensions: testBullExtensions),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => NfcBottomSheet.showReadNfc(
                context: context,
                title: 'Read NFC',
                onDataReceived: payloads.add,
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(payloads, isEmpty);
    expect(find.text("Oups ! Une erreur s'est produite"), findsOneWidget);
    expect(find.textContaining('private payload'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
