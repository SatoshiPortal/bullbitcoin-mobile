import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/view_vault_key_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_privacy/screen_privacy.dart';

/// The `no_screenshot` plugin flips the OS capture flag through this channel.
const _noScreenshot = MethodChannel('com.flutterplaza.no_screenshot_methods');

const _vaultKey = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  final captureCalls = <String>[];

  setUp(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_noScreenshot, (call) async {
      captureCalls.add(call.method);
      return true;
    });
    // The controller is a process-wide singleton: drain any screen a previous
    // test left acquired so each test starts unprotected.
    for (var i = 0; i < 100; i++) {
      await ScreenCaptureProtection.instance.release();
    }
    ScreenCaptureProtection.instance.enabledByUser = true;
    captureCalls.clear();
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_noScreenshot, null);
  });

  testWidgets('blocks screen capture while it is shown', (tester) async {
    await tester.pumpWidget(_app(const ViewVaultKeyPage(vaultKey: _vaultKey)));
    await tester.pump();
    expect(captureCalls, ['screenshotOff']);

    await tester.pumpWidget(_app(const SizedBox.shrink()));
    await tester.pump();
    expect(captureCalls, ['screenshotOff', 'screenshotOn']);
  });
}
