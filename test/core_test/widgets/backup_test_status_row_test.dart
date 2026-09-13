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
      'uses the existing local mnemonic-backup date format (${theme.name})',
      (tester) async {
        final testedAt = DateTime.utc(2026, 9, 12, 16, 42);
        await tester.pumpWidget(_app(theme, testedAt: testedAt));
        final context = tester.element(find.byType(BackupTestStatusRow));
        final material = MaterialLocalizations.of(context);
        final local = testedAt.toLocal();
        final date =
            '${material.formatMediumDate(local)}, '
            '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
        expect(
          find.text(context.loc.backupSettingsTestedOn(date)),
          findsOneWidget,
        );
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
  }

  testWidgets('long source names fit a narrow screen with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 915);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(AppThemeType.light, textScale: 2));
    expect(find.byType(BackupTestStatusRow), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(AppThemeType theme, {DateTime? testedAt, double textScale = 1}) =>
    MaterialApp(
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
          child: BackupTestStatusRow(
            label: 'BULL Data Backup server · BIP138',
            testedAt: testedAt,
          ),
        ),
      ),
    );
