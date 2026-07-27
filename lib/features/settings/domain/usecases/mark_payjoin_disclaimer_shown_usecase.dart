import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/repositories/payjoin_disclaimer_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';

class MarkPayjoinDisclaimerShownUsecase {
  final PayjoinDisclaimerRepository _payjoinDisclaimerRepository;

  MarkPayjoinDisclaimerShownUsecase({
    required this._payjoinDisclaimerRepository,
  });

  Future<Result<void, SettingsFailure>> execute() =>
      _payjoinDisclaimerRepository.markShown();
}
