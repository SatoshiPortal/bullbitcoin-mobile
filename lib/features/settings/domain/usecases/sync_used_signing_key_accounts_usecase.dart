import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/repositories/signing_key_account_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/used_signing_key_account.dart';
import 'package:meta/meta.dart';

class SyncUsedSigningKeyAccountsUsecase {
  final SigningKeyAccountRepository _repository;

  SyncUsedSigningKeyAccountsUsecase(this._repository);

  @useResult
  Future<Result<List<UsedSigningKeyAccount>, SettingsFailure>> execute({
    required String seedFingerprint,
    required int coinType,
  }) => _repository.sync(seedFingerprint: seedFingerprint, coinType: coinType);
}
