import 'package:fees/fees.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    as wallet
    show Network, NetworkX;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'package:bb_mobile/features/replace_by_fee/domain/replace_by_fee_failure.dart';
import 'package:meta/meta.dart';
import 'package:spend/spend.dart';

class BumpFeeUsecase {
  final Spend _spend;
  final Fees _fees;

  BumpFeeUsecase({required this._spend, required this._fees});

  @useResult
  Future<Result<FeeOptions, ReplaceByFeeFailure>> getNetworkFees(
    wallet.Network network,
  ) async {
    final captured = network.shared;
    if (captured is! BitcoinNetwork) {
      return const Err(ReplaceByFeeNetworkFeesFailure());
    }
    try {
      switch (await _fees.estimate(captured)) {
        case Ok(:final value):
          return Ok(value);
        case Err(:final failure):
          final reason =
              'Network fee estimation unavailable: ${failure.runtimeType}';
          log.warning(reason);
          return const Err(ReplaceByFeeNetworkFeesFailure());
      }
    } on Exception catch (e, st) {
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
    required wallet.Network network,
  }) async => switch (network.shared) {
    final BitcoinNetwork bitcoin => (await _spend.verifyOriginalBitcoin(
      walletId: walletId,
      originalTxid: txid,
      network: bitcoin,
    )).mapErr(_bumpFailure),
    _ => const Err(ReplaceByFeeUnexpectedFailure()),
  };

  /// Builds the replacement in sync's writer, signs it with `secrets`, then
  /// broadcasts it with the generation it was built at.
  @useResult
  Future<Result<String, ReplaceByFeeFailure>> execute({
    required String walletId,
    required String txid,
    required RelativeFee newFeeRate,
    required wallet.Network network,
  }) async => switch (network.shared) {
    final BitcoinNetwork bitcoin => (await _spend.replaceBitcoin(
      walletId: walletId,
      originalTxid: txid,
      newFeeRate: newFeeRate,
      network: bitcoin,
    )).map((receipt) => receipt.txid).mapErr(_bumpFailure),
    _ => const Err(ReplaceByFeeUnexpectedFailure()),
  };

  static ReplaceByFeeFailure _bumpFailure(SpendFailure failure) {
    switch (failure) {
      case SpendOriginalSignaturesFailure(unverifiable: false):
        log.severe(
          message: 'Refused to bump a transaction with invalid signatures',
          error: 'original_signatures',
          trace: StackTrace.current,
        );
        return const ReplaceByFeeManipulatedTransactionFailure();
      case SpendOriginalSignaturesFailure():
        log.warning(
          'Refused to bump a transaction whose signatures could not be verified',
        );
        return const ReplaceByFeeUnverifiableTransactionFailure();
      case SpendFeeRateTooLowFailure():
        log.warning('Replacement fee rate below the original');
        return const ReplaceByFeeFeeRateTooLowFailure();
      case SpendUnavailableFailure(:final replacementPending, :final busy):
        return ReplaceByFeeSpendBlockedFailure(
          replacementPending: replacementPending,
          busy: busy,
        );
      case _:
        log.warning('Bump fee refused category=${failure.runtimeType}');
        return const ReplaceByFeeUnexpectedFailure();
    }
  }
}
