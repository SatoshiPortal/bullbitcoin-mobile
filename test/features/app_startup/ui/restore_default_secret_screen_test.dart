import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/features/app_startup/ui/screens/restore_default_secret_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _noScreenshotChannel = MethodChannel(
  'com.flutterplaza.no_screenshot_methods',
);

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshotChannel, (_) async => true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshotChannel, null);
  });

  testWidgets('the phrase entry works above the navigator, where startup '
      'renders it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Like the app: startup is built by MaterialApp.builder, outside the
        // Navigator and its Overlay.
        builder: (context, child) =>
            RestoreDefaultSecretScreen(onCancel: () {}),
        home: const SizedBox.shrink(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MnemonicWidget), findsOneWidget);

    // Focusing a word brings up the in-app keyboard, whose keys show
    // tooltips: the case that needed an Overlay.
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('q').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
