import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/backup_test_status_row.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Use the app font for layout checks, rather than Flutter's synthetic test
  // font whose unusually wide glyphs do not represent this screen.
  setUpAll(() async {
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });
  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets(
      'shared backup date includes the year and local time (${theme.name})',
      (tester) async {
        final testedAt = DateTime.utc(2026, 9, 12, 16, 42);
        await tester.pumpWidget(_app(theme, testedAt: testedAt));
        final context = tester.element(find.byType(BackupTestStatusRow));
        final material = MaterialLocalizations.of(context);
        final local = testedAt.toLocal();
        final date =
            '${material.formatFullDate(local)}, '
            '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
        expect(
          find.text(context.loc.backupSettingsTestedOn(date)),
          findsOneWidget,
        );
        expect(date, contains(local.year.toString()));
        expect(find.text(context.loc.backupSettingsTested), findsOneWidget);
        final text = tester.widget<Text>(
          find.text(context.loc.backupSettingsTested),
        );
        expect(text.style!.color, context.appColors.success);
      },
    );

    testWidgets('untested has no manufactured date (${theme.name})', (
      tester,
    ) async {
      await tester.pumpWidget(_app(theme));
      final context = tester.element(find.byType(BackupTestStatusRow));
      expect(find.text(context.loc.backupSettingsNotTested), findsOneWidget);
      expect(find.byType(Text), findsNWidgets(2));
      final text = tester.widget<Text>(
        find.text(context.loc.backupSettingsNotTested),
      );
      expect(text.style!.color, context.appColors.error);
    });

    testWidgets('unavailable is neutral and dateless (${theme.name})', (
      tester,
    ) async {
      await tester.pumpWidget(_app(theme, unavailable: true));
      final context = tester.element(find.byType(BackupTestStatusRow));
      expect(find.text(context.loc.backupSettingsComingSoon), findsOneWidget);
      expect(find.text(context.loc.backupSettingsTested), findsNothing);
      expect(find.text(context.loc.backupSettingsNotTested), findsNothing);
      expect(find.byType(Text), findsNWidgets(2));
      final text = tester.widget<Text>(
        find.text(context.loc.backupSettingsComingSoon),
      );
      expect(text.style!.color, context.appColors.onSurfaceVariant);
      expect(text.style!.color, isNot(context.appColors.error));
      expect(text.style!.color, isNot(context.appColors.success));
    });
  }

  testWidgets('long source names fit a narrow screen with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 915);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        AppThemeType.light,
        testedAt: DateTime.utc(2026, 9, 12),
        textScale: 2,
      ),
    );
    expect(find.byType(BackupTestStatusRow), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  AppThemeType theme, {
  DateTime? testedAt,
  double textScale = 1,
  bool unavailable = false,
}) => MaterialApp(
  theme: AppTheme.themeData(theme),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: unavailable
          ? const BackupTestStatusRow.unavailable(label: 'Bitcoin · OP_RETURN')
          : BackupTestStatusRow(
              label: 'BULL Data Backup server · BIP138',
              testedAt: testedAt,
            ),
    ),
  ),
);
