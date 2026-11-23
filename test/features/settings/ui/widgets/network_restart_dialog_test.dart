import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/settings/ui/widgets/testnet_mode_switch.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });

  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'restart action fits and remains mandatory at 360dp ($theme, $scale)',
        (tester) async {
          tester.view.physicalSize = const Size(360, 760);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var closes = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.themeData(theme),
              localizationsDelegates: const [
                bullUiLocalizationsDelegate,
                ...appLocalizationsDelegates,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child ?? const SizedBox.shrink(),
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showNetworkRestartDialog(
                      context,
                      onClose: () => closes++,
                    ),
                    child: const Text('Open restart dialog'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open restart dialog'));
          await tester.pumpAndSettle();

          final label = find.text('Close the app');
          expect(label, findsOneWidget);
          expect(
            tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
            isFalse,
            reason: 'The mandatory restart action must remain fully readable',
          );
          expect(find.byType(Dialog), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tapAt(const Offset(8, 8));
          await tester.pumpAndSettle();
          expect(label, findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(label, findsOneWidget);
          expect(closes, 0);

          await tester.tap(label);
          await tester.pumpAndSettle();
          expect(closes, 1);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
