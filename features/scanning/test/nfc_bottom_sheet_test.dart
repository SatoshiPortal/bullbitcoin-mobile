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
      wrapWithTheme(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => NfcBottomSheet.showReadNfc(
              context: context,
              title: 'Read NFC',
              labels: (
                scanNfcButton: 'Scan NFC',
                nfcConnectionLost: 'Connection lost',
                nfcWriteFailed: 'Write failed',
                nfcDisabled: 'NFC disabled',
                nfcNotAvailable: 'NFC unavailable',
                nfcError: 'Could not scan NFC',
                nfcInvalidData: 'Unsupported tag',
              ),
              onDataReceived: payloads.add,
            ),
            child: const Text('Start'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(payloads, isEmpty);
    expect(find.text('Could not scan NFC'), findsOneWidget);
    expect(find.textContaining('private payload'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
