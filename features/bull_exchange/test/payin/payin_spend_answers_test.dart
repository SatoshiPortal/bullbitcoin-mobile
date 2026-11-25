import 'package:bull_exchange/src/payin/payin_spend_answers.dart';
import 'package:bull_payjoin/bull_payjoin.dart' show PayjoinStatus;
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

final _failures = <SpendFailure>[
  const SpendInsufficientFundsFailure(),
  const SpendInsufficientFundsForFeesFailure(),
  const SpendFeeRateTooLowFailure(),
  const SpendOriginalSignaturesFailure(unverifiable: false),
  const SpendNoSpendableInputsFailure(),
  const SpendSelectedInputsUnavailableFailure(),
  const SpendNetworkMismatchFailure(),
  const SpendDeveloperAuthorizationFailure(),
  const SpendSignedTransactionMismatchFailure(),
  const SpendInvalidRequestFailure(),
  const SpendInvalidTransactionFailure(),
  const SpendSigningRefusedFailure(),
  const SpendUnavailableFailure(busy: true),
  const SpendBuildRefusedFailure(),
  const SpendConsolidationRequiredFailure(),
  const SpendBroadcastRejectedFailure(SpendBroadcastRejection.nodeRejected),
  const SpendBroadcastConnectionFailure(),
  const SpendAlreadyInChainFailure(),
  const SpendBroadcastOutcomeUnknownFailure(),
  SpendConsolidationInterruptedFailure(
    const [],
    const SpendUnexpectedFailure(),
  ),
  const SpendPayjoinUnavailableFailure(),
  const SpendUnexpectedFailure(),
];

void main() {
  group('payinBroadcastOf', () {
    test('an accepted broadcast carries the receipt txid', () {
      expect(
        payinBroadcastOf(
          const Ok((txid: 'tx-node', guarded: true, durable: true)),
          txid: 'tx1',
        ),
        const PayinBroadcastAccepted('tx-node'),
      );
    });

    test('only a refusal or a pre-send check says nothing went out', () {
      final outcomes = {
        for (final failure in _failures)
          failure.runtimeType: payinBroadcastOf(Err(failure), txid: 'tx1'),
      };
      expect(outcomes, {
        for (final failure in _failures)
          failure.runtimeType: switch (failure) {
            SpendBroadcastRejectedFailure() => const PayinBroadcastRefused(
              PayinRefusal.nodeRejected,
            ),
            SpendBroadcastConnectionFailure() => const PayinBroadcastNotSent(
              PayinNotSentReason.noConnection,
            ),
            SpendUnavailableFailure() => const PayinBroadcastNotSent(
              PayinNotSentReason.walletBusy,
            ),
            SpendDeveloperAuthorizationFailure() => const PayinBroadcastNotSent(
              PayinNotSentReason.notAuthorized,
            ),
            _ => const PayinBroadcastOutcomeUnknown('tx1'),
          },
      });
    });

    test('already in a block and unknown are never a refusal', () {
      for (final failure in const [
        SpendAlreadyInChainFailure(),
        SpendBroadcastOutcomeUnknownFailure(),
      ]) {
        expect(
          payinBroadcastOf(Err(failure), txid: 'tx1'),
          const PayinBroadcastOutcomeUnknown('tx1'),
        );
      }
    });
  });

  test('build failures name why nothing was sent', () {
    expect(
      {
        for (final failure in _failures)
          failure.runtimeType: payinBuildProblemOf(failure),
      },
      {
        SpendInsufficientFundsFailure: PayinBuildProblem.insufficientFunds,
        SpendInsufficientFundsForFeesFailure:
            PayinBuildProblem.insufficientFunds,
        SpendFeeRateTooLowFailure: PayinBuildProblem.feeTooLow,
        SpendOriginalSignaturesFailure: PayinBuildProblem.signingRefused,
        SpendNoSpendableInputsFailure: PayinBuildProblem.insufficientFunds,
        SpendSelectedInputsUnavailableFailure:
            PayinBuildProblem.insufficientFunds,
        SpendNetworkMismatchFailure: PayinBuildProblem.invalid,
        SpendDeveloperAuthorizationFailure: PayinBuildProblem.notAuthorized,
        SpendSignedTransactionMismatchFailure: PayinBuildProblem.signingRefused,
        SpendInvalidRequestFailure: PayinBuildProblem.invalid,
        SpendInvalidTransactionFailure: PayinBuildProblem.invalid,
        SpendSigningRefusedFailure: PayinBuildProblem.signingRefused,
        SpendUnavailableFailure: PayinBuildProblem.walletBusy,
        SpendBuildRefusedFailure: PayinBuildProblem.invalid,
        SpendConsolidationRequiredFailure:
            PayinBuildProblem.consolidationRequired,
        SpendBroadcastRejectedFailure: PayinBuildProblem.unexpected,
        SpendBroadcastConnectionFailure: PayinBuildProblem.unexpected,
        SpendAlreadyInChainFailure: PayinBuildProblem.unexpected,
        SpendBroadcastOutcomeUnknownFailure: PayinBuildProblem.unexpected,
        SpendConsolidationInterruptedFailure: PayinBuildProblem.unexpected,
        SpendPayjoinUnavailableFailure: PayinBuildProblem.unexpected,
        SpendUnexpectedFailure: PayinBuildProblem.unexpected,
      },
    );
  });

  group('payjoinProgressFrom', () {
    PayjoinProgress progress(
      PayjoinStatus status, {
      bool spendBlocked = false,
      String? txid,
      String? originalTxid = 'otx',
    }) => payjoinProgressFrom(
      status: status,
      spendBlocked: spendBlocked,
      txid: txid,
      originalTxid: originalTxid,
    );

    test('an ongoing session negotiates, or is paused while blocked', () {
      for (final status in [
        PayjoinStatus.started,
        PayjoinStatus.requested,
        PayjoinStatus.proposed,
      ]) {
        expect(progress(status), isA<PayjoinNegotiating>());
        expect(progress(status, spendBlocked: true), isA<PayjoinPaused>());
      }
    });

    test('a completed session sent the payjoin, else the original', () {
      expect(
        progress(PayjoinStatus.completed, txid: 'pjtx'),
        isA<PayjoinSent>().having((p) => p.txid, 'txid', 'pjtx'),
      );
      expect(
        progress(PayjoinStatus.completed),
        isA<PayjoinSent>().having((p) => p.txid, 'txid', 'otx'),
      );
    });

    test('an aborted session sent the original', () {
      expect(
        progress(PayjoinStatus.aborted, txid: 'pjtx'),
        isA<PayjoinSent>().having((p) => p.txid, 'txid', 'otx'),
      );
    });

    test('no txid to follow, or an expiry, is looked up (SELL-3)', () {
      expect(progress(PayjoinStatus.expired), isA<PayjoinExpired>());
      expect(
        progress(PayjoinStatus.completed, originalTxid: null),
        isA<PayjoinExpired>(),
      );
      expect(
        progress(PayjoinStatus.aborted, originalTxid: null),
        isA<PayjoinExpired>(),
      );
    });
  });
}
