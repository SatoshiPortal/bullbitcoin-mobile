import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/signing_key_account_session.dart';
import 'package:meta/meta.dart';

class ReleaseSigningKeyAccountUsecase {
  final SigningKeyAccountSession _session;

  const ReleaseSigningKeyAccountUsecase(this._session);

  @useResult
  Future<Result<void, SettingsFailure>> execute() async =>
      (await _session.release()).mapErr(
        (_) => const SettingsSigningKeyExportFailure(),
      );
}
