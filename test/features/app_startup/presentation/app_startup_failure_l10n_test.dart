import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bb_mobile/features/app_startup/presentation/app_startup_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Startup sits directly on top of the seed and keychain reads, so a raw
/// reason here can quote key material or a keychain error naming it.
const _rawReason =
    'PlatformException(-25308, errSecInteractionNotAllowed, '
    'seed_a1b2c3d4 legal winner thank year, null)';

final _everyFailure = <AppStartupFailure>[
  const AppStartupKeychainLockedFailure(_rawReason),
  const AppStartupWalletCheckFailure(_rawReason),
  const AppStartupLegacyCheckFailure(_rawReason),
  const AppStartupLegacySeedsFailure(_rawReason),
  const AppStartupResetFailure(_rawReason),
  const AppStartupPinCheckFailure(_rawReason),
];

Future<String> _translate(WidgetTester tester, AppStartupFailure f) async {
  late String message;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          message = f.toTranslated(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return message;
}

void main() {
  group('AppStartupFailureL10n.toTranslated', () {
    for (final failure in _everyFailure) {
      testWidgets('${failure.runtimeType} resolves to a user-safe message', (
        tester,
      ) async {
        final message = await _translate(tester, failure);

        expect(message, isNotEmpty);
        expect(message, isNot(contains(_rawReason)));
        expect(message, isNot(contains('PlatformException')));
        expect(message, isNot(contains('-25308')));
        // Seed material quoted by the keychain error must never survive.
        expect(message, isNot(contains('seed_a1b2c3d4')));
        expect(message, isNot(contains('legal winner')));
      });
    }

    test('toString never exposes logMessage, even when one is set', () {
      // These fixtures are built WITH a reason, so this does not prove the
      // production construction sites pass none — the use-case tests do that.
      // What it guards is the other half: Failure has no toString() override
      // today, so a failure held in bloc state cannot leak its reason into a
      // state dump. Adding one would be a natural debugging convenience and
      // would silently turn every logMessage into a disclosure.
      for (final failure in _everyFailure) {
        expect(failure.toString(), isNot(contains(_rawReason)));
        expect(failure.toString(), isNot(contains('legal winner')));
      }
    });

    testWidgets('every variant reads the same, by design', (tester) async {
      // Startup has no wallet, session or screen to return to, so there is no
      // action to offer beyond the support link the screen already shows.
      // This pins that deliberate choice: if someone adds per-variant copy,
      // this fails and they have to justify it.
      final messages = <String>{};
      for (final failure in _everyFailure) {
        messages.add(await _translate(tester, failure));
      }

      expect(messages, hasLength(1));
    });
  });
}
