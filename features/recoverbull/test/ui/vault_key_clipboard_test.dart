import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/ui/screens/view_vault_key_page.dart';
import 'package:bull_recoverbull/src/ui/widgets/copy_input.dart';
import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _vaultKey = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';

/// The platform clipboard, kept in memory: widget tests run in a fake-async
/// zone, so pumping a duration fires the auto-clear timer deterministically.
class _Clipboard {
  String? text;

  /// Android 10+ hides the clipboard from an app in the background: reads
  /// return nothing while writes still succeed.
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
  theme: ThemeData(extensions: const [testBullTheme]),
  localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
  supportedLocales: RecoverBullLocalizations.supportedLocales,
  home: home,
);

void main() {
  late _Clipboard clipboard;

  setUp(() {
    clipboard = _Clipboard();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, clipboard.handle);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> dismissSnackBar(WidgetTester tester) async {
    BullSnackBar.dismiss();
    await tester.pumpAndSettle();
  }

  testWidgets('a copied vault key is cleared after 30 seconds', (tester) async {
    await tester.pumpWidget(_app(const ViewVaultKeyPage(vaultKey: _vaultKey)));
    await tester.tap(find.byIcon(Icons.copy_sharp));
    await tester.pump();
    expect(clipboard.text, _vaultKey);

    await tester.pump(const Duration(seconds: 29));
    expect(clipboard.text, _vaultKey);
    await tester.pump(const Duration(seconds: 1));
    expect(clipboard.text, isEmpty);
    await dismissSnackBar(tester);
  });

  testWidgets('a key copied from the reveal dialog is cleared too', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const ViewVaultKeyPage(vaultKey: _vaultKey)));
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(clipboard.text, _vaultKey);

    await tester.pump(const Duration(seconds: 30));
    expect(clipboard.text, isEmpty);
    await dismissSnackBar(tester);
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
    await dismissSnackBar(tester);
  });

  testWidgets('leaving the page clears the key without waiting', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const ViewVaultKeyPage(vaultKey: _vaultKey)));
    await tester.tap(find.byIcon(Icons.copy_sharp));
    await tester.pump();
    await dismissSnackBar(tester);
    expect(clipboard.text, _vaultKey);

    await tester.pumpWidget(_app(const SizedBox.shrink()));
    await tester.pump();
    expect(clipboard.text, isEmpty);
    // No clear is left pending once the page is gone.
    await tester.pump(const Duration(seconds: 30));
    expect(clipboard.text, isEmpty);
  });

  testWidgets('a key the app could not read back is cleared on return', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const ViewVaultKeyPage(vaultKey: _vaultKey)));
    await tester.tap(find.byIcon(Icons.copy_sharp));
    await tester.pump();
    await dismissSnackBar(tester);

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
    await dismissSnackBar(tester);
  });
}
