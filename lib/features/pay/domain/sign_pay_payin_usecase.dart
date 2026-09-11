import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Signs the pay payin on either network.
class SignPayPayinUsecase {
  final BitcoinWalletRepository _bitcoinWalletRepository;
  final LiquidWalletRepository _liquidWalletRepository;

  const SignPayPayinUsecase({
    required this._bitcoinWalletRepository,
    required this._liquidWalletRepository,
  });

  /// Signs [psbt] and reports the signed transaction with its vsize.
  ///
  /// The vsize is measured on the *signed* transaction: the witness is what
  /// decides whether the fee clears the relay floor.
  @useResult
  Future<Result<({String signedPsbt, int txSize}), PayFailure>> bitcoin({
    required String psbt,
    required String walletId,
  }) async {
    try {
      final signedPsbt = await _bitcoinWalletRepository.signPsbt(
        psbt,
        walletId: walletId,
      );
      final txSize = await _bitcoinWalletRepository.getTxSize(psbt: signedPsbt);
      return Ok((signedPsbt: signedPsbt, txSize: txSize));
    } catch (e, st) {
      log.severe(
        message: 'Failed to sign the Bitcoin pay payin',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }
  }

  @useResult
  Future<Result<String, PayFailure>> liquid({
    required String pset,
    required String walletId,
  }) async {
    try {
      final signedPset = await _liquidWalletRepository.signPset(
        pset: pset,
        walletId: walletId,
      );
      return Ok(signedPset);
    } catch (e, st) {
      log.severe(
        message: 'Failed to sign the Liquid pay payin',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }
  }
}
