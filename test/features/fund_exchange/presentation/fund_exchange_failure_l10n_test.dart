import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A raw reason of the shape the Bull Bitcoin funding API actually produces.
/// It quotes the JSON-RPC error object, the backend's English sentence and a
/// recipient IBAN — none of it may survive into a user-facing string.
const _rawReason =
    'getUserPaymentProcessorCode API error [ERR_ORD_CSRCP400]: '
    'Please activate virtual payment for recipient DE89370400440532013000';

final _everyFailure = <FundExchangeFailure>[
  const FundExchangePaymentOptionUnavailableFailure(_rawReason),
  const FundExchangeOptionNotPermittedFailure(_rawReason),
  const FundExchangeSinpeNotRegisteredFailure(_rawReason),
  const FundExchangeKycIncompleteFailure(_rawReason),
  const FundExchangeCopRequestInvalidFailure(_rawReason),
  const FundExchangeSepaVirtualPaymentInactiveFailure(_rawReason),
  const FundExchangeRequestInvalidFailure(_rawReason),
  const FundExchangeNoInstitutionsFailure(_rawReason),
  const FundExchangeConsentRegistrationFailure(_rawReason),
  const FundExchangeUnexpectedFailure(_rawReason),
];

Future<String?> _translateTitle(
  WidgetTester tester,
  FundExchangeFailure failure,
) async {
  late String? title;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          title = failure.toTranslatedTitle(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return title;
}

Future<String> _translate(
  WidgetTester tester,
  FundExchangeFailure failure,
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
  group('FundExchangeFailureL10n.toTranslated', () {
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
        expect(message, isNot(contains('ERR_')));
        expect(message, isNot(contains('Exception')));
        expect(
          message,
          isNot(contains('DE89370400440532013000')),
          reason: 'the recipient IBAN must never reach the screen',
        );
      });
    }

    testWidgets('titles are user-safe and never carry the raw reason', (
      tester,
    ) async {
      for (final failure in _everyFailure) {
        final title = await _translateTitle(tester, failure);
        if (title == null) continue;

        expect(title, isNotEmpty);
        expect(title, isNot(contains(_rawReason)));
        expect(title, isNot(contains('ERR_')));
        expect(
          title,
          isNot(contains('DE89370400440532013000')),
          reason: 'the recipient IBAN must never reach the screen',
        );
      }
    });

    testWidgets('the generic failures stay title-less', (tester) async {
      for (final failure in [
        const FundExchangeNoInstitutionsFailure(_rawReason),
        const FundExchangeConsentRegistrationFailure(_rawReason),
        const FundExchangeUnexpectedFailure(_rawReason),
      ]) {
        expect(
          await _translateTitle(tester, failure),
          isNull,
          reason: '${failure.runtimeType} should render as a bare message',
        );
      }
    });

    testWidgets('the message never depends on the raw reason', (tester) async {
      final withReason = await _translate(
        tester,
        const FundExchangeSepaVirtualPaymentInactiveFailure(_rawReason),
      );
      final withoutReason = await _translate(
        tester,
        const FundExchangeSepaVirtualPaymentInactiveFailure(),
      );

      expect(withReason, withoutReason);
    });

    testWidgets('each mapped code reads differently from the catch-all', (
      tester,
    ) async {
      final generic = await _translate(
        tester,
        const FundExchangeUnexpectedFailure(),
      );

      for (final failure in _everyFailure) {
        if (failure is FundExchangeUnexpectedFailure) continue;
        // The consent failure deliberately shares the generic copy: there is
        // nothing actionable to say beyond "try again".
        if (failure is FundExchangeConsentRegistrationFailure) continue;
        expect(
          await _translate(tester, failure),
          isNot(generic),
          reason:
              '${failure.runtimeType} is indistinguishable from the '
              'generic message',
        );
      }
    });
  });
}
