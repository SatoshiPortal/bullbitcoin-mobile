import 'package:bull_recoverbull/bull_recoverbull.dart' show RecoverBullFeature;
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/presentation/recoverbull_failure_l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['en', 'fr']) {
    testWidgets('storage failures have distinct actionable $locale messages', (
      tester,
    ) async {
      final messages = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: RecoverBullFeature.localizationsDelegates,
          supportedLocales: RecoverBullLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              messages.clear();
              for (final failure in [
                const RecoverBullStorageFullFailure(),
                const RecoverBullStorageDamagedFailure(),
                const RecoverBullJournalFailure(),
              ]) {
                messages.add(failure.toTranslated(context));
              }
              return Text(messages.join('\n'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(messages.toSet(), hasLength(3));
      expect(
        messages.every(
          (message) =>
              message.contains(locale == 'fr' ? 'clé de coffre' : 'vault key'),
        ),
        isTrue,
      );
      expect(
        messages.first,
        contains(locale == 'fr' ? 'Libérez' : 'Free up space'),
      );
      expect(messages[1], contains(locale == 'fr' ? 'endommagées' : 'damaged'));
      expect(messages[2], contains(locale == 'fr' ? 'Réessayez' : 'retry'));
      expect(messages.join(), isNot(contains('SQLite')));
    });
  }
}
