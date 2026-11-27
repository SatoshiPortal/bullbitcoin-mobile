import 'dart:async';
import 'dart:io';

import 'package:bull_ui/app_theme.dart';
import 'package:settings/testing.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

class _Settings extends Mock implements SettingsCubit {}

void main() {
  setUpAll(() async {
    await (FontLoader('Golos Text')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('../../assets/fonts/GolosText.ttf').readAsBytes(),
            ),
          ),
        ))
        .load();
  });

  testWidgets('does not announce before the choice is saved', (tester) async {
    final pending = Completer<bool>();
    final settings = _Settings();
    when(() => settings.stream).thenAnswer((_) => const Stream.empty());
    when(() => settings.toggleErrorReporting(true))
        .thenAnswer((_) => pending.future);
    await _pump(
      tester,
      AppThemeType.light,
      Builder(
        builder: (context) => BullButton.secondary(
          label: 'Open reporting preferences',
          onPressed: () => ErrorReportingConfirmationBottomSheet.show(context),
        ),
      ),
      wrap: (child) =>
          BlocProvider<SettingsCubit>.value(value: settings, child: child),
    );
    await tester.tap(find.text('Open reporting preferences'));
    await tester.pumpAndSettle();
    final loc = SettingsLocalizations.of(
      tester.element(find.byType(BottomSheet)),
    );
    await tester.ensureVisible(find.text(loc.errorReportingAcceptButton));
    await tester.tap(find.text(loc.errorReportingAcceptButton));
    await tester.pump();
    expect(find.text(loc.errorReportingRestartSnackbar), findsNothing);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.text(loc.errorReportingRestartSnackbar), findsOneWidget);
    expect(find.text(loc.networkRestartDialogAction), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(loc.errorReportingRestartSnackbar), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text(loc.errorReportingRestartSnackbar), findsOneWidget);
  });

  testWidgets('failed activation does not announce success', (tester) async {
    final settings = _Settings();
    when(() => settings.stream).thenAnswer((_) => const Stream.empty());
    when(() => settings.toggleErrorReporting(true))
        .thenAnswer((_) async => false);
    await _pump(
      tester,
      AppThemeType.light,
      Builder(
        builder: (context) => BullButton.secondary(
          label: 'Open reporting preferences',
          onPressed: () => ErrorReportingConfirmationBottomSheet.show(context),
        ),
      ),
      wrap: (child) =>
          BlocProvider<SettingsCubit>.value(value: settings, child: child),
    );
    await tester.tap(find.text('Open reporting preferences'));
    await tester.pumpAndSettle();
    final loc = SettingsLocalizations.of(
      tester.element(find.byType(BottomSheet)),
    );
    await tester.ensureVisible(find.text(loc.errorReportingAcceptButton));
    await tester.tap(find.text(loc.errorReportingAcceptButton));
    await tester.pumpAndSettle();
    expect(find.text(loc.errorReportingRestartSnackbar), findsNothing);
  });

  for (final saved in [false, true]) {
    testWidgets('withdrawal announces only when saved: $saved', (tester) async {
      final settings = _Settings();
      when(() => settings.stream).thenAnswer((_) => const Stream.empty());
      when(() => settings.state).thenReturn(
        const SettingsState(
          storedSettings: SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
            isErrorReportingEnabled: true,
          ),
        ),
      );
      when(() => settings.toggleErrorReporting(false))
          .thenAnswer((_) async => saved);
      await _pump(
        tester,
        AppThemeType.light,
        const ErrorReportingSwitch(),
        wrap: (child) =>
            BlocProvider<SettingsCubit>.value(value: settings, child: child),
      );
      final loc = SettingsLocalizations.of(tester.element(find.byType(Switch)));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(
        find.text(loc.errorReportingRestartSnackbar),
        saved ? findsOneWidget : findsNothing,
      );
      expect(
        find.text(loc.networkRestartDialogAction),
        saved ? findsOneWidget : findsNothing,
      );
    });
  }

  test('restart notice is localized in English and French', () async {
    final en = await SettingsLocalizations.delegate.load(const Locale('en'));
    final fr = await SettingsLocalizations.delegate.load(const Locale('fr'));
    expect(
      en.errorReportingRestartSnackbar,
      'Close and reopen the app to apply this change.',
    );
    expect(
      fr.errorReportingRestartSnackbar,
      'Fermez et rouvrez l’application pour appliquer ce changement.',
    );
  });

  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets('error reporting sheet in ${theme.name}', (tester) async {
      final settings = _Settings();
      when(() => settings.stream).thenAnswer((_) => const Stream.empty());
      when(() => settings.toggleErrorReporting(true))
          .thenAnswer((_) async => true);
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

      final loc = SettingsLocalizations.of(
        tester.element(find.byType(BottomSheet)),
      );
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
      expect(find.text(loc.networkRestartDialogAction), findsOneWidget);
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
      ...settingsTestLocalizationsDelegates,
    ],
    supportedLocales: SettingsLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: content)),
  );
  await tester.pumpWidget(wrap?.call(app) ?? app);
  await tester.pumpAndSettle();
}
