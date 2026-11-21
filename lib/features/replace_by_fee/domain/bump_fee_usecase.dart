import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show WalletSpendBlockedException, BitcoinSpendStatus;
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:fees/fees.dart';
import 'package:bb_mobile/features/fees/public/app_fee_estimates.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'package:bb_mobile/features/wallet/data/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/transaction_signature_status.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/replace_by_fee_failure.dart';
import 'package:sync/sync.dart'
    show
        SignatureCheck,
        SyncBusyFailure,
        SyncFailure,
        SyncFeeRateTooLowFailure,
        SyncOriginalSignaturesFailure,
        SyncSpendBlockedFailure,
        UnsignedSpend;
import 'package:meta/meta.dart';

class BumpFeeUsecase {
  final BitcoinWalletRepository _bitcoinWalletRepository;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTransactionUsecase;
  final AppFeeEstimates _feeEstimates;

  BumpFeeUsecase({
    required this._bitcoinWalletRepository,
    required this._broadcastBitcoinTransactionUsecase,
    required this._feeEstimates,
  });

  @useResult
  Future<Result<FeeOptions, ReplaceByFeeFailure>> getNetworkFees() async {
    try {
      final fees = await _feeEstimates.execute(isLiquid: false);
      return Ok(fees);
    } catch (e, st) {
      log.warning('Failed to fetch network fees for RBF', error: e, trace: st);
      return const Err(ReplaceByFeeNetworkFeesFailure());
    }
  }

  /// Pre-flight check for the RBF screen: refuses to offer a bump when the
  /// original transaction's signatures don't verify (a planted transaction,
  /// GHSA-6jp4-8v48-cc5v). [execute] re-runs the same check fail-closed.
  @useResult
  Future<Result<void, ReplaceByFeeFailure>> verifyOriginalTransaction({
    required String walletId,
    required String txid,
  }) async {
    try {
      final status = await _bitcoinWalletRepository
          .getTransactionSignatureStatus(walletId: walletId, txid: txid);
      return switch (status) {
        TransactionSignatureStatus.valid => const Ok(null),
        TransactionSignatureStatus.invalid => const Err(
          ReplaceByFeeManipulatedTransactionFailure(),
        ),
        TransactionSignatureStatus.unverifiable => const Err(
          ReplaceByFeeUnverifiableTransactionFailure(),
        ),
      };
    } catch (e, st) {
      log.severe(
        message: 'Failed to verify original transaction for RBF',
        error: e,
        trace: st,
      );
      return Err(ReplaceByFeeUnexpectedFailure(e.toString()));
    }
  }

  /// Builds the replacement in sync's writer, signs it with `secrets`, then
  /// broadcasts it with the generation it was built at.
  @useResult
  Future<Result<String, ReplaceByFeeFailure>> execute({
    required String walletId,
    required String txid,
    required RelativeFee newFeeRate,
    required Network network,
  }) async {
    try {
      final built = await _bitcoinWalletRepository.bumpFee(
        walletId: walletId,
        txid: txid,
        newFeeRate: newFeeRate,
      );
      final UnsignedSpend unsigned;
      switch (built) {
        case Ok(:final value):
          unsigned = value;
        case Err(:final failure):
          return Err(_bumpFailure(failure));
      }
      final signed = await _bitcoinWalletRepository.signPsbt(
        unsigned.encoded,
        walletId: walletId,
      );
      final broadcastedTxid = await _broadcastBitcoinTransactionUsecase.execute(
        signed,
        isPsbt: true,
        network: network,
        walletId: walletId,
        built: unsigned,
      );
      return Ok(broadcastedTxid);
    } on WalletSpendBlockedException catch (e) {
      return Err(
        ReplaceByFeeSpendBlockedFailure(
          replacementPending: e.status == BitcoinSpendStatus.replacementPending,
          busy: e.status == BitcoinSpendStatus.busy,
        ),
      );
    } catch (e, st) {
      log.severe(message: 'Bump fee failed', error: e, trace: st);
      return Err(ReplaceByFeeUnexpectedFailure(e.toString()));
    }
  }

  static ReplaceByFeeFailure _bumpFailure(SyncFailure failure) {
    switch (failure) {
      case SyncOriginalSignaturesFailure(check: SignatureCheck.invalid):
        log.severe(
          message: 'Refused to bump a transaction with invalid signatures',
          error: 'original_signatures',
          trace: StackTrace.current,
        );
        return const ReplaceByFeeManipulatedTransactionFailure();
      case SyncOriginalSignaturesFailure():
        log.warning(
          'Refused to bump a transaction whose signatures could not be verified',
        );
        return const ReplaceByFeeUnverifiableTransactionFailure();
      case SyncFeeRateTooLowFailure():
        log.warning('Replacement fee rate below the original');
        return const ReplaceByFeeFeeRateTooLowFailure();
      case SyncSpendBlockedFailure(:final status):
        return ReplaceByFeeSpendBlockedFailure(
          replacementPending: status == BitcoinSpendStatus.replacementPending,
          busy: false,
        );
      case SyncBusyFailure():
        return const ReplaceByFeeSpendBlockedFailure(
          replacementPending: false,
          busy: true,
        );
      case _:
        log.warning('Bump fee refused category=${failure.logCode}');
        return ReplaceByFeeUnexpectedFailure(failure.logCode);
    }
  }
}
