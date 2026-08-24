import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';

class ValidateBitcoinPolicyPreimageUsecase {
  final BitcoinSigningPort _bitcoinSigningPort;

  ValidateBitcoinPolicyPreimageUsecase(this._bitcoinSigningPort);

  @useResult
  Future<Result<BitcoinPolicyPreimage?, BitcoinSigningFailure>> execute({
    required BitcoinHashlockPolicyNode hashlock,
    required String preimageHex,
  }) async {
    try {
      final preimage = BitcoinPolicyPreimage(
        type: hashlock.type,
        hash: hashlock.hash,
        preimageHex: preimageHex.trim(),
      );
      return switch (await _bitcoinSigningPort.validatePolicyPreimage(
        preimage,
      )) {
        Ok(:final value) => Ok(value ? preimage : null),
        Err(:final failure) => Err(failure),
      };
    } on ArgumentError {
      return const Ok(null);
    }
  }
}
