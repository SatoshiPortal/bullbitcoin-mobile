import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';
import 'package:meta/meta.dart';

/// Signs the unsigned sweep PSBT with the wallet's own key.
///
/// Deliberately does not reuse `send`'s equivalent use-case: that would import
/// another feature's internals. The overlap is one repository call.
class SignSweepPsbtUsecase {
  final BitcoinWalletRepository _bitcoinWalletRepository;

  SignSweepPsbtUsecase({required this._bitcoinWalletRepository});

  @useResult
  Future<Result<String, SweepFailure>> execute({
    required String walletId,
    required String unsignedPsbt,
  }) async {
    try {
      final signed = await _bitcoinWalletRepository.signPsbt(
        unsignedPsbt,
        walletId: walletId,
      );
      return Ok(signed);
    } catch (e, st) {
      // Never log the PSBT itself — it carries the spending policy and, once
      // signed, the signatures.
      log.severe(message: 'Failed to sign sweep psbt', error: e, trace: st);
      return Err(SweepSignFailure(e.toString()));
    }
  }
}
