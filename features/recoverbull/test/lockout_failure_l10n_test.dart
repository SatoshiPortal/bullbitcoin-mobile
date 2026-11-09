import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/presentation/recoverbull_failure_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['en', 'fr']) {
    testWidgets('lockout durations are readable in $locale', (tester) async {
      final cases = [
        (const Duration(days: 2, hours: 3), '2 days', '2 jours'),
        (const Duration(days: 1), '1 day', '1 jour'),
        (const Duration(minutes: 1398), '23 hours', '23 heures'),
        (const Duration(hours: 1), '1 hour', '1 heure'),
        (const Duration(minutes: 59, seconds: 59), '59 minutes', '59 minutes'),
        (const Duration(minutes: 1), '1 minute', '1 minute'),
        (const Duration(seconds: 59), '59 seconds', '59 secondes'),
        (const Duration(seconds: 1), '1 second', '1 seconde'),
        (const Duration(milliseconds: 500), '1 second', '1 seconde'),
        (Duration.zero, '1 second', '1 seconde'),
        (const Duration(seconds: -1), '1 second', '1 seconde'),
      ];
      final messages = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates:
              RecoverBullLocalizations.localizationsDelegates,
          supportedLocales: RecoverBullLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              messages.clear();
              for (final (duration, _, _) in cases) {
                messages.add(
                  KeyServerFailure(
                    KeyServerFailureKind.locked,
                    retryAfter: duration,
                  ).toTranslated(context),
                );
              }
              final loc = RecoverBullLocalizations.of(context);
              expect(
                const KeyServerFailure(
                  KeyServerFailureKind.locked,
                ).toTranslated(context),
                loc.recoverbullLockoutAlert,
              );
              expect(
                const KeyServerFailure(
                  KeyServerFailureKind.credentials,
                  retryAfter: Duration(hours: 2),
                ).toTranslated(context),
                loc.recoverbullErrorInvalidCredentials,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < cases.length; i++) {
        final (_, english, french) = cases[i];
        expect(
          messages[i],
          contains(
            locale == 'fr'
                ? 'réessayez dans $french.'
                : 'try again in $english.',
          ),
          reason: 'Retry delay: ${cases[i].$1}',
        );
      }
    });
  }
}
