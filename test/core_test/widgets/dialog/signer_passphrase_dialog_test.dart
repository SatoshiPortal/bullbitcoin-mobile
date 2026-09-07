import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/dialog/signer_passphrase_dialog.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');

  for (final accepted in [true, false, null]) {
    testWidgets('passphrase input waits for native protection: $accepted', (
      tester,
    ) async {
      final protection = Completer<bool?>();
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'screenshotOff') return await protection.future;
            return true;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  submitted = await showSignerPassphraseDialog(
                    context,
                    title: 'Unlock signer',
                    description: 'Enter the signer passphrase',
                    hint: 'Passphrase',
                    cancelLabel: 'Cancel',
                    confirmLabel: 'Unlock',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(EditableText), findsNothing);

      protection.complete(accepted);
      await tester.pumpAndSettle();
      if (accepted == true) {
        expect(find.byType(EditableText), findsOneWidget);
        await tester.enterText(find.byType(EditableText), 'test-only-secret');
        await tester.pump();
        await tester.tap(find.text('Unlock'));
      } else {
        expect(find.byType(EditableText), findsNothing);
        final context = tester.element(find.byType(AlertDialog));
        expect(find.text(context.loc.screenPrivacyUnavailable), findsOneWidget);
        await tester.tap(find.text('Cancel'));
      }
      await tester.pumpAndSettle();
      expect(submitted, accepted == true ? 'test-only-secret' : null);
      expect(calls, ['screenshotOff', 'screenshotOn']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
