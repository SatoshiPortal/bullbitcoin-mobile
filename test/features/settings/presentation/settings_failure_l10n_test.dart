import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/presentation/settings_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The kind of text a settings write fails with: a storage error naming the
/// database path and the value being written.
const _rawReason =
    'SqliteException(5): database is locked, '
    'UPDATE settings SET currency = "CAD" WHERE id = 1 at /data/user/0';

const _everyFailure = <SettingsFailure>[
  SettingsStorageFailure(_rawReason),
  SettingsConsentFailure(_rawReason),
  SettingsLogsFailure(_rawReason),
  SettingsUnexpectedFailure(_rawReason),
];

Future<String> _translate(WidgetTester tester, SettingsFailure failure) async {
  late String translated;

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          translated = failure.toTranslated(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  return translated;
}

void main() {
  testWidgets('no variant ever renders the raw reason', (tester) async {
    for (final failure in _everyFailure) {
      final message = await _translate(tester, failure);

      expect(message, isNotEmpty);
      expect(
        message,
        isNot(contains('SqliteException')),
        reason: '${failure.runtimeType} leaked an exception class name',
      );
      expect(
        message,
        isNot(contains('/data/user/0')),
        reason: '${failure.runtimeType} leaked a file path',
      );
      expect(
        message,
        isNot(contains(_rawReason)),
        reason: '${failure.runtimeType} rendered logMessage verbatim',
      );
    }
  });

  testWidgets('each mapped failure reads differently from the catch-all', (
    tester,
  ) async {
    final generic = await _translate(tester, const SettingsUnexpectedFailure());

    for (final failure in _everyFailure) {
      if (failure is SettingsUnexpectedFailure) continue;
      expect(
        await _translate(tester, failure),
        isNot(generic),
        reason:
            '${failure.runtimeType} is indistinguishable from the generic '
            'message, so the user learns nothing from it',
      );
    }
  });
}
