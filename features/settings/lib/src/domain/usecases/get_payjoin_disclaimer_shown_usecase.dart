import 'package:primitives/primitives.dart';
import 'package:settings/src/domain/repositories/payjoin_disclaimer_repository.dart';
import 'package:settings/src/domain/settings_failure.dart';

class GetPayjoinDisclaimerShownUsecase {
  final PayjoinDisclaimerRepository _payjoinDisclaimerRepository;

  GetPayjoinDisclaimerShownUsecase({
    required this._payjoinDisclaimerRepository,
  });

  Future<Result<bool, SettingsFailure>> execute() =>
      _payjoinDisclaimerRepository.hasBeenShown();
}
