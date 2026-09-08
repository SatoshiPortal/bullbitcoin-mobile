import 'package:bb_mobile/core/primitives/payment_network.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bb_mobile/features/receive/presentation/receive_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A raw reason of the shape a foreign SDK or a driver would produce. Every
/// variant below carries it in `logMessage` so the assertions can prove it
/// never survives into the translated string.
const _rawReason =
    'DriftRemoteException: locked at /data/user/0/app.sqlite (nginx 10.0.0.7)';

/// One instance of every [ReceiveFailure], including the field combinations
/// that select a different l10n arm (min vs max bound, known vs unknown swap
/// networks, a rate limit with and without a retry hint).
///
/// The `sealed` switch in `toTranslated` already gives compile-time coverage:
/// add a variant and the switch stops compiling. What the compiler cannot
/// check is that each arm resolves to a real, non-empty `.arb` value and that
/// no arm echoes the raw reason — which is the entire point of this migration,
/// and would otherwise be unpinned by any test in it.
final _everyFailure = <ReceiveFailure>[
  ReceiveAmountOutOfBoundsFailure(
    limitAmountSat: BigInt.from(1000),
    isMinimum: true,
    logMessage: _rawReason,
  ),
  ReceiveAmountOutOfBoundsFailure(
    limitAmountSat: BigInt.from(25000000),
    logMessage: _rawReason,
  ),
  const ReceiveAmountOutOfBoundsFailure(logMessage: _rawReason),
  const ReceiveInvalidInvoiceFailure(_rawReason),
  const ReceiveSwapUnavailableFailure(_rawReason),
  const ReceiveSwapRouteUnavailableFailure(
    inNetwork: PaymentNetwork.lightning,
    outNetwork: PaymentNetwork.liquid,
    logMessage: _rawReason,
  ),
  const ReceiveSwapRouteUnavailableFailure(logMessage: _rawReason),
  const ReceiveNetworkFailure(_rawReason),
  const ReceiveRateLimitedFailure(
    retryAfter: Duration(seconds: 45),
    logMessage: _rawReason,
  ),
  const ReceiveRateLimitedFailure(logMessage: _rawReason),
  const ReceiveAmountAboveProtocolLimitFailure(
    limitAmountSat: 2100000000000000,
    logMessage: _rawReason,
  ),
  const ReceiveNoteNotSavedFailure(_rawReason),
  const ReceiveAddressUnavailableFailure(_rawReason),
  const ReceivePayjoinUnavailableFailure(_rawReason),
  const ReceivePayjoinSettingFailure(_rawReason),
  const ReceivePayjoinPolicyUnavailableFailure(_rawReason),
  const ReceiveBroadcastOriginalTxFailure(_rawReason),
  const ReceiveBroadcastOriginalTxUnavailableFailure(_rawReason),
  const ReceiveUnexpectedFailure(_rawReason),
];

Future<String> _translate(WidgetTester tester, ReceiveFailure failure) async {
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
  group('ReceiveFailureL10n.toTranslated', () {
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
        // The raw reason is for logs and Sentry only. Neither it, nor the
        // exception type, nor the filesystem path or host it quotes, may
        // appear on screen.
        expect(message, isNot(contains(_rawReason)));
        expect(message, isNot(contains('Exception')));
        expect(message, isNot(contains('app.sqlite')));
        expect(message, isNot(contains('10.0.0.7')));
      });
    }

    testWidgets('the catch-all reads identically with and without a reason', (
      tester,
    ) async {
      final withReason = await _translate(
        tester,
        const ReceiveUnexpectedFailure(_rawReason),
      );
      final without = await _translate(
        tester,
        const ReceiveUnexpectedFailure(),
      );

      expect(withReason, without);
    });

    testWidgets('a swap bound names the limit so the user can act on it', (
      tester,
    ) async {
      final message = await _translate(
        tester,
        ReceiveAmountOutOfBoundsFailure(
          limitAmountSat: BigInt.from(1000),
          isMinimum: true,
        ),
      );

      expect(message, contains('1000'));
    });

    testWidgets('a rate limit without a hint still names a wait', (
      tester,
    ) async {
      final message = await _translate(
        tester,
        const ReceiveRateLimitedFailure(),
      );

      expect(message, contains('30'));
    });
  });
}
