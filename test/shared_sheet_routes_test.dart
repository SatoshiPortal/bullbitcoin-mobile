import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/announcement_banner.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/widgets/error_reporting_confirmation_bottom_sheet.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Exchange extends Mock implements ExchangeCubit {}

class _Settings extends Mock implements SettingsCubit {}

void main() {
  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets('exchange announcement sheet in ${theme.name}', (tester) async {
      final exchange = _Exchange();
      when(() => exchange.stream).thenAnswer((_) => const Stream.empty());
      when(() => exchange.state).thenReturn(
        ExchangeState(
          announcements: [
            Announcement(
              title: 'Scheduled maintenance',
              description: 'Exchange services will be unavailable during scheduled maintenance.',
              updatedAt: DateTime.utc(2026, 11, 20),
            ),
          ],
        ),
      );
      await _pump(
        tester,
        theme,
        BlocProvider<ExchangeCubit>.value(
          value: exchange,
          child: const AnnouncementBanner(),
        ),
      );

      await tester.tap(find.text('Scheduled maintenance'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(BullBottomSheet), findsOneWidget);
      final close = MaterialLocalizations.of(
        tester.element(find.byType(BottomSheet)),
      ).closeButtonTooltip;
      final closeButton = find.byTooltip(close);
      expect(
        tester.getSize(closeButton).shortestSide,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(closeButton);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    });

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
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('review'),
      child: wrap?.call(app) ?? app,
    ),
  );
  await tester.pumpAndSettle();
}
