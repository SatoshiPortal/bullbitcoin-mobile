import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/repositories/payjoin_disclaimer_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';

class GetPayjoinDisclaimerShownUsecase {
  final PayjoinDisclaimerRepository _payjoinDisclaimerRepository;

  GetPayjoinDisclaimerShownUsecase({
    required this._payjoinDisclaimerRepository,
  });

  Future<Result<bool, SettingsFailure>> execute() =>
      _payjoinDisclaimerRepository.hasBeenShown();
}
