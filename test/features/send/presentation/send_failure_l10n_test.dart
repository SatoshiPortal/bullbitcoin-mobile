import 'package:bb_mobile/core/primitives/payment_network.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/presentation/send_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A raw reason of the shape a foreign SDK would produce. Every variant below
/// carries it in `logMessage` so the assertions can prove it never survives
/// into the translated string.
const _rawReason = 'BdkException: secret-detail xprv9s21ZrQH143K3';

/// One instance of every [SendFailure] the send flow can surface, including the
/// field combinations that select a different l10n arm (`isUnsupportedQr`,
/// min vs max bound, `isBroadcastFailure`, known vs unknown swap networks).
///
/// The `sealed` switch in `toTranslated` already gives compile-time coverage:
/// add a variant and the switch stops compiling. What the compiler cannot check
/// is that each arm resolves to a real, non-empty `.arb` value and that no arm
/// echoes the raw reason — that is what this table locks in.
final _everyFailure = <SendFailure>[
  const SendInvalidPaymentRequestFailure(logMessage: _rawReason),
  const SendInvalidPaymentRequestFailure(
    isUnsupportedQr: true,
    logMessage: _rawReason,
  ),
  const SendInvoiceExpiredFailure(_rawReason),
  const SendInvoiceAmountRequiredFailure(_rawReason),
  const SendHardwareWalletFailure(_rawReason),
  const SendInsufficientBalanceFailure(_rawReason),
  const SendInsufficientFundsForFeesFailure(_rawReason),
  const SendSelectedCoinsUnavailableFailure(_rawReason),
  const SendSelectedCoinsInsufficientFailure(_rawReason),
  SendAmountOutOfBoundsFailure(
    minimumSat: BigInt.from(1000),
    logMessage: _rawReason,
  ),
  SendAmountOutOfBoundsFailure(
    maximumSat: BigInt.from(1000000),
    logMessage: _rawReason,
  ),
  const SendAmountOutOfBoundsFailure(logMessage: _rawReason),
  const SendSwapCreationFailure(_rawReason),
  const SendSwapRouteUnavailableFailure(
    inNetwork: PaymentNetwork.bitcoin,
    outNetwork: PaymentNetwork.lightning,
    logMessage: _rawReason,
  ),
  const SendSwapRouteUnavailableFailure(logMessage: _rawReason),
  const SendRateLimitedFailure(
    retryAfter: Duration(seconds: 45),
    logMessage: _rawReason,
  ),
  const SendTransactionBuildFailure(_rawReason),
  const SendFeeBelowRelayFloorFailure(_rawReason),
  const SendFeesUnavailableFailure(_rawReason),
  const SendExchangeOrderMismatchFailure(_rawReason),
  const SendTransactionConfirmationFailure(logMessage: _rawReason),
  const SendTransactionConfirmationFailure(
    isBroadcastFailure: true,
    logMessage: _rawReason,
  ),
  const SendUnexpectedFailure(_rawReason),
];

Future<String> _translate(
  WidgetTester tester,
  SendFailure failure, {
  Locale? locale,
}) async {
  late String message;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
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
  group('SendFailureL10n.toTranslated', () {
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
        // The raw reason is for logs and Sentry only. None of it — the
        // exception type, nor any key material it may quote — may appear.
        expect(message, isNot(contains(_rawReason)));
        expect(message, isNot(contains('Exception')));
        expect(message, isNot(contains('xprv')));
      });
    }

    testWidgets('an unsupported QR reads differently from an invalid request', (
      tester,
    ) async {
      final invalid = await _translate(
        tester,
        const SendInvalidPaymentRequestFailure(),
      );
      final unsupported = await _translate(
        tester,
        const SendInvalidPaymentRequestFailure(isUnsupportedQr: true),
      );

      expect(invalid, isNot(unsupported));
    });

    testWidgets('a broadcast failure reads differently from a confirm one', (
      tester,
    ) async {
      final confirm = await _translate(
        tester,
        const SendTransactionConfirmationFailure(),
      );
      final broadcast = await _translate(
        tester,
        const SendTransactionConfirmationFailure(isBroadcastFailure: true),
      );

      expect(confirm, isNot(broadcast));
    });

    // #1895: "Build Failed" used to be shown for ten unrelated causes, several
    // of them actionable. Each distinct problem must now read differently, or
    // the user cannot tell "raise the fee" from "start again".
    testWidgets('the build-stage failures each read differently', (
      tester,
    ) async {
      final messages = <String>[
        await _translate(tester, const SendTransactionBuildFailure()),
        await _translate(tester, const SendFeeBelowRelayFloorFailure()),
        await _translate(tester, const SendFeesUnavailableFailure()),
        await _translate(tester, const SendExchangeOrderMismatchFailure()),
        await _translate(tester, const SendUnexpectedFailure()),
      ];

      expect(
        messages.toSet(),
        hasLength(messages.length),
        reason: 'two distinct build-stage problems share a message: $messages',
      );
    });

    testWidgets('a fee below the relay floor tells the user to raise it', (
      tester,
    ) async {
      final message = await _translate(
        tester,
        const SendFeeBelowRelayFloorFailure(),
      );

      expect(message.toLowerCase(), contains('fee'));
      expect(
        message,
        isNot(contains('Build')),
        reason: 'this was the case most badly hidden behind "Build Failed"',
      );
    });

    testWidgets('each amount bound names its own limit', (tester) async {
      final below = await _translate(
        tester,
        SendAmountOutOfBoundsFailure(minimumSat: BigInt.from(1000)),
      );
      final above = await _translate(
        tester,
        SendAmountOutOfBoundsFailure(maximumSat: BigInt.from(1000000)),
      );

      expect(below, contains('1000'));
      expect(above, contains('1000000'));
      expect(below, isNot(above));
    });
  });

  // The table above proves every variant resolves to *something* safe. These
  // pin the exact wording of the coin-selection messages in both shipped
  // locales, so a careless .arb edit is caught rather than silently reworded.
  testWidgets('selected coin failures use the English messages', (
    tester,
  ) async {
    expect(
      await _translate(
        tester,
        const SendSelectedCoinsUnavailableFailure(),
        locale: const Locale('en'),
      ),
      'One or more selected coins are no longer available. Review your coin selection and try again.',
    );
    expect(
      await _translate(
        tester,
        const SendSelectedCoinsInsufficientFailure(),
        locale: const Locale('en'),
      ),
      'The selected coins do not cover the amount and fees. Select more coins or reduce the amount.',
    );
  });

  testWidgets('selected coin failures use the French messages', (tester) async {
    expect(
      await _translate(
        tester,
        const SendSelectedCoinsUnavailableFailure(),
        locale: const Locale('fr'),
      ),
      'Un ou plusieurs coins sélectionnés ne sont plus disponibles. Vérifiez votre sélection et réessayez.',
    );
    expect(
      await _translate(
        tester,
        const SendSelectedCoinsInsufficientFailure(),
        locale: const Locale('fr'),
      ),
      'Les coins sélectionnés ne couvrent pas le montant et les frais. Sélectionnez plus de coins ou réduisez le montant.',
    );
  });
}
