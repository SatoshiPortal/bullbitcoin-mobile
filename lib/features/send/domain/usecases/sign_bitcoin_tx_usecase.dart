import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';

typedef SignedBitcoinTransaction = ({
  String signedPsbt,
  int txSize,
  bool isFinalized,
});

class SignBitcoinTxUsecase {
  final BitcoinSigningPort _bitcoinSigningPort;

  SignBitcoinTxUsecase(this._bitcoinSigningPort);

  Future<Result<SignedBitcoinTransaction, BitcoinSigningFailure>> execute({
    required String psbt,
    required String walletId,
    String? externalPsbt,
    bool requireFinalized = true,
    bool tryFinalize = true,
    String? signerId,
  }) async {
    final signingResult = externalPsbt == null
        ? await _bitcoinSigningPort.signPsbt(
            psbt,
            walletId: walletId,
            tryFinalize: tryFinalize,
            signerId: signerId,
          )
        : await _bitcoinSigningPort.combinePsbts(
            currentPsbt: psbt,
            signedPsbt: externalPsbt,
            walletId: walletId,
            tryFinalize: tryFinalize,
          );
    final ({String psbt, bool isFinalized}) signed;
    switch (signingResult) {
      case Ok(:final value):
        signed = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (requireFinalized && !signed.isFinalized) {
      return const Err(
        BitcoinSigningFailure(BitcoinSigningFailureKind.incomplete),
      );
    }
    try {
      final size = await _bitcoinSigningPort.getTxSize(
        psbt: signed.psbt,
        walletId: walletId,
      );
      return Ok((
        signedPsbt: signed.psbt,
        txSize: size,
        isFinalized: signed.isFinalized,
      ));
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Failed to calculate signed Bitcoin transaction size',
        error: error,
        trace: stackTrace,
      );
      return const Err(
        BitcoinSigningFailure(BitcoinSigningFailureKind.unexpected),
      );
    }
  }
}
