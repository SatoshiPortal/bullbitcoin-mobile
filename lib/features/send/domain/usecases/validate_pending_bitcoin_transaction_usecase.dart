import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_bitcoin_signing_plan_usecase.dart';
import 'package:meta/meta.dart';

typedef ValidatedPendingBitcoinTransaction = ({
  PendingBitcoinTransaction transaction,
  BitcoinSigningPlanDetails? details,
});

class ValidatePendingBitcoinTransactionUsecase {
  final GetWalletUsecase _getWalletUsecase;
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;
  final BitcoinSigningPort _bitcoinSigningPort;
  final GetBitcoinSigningPlanUsecase _getBitcoinSigningPlanUsecase;

  const ValidatePendingBitcoinTransactionUsecase(
    this._getWalletUsecase,
    this._getWalletUtxosUsecase,
    this._bitcoinSigningPort,
    this._getBitcoinSigningPlanUsecase,
  );

  @useResult
  Future<Result<ValidatedPendingBitcoinTransaction, SendFailure>> execute(
    PendingBitcoinTransaction transaction, {
    Set<String> satisfiedPreimageKeys = const {},
  }) async {
    if (transaction.isDraft) {
      return Ok((transaction: transaction, details: null));
    }
    try {
      final wallet = await _getWalletUsecase.execute(transaction.walletId);
      if (wallet == null || !wallet.isBitcoin) {
        return const Err(SendStoredTransactionInvalidFailure());
      }
      final psbt = transaction.psbt!;
      final BitcoinSigningPlanDetails planDetails;
      switch (await _getBitcoinSigningPlanUsecase.execute(
        wallet: wallet,
        psbt: psbt,
        selection: transaction.policySelection,
        allowSpentWalletInputs: true,
        allowFrozenWalletInputs: true,
        satisfiedPreimageKeys: satisfiedPreimageKeys,
      )) {
        case Ok(:final value):
          planDetails = value;
        case Err(:final failure):
          return Err(
            failure is SendUnexpectedFailure
                ? failure
                : const SendStoredTransactionInvalidFailure(),
          );
      }
      final review = planDetails.review;
      if (review == null) {
        return const Err(SendStoredTransactionInvalidFailure());
      }
      final plan = planDetails.plan;
      var recipient = transaction.recipient;
      if (transaction.stage == PendingBitcoinTransactionStage.payjoinPending) {
        final request = await PaymentRequest.parse(recipient);
        if (request is! Bip21PaymentRequest ||
            request.pj.isEmpty ||
            request.network != wallet.network) {
          return const Err(SendStoredTransactionInvalidFailure());
        }
        recipient = request.address;
      }
      final amountSat = BigInt.parse(transaction.amount);
      final matchingOutputs = review.outputs
          .where(
            (output) =>
                _sameBitcoinAddress(output.address, recipient) &&
                output.amountSat == amountSat,
          )
          .toList(growable: false);
      if (matchingOutputs.length != 1) {
        return const Err(SendStoredTransactionInvalidFailure());
      }
      final recipientOutput = matchingOutputs.single;
      final unexpectedExternalOutput = recipientOutput.isWalletOwned
          ? review.recipients.isNotEmpty
          : review.recipients.length != 1 ||
                review.recipients.single.index != recipientOutput.index;
      if (unexpectedExternalOutput) {
        return const Err(SendStoredTransactionInvalidFailure());
      }
      final hasRequiredPreimages = plan.policy.hasRequiredPreimages(
        transaction.policySelection,
        plan.satisfiedPreimageKeys,
      );
      final policyReady =
          plan.policy.pathRequirements(transaction.policySelection).isEmpty &&
          plan.policy.selectionIsAvailable(
            selection: transaction.policySelection,
            maturity: planDetails.maturity,
            selectedOutpoints: review.outpoints,
          ) &&
          review.timingIsSatisfied(planDetails.maturity) &&
          hasRequiredPreimages;
      final utxos = await _getWalletUtxosUsecase.execute(walletId: wallet.id);
      final availableOutpoints = {
        for (final utxo in utxos)
          if (!utxo.isFrozen) '${utxo.txId}:${utxo.vout}',
      };
      final conflict = review.outpoints.any(
        (outpoint) => !availableOutpoints.contains(outpoint),
      );
      if (transaction.selectedOutpoints.isNotEmpty &&
          !_sameOutpoints(transaction.selectedOutpoints, review.outpoints)) {
        return const Err(SendStoredTransactionInvalidFailure());
      }
      if (transaction.finalTransaction case final finalTransaction?) {
        switch (await _bitcoinSigningPort.verifyFinalTransaction(
          psbt: psbt,
          transaction: finalTransaction,
        )) {
          case Ok():
            break;
          case Err(:final failure):
            return Err(_storedTransactionFailure(failure));
        }
      }
      final ({String psbt, bool isFinalized}) finalized;
      if (transaction.stage == PendingBitcoinTransactionStage.payjoinPending) {
        finalized = (psbt: psbt, isFinalized: false);
      } else if (review.isFinalized) {
        finalized = (psbt: psbt, isFinalized: true);
      } else {
        switch (await _bitcoinSigningPort.finalizePsbt(psbt)) {
          case Ok(:final value):
            finalized = value;
          case Err(:final failure):
            return Err(_storedTransactionFailure(failure));
        }
      }
      final ready =
          transaction.finalTransaction != null || finalized.isFinalized;
      if (transaction.stage ==
              PendingBitcoinTransactionStage.broadcastPending &&
          !ready) {
        return const Err(SendStoredTransactionInvalidFailure());
      }
      return Ok((
        transaction: transaction.copyWith(
          psbt: finalized.psbt,
          stage: transaction.isSubmission
              ? transaction.stage
              : ready
              ? PendingBitcoinTransactionStage.readyToBroadcast
              : PendingBitcoinTransactionStage.needsSignatures,
          isConflict: conflict,
          isPolicyReady: policyReady,
          signersNeeded: ready ? 0 : plan.signersNeeded,
        ),
        details: finalized.psbt == psbt ? planDetails : null,
      ));
    } on FormatException {
      return const Err(SendStoredTransactionInvalidFailure());
    } on ArgumentError {
      return const Err(SendStoredTransactionInvalidFailure());
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Failed to validate a pending Bitcoin transaction',
        error: error,
        trace: stackTrace,
      );
      return Err(SendUnexpectedFailure(error.runtimeType.toString()));
    }
  }
}

bool _sameOutpoints(Set<String> first, Set<String> second) =>
    first.length == second.length && first.containsAll(second);

bool _sameBitcoinAddress(String? first, String second) {
  if (first == null) return false;
  if (first == second) return true;
  final normalizedFirst = first.toLowerCase();
  final normalizedSecond = second.toLowerCase();
  return normalizedFirst == normalizedSecond &&
      (normalizedFirst.startsWith('bc1') ||
          normalizedFirst.startsWith('tb1') ||
          normalizedFirst.startsWith('bcrt1'));
}

SendFailure _storedTransactionFailure(BitcoinSigningFailure failure) =>
    switch (failure.kind) {
      BitcoinSigningFailureKind.unexpected => SendUnexpectedFailure(
        failure.kind.name,
      ),
      _ => const SendStoredTransactionInvalidFailure(),
    };
