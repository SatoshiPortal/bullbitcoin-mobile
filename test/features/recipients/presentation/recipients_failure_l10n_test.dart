import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/presentation/recipients_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A raw reason shaped like what this API actually returns on failure: a
/// JSON-RPC error object quoting the recipient payload it rejected. It holds
/// server internals AND the user's own banking details, which is why no arm
/// may echo it.
const _iban = 'DE89370400440532013000';
const _phone = '+50688887777';
const _rawReason =
    'DioException [bad response]: {"error":{"code":-32602,'
    '"message":"invalid iban $_iban for phone $_phone",'
    '"data":{"stack":"at RecipientService.create (/srv/api/recipients.js:214)"}}}';

/// One instance of every [RecipientsFailure].
///
/// The `sealed` switch in `toTranslated` already gives compile-time coverage:
/// add a variant and the switch stops compiling. What the compiler cannot
/// check is that each arm resolves to a real, non-empty `.arb` value and that
/// none of them echoes the reason.
final _everyFailure = <RecipientsFailure>[
  const RecipientsLoadFailure(_rawReason),
  const RecipientsSaveFailure(_rawReason),
  const RecipientsSinpeLookupFailure(_rawReason),
  const RecipientsCadBillerSearchFailure(_rawReason),
  const RecipientsNetworkFailure(_rawReason),
  const RecipientsSelectionFailure(_rawReason),
  const RecipientsSavedButNotSelectedFailure(_rawReason),
  const RecipientsUnexpectedFailure(_rawReason),
];

Future<String> _translate(
  WidgetTester tester,
  RecipientsFailure failure,
) async {
  late String message;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          message = failure.toTranslated(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return message;
}

void main() {
  group('RecipientsFailureL10n.toTranslated', () {
    for (final failure in _everyFailure) {
      testWidgets('${failure.runtimeType} resolves to a user-safe message', (
        tester,
      ) async {
        final message = await _translate(tester, failure);

        expect(
          message,
          isNotEmpty,
          reason: 'the .arb key for ${failure.runtimeType} resolved to nothing',
        );
        expect(message, isNot(contains(_rawReason)));
        expect(message, isNot(contains('DioException')));
        // Server internals.
        expect(message, isNot(contains('recipients.js')));
        expect(message, isNot(contains('-32602')));
        // The user's own banking details, which the payload quotes back.
        expect(message, isNot(contains(_iban)));
        expect(message, isNot(contains(_phone)));
      });
    }

    testWidgets('the catch-all reads identically with and without a reason', (
      tester,
    ) async {
      final withReason = await _translate(
        tester,
        const RecipientsUnexpectedFailure(_rawReason),
      );
      final without = await _translate(
        tester,
        const RecipientsUnexpectedFailure(),
      );

      expect(withReason, without);
    });

    testWidgets('a saved-but-not-selected failure must not read as a save '
        'failure, or the user retries and creates a duplicate', (tester) async {
      final savedButNotSelected = await _translate(
        tester,
        const RecipientsSavedButNotSelectedFailure(),
      );
      final saveFailed = await _translate(
        tester,
        const RecipientsSaveFailure(),
      );

      expect(savedButNotSelected, isNot(saveFailed));
      expect(savedButNotSelected.toLowerCase(), contains('saved'));
    });

    testWidgets('a connectivity failure gives advice the others do not', (
      tester,
    ) async {
      final network = await _translate(
        tester,
        const RecipientsNetworkFailure(),
      );
      final load = await _translate(tester, const RecipientsLoadFailure());

      // "check your connection" and "could not load" call for different
      // actions, so they must not collapse into one message.
      expect(network, isNot(load));
    });
  });
}
