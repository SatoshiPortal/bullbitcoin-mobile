import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';

class ApplyBitcoinPolicyPreimagesUsecase {
  final BitcoinSigningPort _bitcoinSigningPort;

  ApplyBitcoinPolicyPreimagesUsecase(this._bitcoinSigningPort);

  @useResult
  Future<Result<String, BitcoinSigningFailure>> execute({
    required String psbt,
    required Iterable<BitcoinPolicyPreimage> preimages,
  }) => _bitcoinSigningPort.applyPolicyPreimages(
    psbt: psbt,
    preimages: preimages.toList(growable: false),
  );
}
