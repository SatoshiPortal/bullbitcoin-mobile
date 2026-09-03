import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_psbt_review.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';

abstract interface class BitcoinSigningPort {
  @useResult
  Future<Result<BitcoinWalletPolicy, BitcoinSigningFailure>> getPolicy({
    required String walletId,
  });

  @useResult
  Future<Result<BitcoinPolicyMaturity, BitcoinSigningFailure>>
  getPolicyMaturity({
    required String walletId,
    required bool includeTimeBasedLocks,
  });

  @useResult
  Future<Result<({String psbt, bool isFinalized}), BitcoinSigningFailure>>
  signPsbt(
    String psbt, {
    required String walletId,
    bool tryFinalize = true,
    String? signerId,
    String? passphrase,
  });

  @useResult
  Future<Result<BitcoinPsbtReview, BitcoinSigningFailure>> reviewPsbt(
    String psbt, {
    required String walletId,
    bool requireLocalOrigin = true,
    bool allowSpentWalletInputs = false,
  });

  @useResult
  Future<Result<({String psbt, bool isFinalized}), BitcoinSigningFailure>>
  combinePsbts({
    required String currentPsbt,
    required String signedPsbt,
    required String walletId,
    bool tryFinalize = true,
  });

  @useResult
  Future<Result<({String psbt, bool isFinalized}), BitcoinSigningFailure>>
  finalizePsbt(String psbt);

  @useResult
  Future<Result<bool, BitcoinSigningFailure>> validatePolicyPreimage(
    BitcoinPolicyPreimage preimage,
  );

  @useResult
  Future<Result<String, BitcoinSigningFailure>> applyPolicyPreimages({
    required String psbt,
    required List<BitcoinPolicyPreimage> preimages,
  });

  @useResult
  Future<Result<({String transaction, int txSize}), BitcoinSigningFailure>>
  verifyFinalTransaction({required String psbt, required String transaction});

  Future<int> getTxSize({required String psbt, required String walletId});
}
