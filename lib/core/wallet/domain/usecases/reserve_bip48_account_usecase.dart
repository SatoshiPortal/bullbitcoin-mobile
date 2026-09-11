import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bip48_account_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';

class ReserveBip48AccountUsecase {
  final Bip48AccountRepository _repository;

  const ReserveBip48AccountUsecase(this._repository);

  @useResult
  Future<Result<int, Bip48AccountAllocationFailure>> execute({
    required String seedFingerprint,
    required int coinType,
    required int account,
  }) async {
    final result = await _repository.reserve(
      seedFingerprint: seedFingerprint,
      coinType: coinType,
      account: account,
    );
    return result.map((_) => account);
  }
}
