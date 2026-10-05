import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/used_signing_key_account.dart';
import 'package:meta/meta.dart';

abstract interface class SigningKeyAccountRepository {
  @useResult
  Future<Result<List<UsedSigningKeyAccount>, SettingsFailure>> sync({
    required String seedFingerprint,
    required int coinType,
  });
}
