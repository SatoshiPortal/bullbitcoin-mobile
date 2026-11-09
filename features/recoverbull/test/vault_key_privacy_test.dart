import 'dart:async';

import 'package:bull_recoverbull/src/ui/screens/view_vault_key_page.dart';
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_privacy/screen_privacy.dart';
import 'package:secrets/secrets.dart';

const _channel = MethodChannel('com.flutterplaza.no_screenshot_methods');

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(extensions: const [testBullTheme]),
  localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
  supportedLocales: RecoverBullLocalizations.supportedLocales,
  home: child,
);

void main() {
  final key = VaultKey('ab' * 32);
  setUp(() {
    ScreenCaptureProtection.instance.enabledByUser = true;
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });
  for (final mode in ['pending', 'refused', 'throws']) {
    testWidgets('no reveal or copy when privacy is $mode', (tester) async {
      final pending = Completer<bool>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
        call,
      ) async {
        if (call.method != 'screenshotOff') return true;
        if (mode == 'pending') return pending.future;
        if (mode == 'throws') throw PlatformException(code: 'unavailable');
        return false;
      });
      await tester.pumpWidget(
        _app(ViewVaultKeyPage(vaultKey: key, copiedMessage: 'Copied')),
      );
      await tester.pump();
      expect(find.byType(BullCopyField), findsNothing);
      expect(find.widgetWithText(BullButton, 'Vault key'), findsNothing);
      expect(
        find.widgetWithText(BullButton, 'Retry'),
        mode == 'pending' ? findsNothing : findsOneWidget,
      );
      expect(find.text(key.hex), findsNothing);
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      if (!pending.isCompleted) pending.complete(true);
      await tester.pump();
    });
  }
  testWidgets('confirmed protection permits reveal without semantics', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => true,
    );
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(ViewVaultKeyPage(vaultKey: key, copiedMessage: 'Copied')),
    );
    await tester.pump();
    await tester.tap(find.byType(BullButton));
    await tester.pump();
    expect(find.text(key.hex), findsOneWidget);
    expect(find.bySemanticsLabel(key.hex), findsNothing);
    await tester.pumpWidget(_app(const SizedBox.shrink()));
    semantics.dispose();
  });
}
