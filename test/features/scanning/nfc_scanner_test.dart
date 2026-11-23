import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/scanning/public/nfc_scanning.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final succeeds in [true, false]) {
    testWidgets(
      'finishes NFC polling on disposal after ${succeeds ? 'a tag' : 'an error'}',
      (tester) async {
        const channel = MethodChannel('flutter_nfc_kit/method');
        final messenger = tester.binding.defaultBinaryMessenger;
        final pollingError = PlatformException(code: '408');
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'finish') return null;
          expect(call.method, 'poll');
          if (!succeeds) throw pollingError;
          return '{"type":"iso15693","id":"fixture","standard":"ISO 15693"}';
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

        final tags = <NFCTag>[];
        final errors = <Object>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: NfcScannerWidget(
                onScanned: tags.add,
                onError: errors.add,
                loadingWidget: const Text('Waiting for tag'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final technologies =
            (calls.single.arguments as Map)['technologies'] as int;
        expect(technologies & 0x8, 0x8);
        expect(technologies & 0x4, 0);

        if (succeeds) {
          expect(tags.single.id, 'fixture');
          expect(errors, isEmpty);
        } else {
          expect(tags, isEmpty);
          expect(errors.single, isA<PlatformException>());
          expect((errors.single as PlatformException).code, pollingError.code);
          expect(find.text('Waiting for tag'), findsOneWidget);
        }

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(calls.map((call) => call.method), ['poll', 'finish']);
      },
    );
  }
}
