import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/presentation/send_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// One concrete instance of every [SendFailure] variant the UI can surface. The
// sealed switch in `toTranslated` already gives compile-time coverage; this
// table locks in that each arm resolves to a non-empty localized string (the
// .arb key exists and is translated), which the switch alone does not guarantee.
//
// `SendSwapLimitsFailure` carries exactly one of min/max per construction (the
// constructor asserts it), so the both-null generic arm is unreachable by
// design and intentionally not exercised here.
final _everyFailure = <SendFailure>[
  const SendInvalidPaymentRequestGenericFailure(),
  const SendUnsupportedQrFormatFailure(),
  const SendInsufficientBalanceFailure(),
  const SendAmountlessInvoiceFailure(),
  const SendExpiredInvoiceFailure(),
  const SendHardwareWalletSwapFailure(),
  const SendSwapCreationGenericFailure(),
  const SendSwapLimitsFailure(minLimit: 1000),
  const SendSwapLimitsFailure(maxLimit: 1000000),
  const SendBuildTransactionFailure(),
  const SendConfirmTransactionFailure(),
  const SendConfirmTransactionFailure(isBroadcastFailure: true),
  const SendUnexpectedFailure(),
];

void main() {
  group('SendFailureL10n.toTranslated', () {
    for (final failure in _everyFailure) {
      testWidgets('${failure.runtimeType} resolves to a non-empty message', (
        tester,
      ) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final message = failure.toTranslated(capturedContext);

        expect(message, isNotEmpty);
        // The raw log reason must never leak into the user-facing string.
        expect(message, isNot(contains('Exception')));
      });
    }
  });
}
