import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/view_vault_key_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_privacy/screen_privacy.dart';

/// The `no_screenshot` plugin flips the OS capture flag through this channel.
const _noScreenshot = MethodChannel('com.flutterplaza.no_screenshot_methods');

const _vaultKey = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';

/// The platform clipboard, kept in memory so pumping a duration fires the
/// clear timer deterministically.
class _Clipboard {
  String? text;

  /// Android 10+ hides the clipboard from a backgrounded app: reads return
  /// nothing while writes still succeed.
  bool readable = true;

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'Clipboard.setData':
        text = (call.arguments as Map)['text'] as String?;
      case 'Clipboard.getData':
        return text == null || !readable ? null : {'text': text};
    }
    return null;
  }
}

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  late _Clipboard clipboard;
  final captureCalls = <String>[];

  setUp(() async {
    clipboard = _Clipboard();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      clipboard.handle,
    );
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
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(_noScreenshot, null);
  });

  Future<void> settleSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  }

  testWidgets('blocks screen capture while it is shown', (tester) async {
    await tester.pumpWidget(_app(const ViewVaultKeyPage(vaultKey: _vaultKey)));
    await tester.pump();
    expect(captureCalls, ['screenshotOff']);

    await tester.pumpWidget(_app(const SizedBox.shrink()));
    await tester.pump();
    expect(captureCalls, ['screenshotOff', 'screenshotOn']);
  });

  testWidgets('a copied vault key is cleared after 30 seconds', (tester) async {
    await tester.pumpWidget(_app(const ViewVaultKeyPage(vaultKey: _vaultKey)));
    await tester.tap(find.byIcon(Icons.copy_sharp));
    await tester.pump();
    expect(clipboard.text, _vaultKey);

    await tester.pump(const Duration(seconds: 29));
    expect(clipboard.text, _vaultKey);
    await tester.pump(const Duration(seconds: 1));
    expect(clipboard.text, isEmpty);
    await settleSnackBar(tester);
  });

  testWidgets('a key copied from the reveal dialog is cleared too', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const ViewVaultKeyPage(vaultKey: _vaultKey)));
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Copy'));
    await tester.pump();
    expect(clipboard.text, _vaultKey);

    await tester.pump(const Duration(seconds: 30));
    expect(clipboard.text, isEmpty);
  });

  testWidgets('something copied since then is left in the clipboard', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const ViewVaultKeyPage(vaultKey: _vaultKey)));
    await tester.tap(find.byIcon(Icons.copy_sharp));
    await tester.pump();
    clipboard.text = 'copied elsewhere';

    await tester.pump(const Duration(seconds: 30));
    expect(clipboard.text, 'copied elsewhere');
    await settleSnackBar(tester);
  });

  testWidgets('leaving the page clears the key without waiting', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const ViewVaultKeyPage(vaultKey: _vaultKey)));
    await tester.tap(find.byIcon(Icons.copy_sharp));
    await tester.pump();
    await settleSnackBar(tester);
    expect(clipboard.text, _vaultKey);

    await tester.pumpWidget(_app(const SizedBox.shrink()));
    await tester.pump();
    expect(clipboard.text, isEmpty);
  });

  testWidgets('a key the app could not read back is cleared on return', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const ViewVaultKeyPage(vaultKey: _vaultKey)));
    await tester.tap(find.byIcon(Icons.copy_sharp));
    await tester.pump();
    await settleSnackBar(tester);

    // The user switches to another app to paste the key.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    clipboard.readable = false;
    await tester.pump(const Duration(seconds: 30));
    expect(clipboard.text, _vaultKey);

    clipboard.readable = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(clipboard.text, isEmpty);
  });

  testWidgets('keeps the vault key out of the accessibility tree', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const ViewVaultKeyPage(vaultKey: _vaultKey)));
    expect(find.bySemanticsLabel(RegExp('a1b2c3')), findsNothing);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('a1b2')), findsNothing);
    // Not selectable, so it is only copied through the clearing buttons.
    expect(find.byType(SelectableText), findsNothing);
    semantics.dispose();
  });

  testWidgets('CopyInput leaves the clipboard alone unless asked', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const Scaffold(body: CopyInput(text: 'value'))),
    );
    await tester.tap(find.byIcon(Icons.copy_sharp));
    await tester.pump();

    await tester.pump(const Duration(minutes: 1));
    expect(clipboard.text, 'value');
    await settleSnackBar(tester);
  });
}
