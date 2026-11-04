import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Signs the sell payin on either network.
class SignSellPayinUsecase {
  final BitcoinWalletRepository _bitcoinWalletRepository;
  final LiquidWalletRepository _liquidWalletRepository;

  const SignSellPayinUsecase({
    required this._bitcoinWalletRepository,
    required this._liquidWalletRepository,
  });

  /// Signs [psbt] and reports the signed transaction with its vsize.
  @useResult
  Future<Result<({String signedPsbt, int txSize}), SellFailure>> bitcoin({
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
        message: 'Failed to sign the Bitcoin sell payin',
        error: e,
        trace: st,
      );
      return Err(SellUnexpectedFailure('$e'));
    }
  }

  @useResult
  Future<Result<String, SellFailure>> liquid({
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
        message: 'Failed to sign the Liquid sell payin',
        error: e,
        trace: st,
      );
      return Err(SellUnexpectedFailure('$e'));
    }
  }
}
