import 'package:primitives/primitives.dart';
import 'package:settings/src/domain/repositories/payjoin_disclaimer_repository.dart';
import 'package:settings/src/domain/settings_failure.dart';

class MarkPayjoinDisclaimerShownUsecase {
  final PayjoinDisclaimerRepository _payjoinDisclaimerRepository;

  MarkPayjoinDisclaimerShownUsecase({
    required this._payjoinDisclaimerRepository,
  });

  Future<Result<void, SettingsFailure>> execute() =>
      _payjoinDisclaimerRepository.markShown();
}
