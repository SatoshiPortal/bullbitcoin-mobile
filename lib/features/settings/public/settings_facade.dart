import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_payjoin_disclaimer_shown_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/mark_payjoin_disclaimer_shown_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_enabled_usecase.dart';

export '../domain/settings_failure.dart';
export '../ui/settings_router.dart' show SettingsRoute;
export 'payjoin_disclaimer_dialog.dart';

/// Public settings contract consumed by other features.
class SettingsFacade {
  final GetPayjoinDisclaimerShownUsecase _getPayjoinDisclaimerShownUsecase;
  final MarkPayjoinDisclaimerShownUsecase _markPayjoinDisclaimerShownUsecase;
  final SetPayjoinEnabledUsecase _setPayjoinEnabledUsecase;

  SettingsFacade({
    required this._getPayjoinDisclaimerShownUsecase,
    required this._markPayjoinDisclaimerShownUsecase,
    required this._setPayjoinEnabledUsecase,
  });

  Future<Result<bool, SettingsFailure>> getPayjoinDisclaimerShown() =>
      _getPayjoinDisclaimerShownUsecase.execute();

  Future<Result<void, SettingsFailure>> markPayjoinDisclaimerShown() =>
      _markPayjoinDisclaimerShownUsecase.execute();

  Future<void> setPayjoinEnabled(bool enabled) =>
      _setPayjoinEnabledUsecase.execute(enabled);
}
