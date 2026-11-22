import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/widgets/error_reporting_confirmation_bottom_sheet.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Settings extends Mock implements SettingsCubit {}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });

  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets('error reporting sheet in ${theme.name}', (tester) async {
      final settings = _Settings();
      when(() => settings.stream).thenAnswer((_) => const Stream.empty());
      when(() => settings.toggleErrorReporting(true)).thenAnswer((_) async {});
      await _pump(
        tester,
        theme,
        Builder(
          builder: (context) => BullButton.secondary(
            label: 'Open reporting preferences',
            onPressed: () =>
                ErrorReportingConfirmationBottomSheet.show(context),
          ),
        ),
        wrap: (child) =>
            BlocProvider<SettingsCubit>.value(value: settings, child: child),
      );

      final open = find.text('Open reporting preferences');
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(BullBottomSheet), findsOneWidget);

      final loc = AppLocalizations.of(tester.element(find.byType(BottomSheet)));
      final cancel = find.text(loc.errorReportingCancelButton);
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      verifyNever(() => settings.toggleErrorReporting(true));

      await tester.tap(open);
      await tester.pumpAndSettle();
      final accept = find.text(loc.errorReportingAcceptButton);
      await tester.ensureVisible(accept);
      await tester.tap(accept);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      verify(() => settings.toggleErrorReporting(true)).called(1);
      expect(find.text(loc.errorReportingRestartSnackbar), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  }
}

Future<void> _pump(
  WidgetTester tester,
  AppThemeType theme,
  Widget content, {
  Widget Function(Widget)? wrap,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.themeData(theme),
    localizationsDelegates: const [
      bullUiLocalizationsDelegate,
      ...appLocalizationsDelegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: content)),
  );
  await tester.pumpWidget(wrap?.call(app) ?? app);
  await tester.pumpAndSettle();
}
