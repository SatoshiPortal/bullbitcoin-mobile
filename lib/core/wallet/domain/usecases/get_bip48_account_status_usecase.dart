import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bip48_account_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';

class GetBip48AccountStatusUsecase {
  final Bip48AccountRepository _repository;

  const GetBip48AccountStatusUsecase(this._repository);

  @useResult
  Future<
    Result<({int account, bool isReserved}), Bip48AccountAllocationFailure>
  >
  execute({
    required String seedFingerprint,
    required int coinType,
    int? account,
  }) async {
    if (account == null) {
      return (await _repository.nextAvailable(
        seedFingerprint: seedFingerprint,
        coinType: coinType,
      )).map((value) => (account: value, isReserved: false));
    }
    return (await _repository.isReserved(
      seedFingerprint: seedFingerprint,
      coinType: coinType,
      account: account,
    )).map((value) => (account: account, isReserved: value));
  }
}
