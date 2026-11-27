import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/presentation/exchange_failure_l10n.dart';
import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:material_ui/material_ui.dart';
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

/// One instance of every [ExchangeFailure].
///
/// The `sealed` switch in `toTranslated` already gives compile-time coverage:
/// add a variant and the switch stops compiling. What the compiler cannot
/// check is that each arm resolves to a real, non-empty `.arb` value and that
/// none of them echoes the reason.
final _everyFailure = <ExchangeFailure>[
  const ExchangeNotAuthenticatedFailure(),
  const ExchangeRecipientsLoadFailure(_rawReason),
  const ExchangeRecipientsSaveFailure(_rawReason),
  const ExchangeRecipientsSaveOutcomeUnknownFailure(_rawReason),
  const ExchangeRecipientsSinpeLookupFailure(_rawReason),
  const ExchangeRecipientsCadBillerSearchFailure(_rawReason),
  const ExchangeNetworkFailure(_rawReason),
  const ExchangeRecipientsSelectionFailure(_rawReason),
  const ExchangeRecipientsSavedButNotSelectedFailure(_rawReason),
  const ExchangeRecipientsInvalidSecurityDetailsFailure(_rawReason),
  const ExchangeVirtualIbanNotAvailableFailure(_rawReason),
  const ExchangeEuResidencyRequiredFailure(_rawReason),
  const ExchangeUnexpectedFailure(_rawReason),
  ExchangeRecipientsInvalidFieldsFailure.fromFieldErrors(const {
    'email': 'ERR_VALIDATION_REQUIRED',
    'iban': 'ERR_VALIDATION_FORMAT',
  })!,
];

Future<String> _translate(WidgetTester tester, ExchangeFailure failure) async {
  late String message;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
      supportedLocales: ExchangeLocalizations.supportedLocales,
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
  group('ExchangeFailureL10n.toTranslated over the recipients failures', () {
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
        const ExchangeUnexpectedFailure(_rawReason),
      );
      final without = await _translate(
        tester,
        const ExchangeUnexpectedFailure(),
      );

      expect(withReason, without);
    });

    testWidgets('a saved-but-not-selected failure must not read as a save '
        'failure, or the user retries and creates a duplicate', (tester) async {
      final savedButNotSelected = await _translate(
        tester,
        const ExchangeRecipientsSavedButNotSelectedFailure(),
      );
      final saveFailed = await _translate(
        tester,
        const ExchangeRecipientsSaveFailure(),
      );

      expect(savedButNotSelected, isNot(saveFailed));
      expect(savedButNotSelected.toLowerCase(), contains('saved'));
    });

    testWidgets('a connectivity failure gives advice the others do not', (
      tester,
    ) async {
      final network = await _translate(tester, const ExchangeNetworkFailure());
      final load = await _translate(
        tester,
        const ExchangeRecipientsLoadFailure(),
      );

      // "check your connection" and "could not load" call for different
      // actions, so they must not collapse into one message.
      expect(network, isNot(load));
    });
  });

  group('ExchangeRecipientsInvalidFieldsFailure', () {
    final failure = ExchangeRecipientsInvalidFieldsFailure.fromFieldErrors(
      const {
        'email': 'ERR_VALIDATION_REQUIRED',
        'lastname': 'ERR_VALIDATION_STRING',
        'element.extra': 'ERR_VALIDATION_UNEXPECTED',
      },
    )!;

    test('maps known fields and keeps the names of the others', () {
      expect(failure.fields, {
        RecipientField.email: RecipientFieldProblem.missing,
        RecipientField.lastname: RecipientFieldProblem.invalid,
      });
      expect(failure.otherFields, ['element.extra']);
      expect(
        ExchangeRecipientsInvalidFieldsFailure.fromFieldErrors(const {}),
        isNull,
      );
    });

    testWidgets('the summary names only the fields the form does not mark', (
      tester,
    ) async {
      late String partly;
      late String all;
      late ExchangeLocalizations loc;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
          supportedLocales: ExchangeLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              loc = ExchangeLocalizations.of(context);
              partly = failure.summary(context, const {RecipientField.email});
              all = ExchangeRecipientsInvalidFieldsFailure.fromFieldErrors(
                const {'email': 'ERR_VALIDATION_REQUIRED'},
              )!.summary(context, const {RecipientField.email});
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        partly,
        loc.recipientsErrorFieldsRefused('lastname, element.extra'),
      );
      expect(all, loc.recipientsErrorCheckFields);
    });
  });
}
