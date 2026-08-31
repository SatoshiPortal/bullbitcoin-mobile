import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bip48_account_claim.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';

abstract interface class Bip48AccountRepository {
  @useResult
  Future<Result<int, Bip48AccountAllocationFailure>> nextAvailable({
    required String seedFingerprint,
    required int coinType,
  });

  @useResult
  Future<Result<bool, Bip48AccountAllocationFailure>> isReserved({
    required String seedFingerprint,
    required int coinType,
    required int account,
  });

  @useResult
  Future<Result<Bip48AccountClaim, Bip48AccountAllocationFailure>> claimNext({
    required String seedFingerprint,
    required int coinType,
  });

  @useResult
  Future<Result<Bip48AccountClaim, Bip48AccountAllocationFailure>> claim({
    required String seedFingerprint,
    required int coinType,
    required int account,
  });

  @useResult
  Future<Result<void, Bip48AccountAllocationFailure>> commitClaim({
    required String seedFingerprint,
    required int coinType,
    required Bip48AccountClaim claim,
  });

  @useResult
  Future<Result<void, Bip48AccountAllocationFailure>> releaseClaim({
    required String seedFingerprint,
    required int coinType,
    required Bip48AccountClaim claim,
  });

  @useResult
  Future<Result<void, Bip48AccountAllocationFailure>> reserve({
    required String seedFingerprint,
    required int coinType,
    required int account,
  });
}
