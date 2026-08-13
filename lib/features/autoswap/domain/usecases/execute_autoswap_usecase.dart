import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_provider_port.dart';
import 'package:meta/meta.dart';

class ExecuteAutoswapUsecase {
  final GetAutoSwapSettingsUsecase _getSettings;
  final AutoswapProviderPort _provider;

  const ExecuteAutoswapUsecase(this._getSettings, this._provider);

  @useResult
  Future<Result<String, AutoswapFailure>> execute() async {
    final settings = await _getSettings.execute();
    if (!settings.enabled || settings.showWarning) {
      return const Err(AutoswapDisabledFailure());
    }
    if (settings.violation case final violation?) {
      return Err(AutoswapInvalidSettingsFailure(violation));
    }
    return _provider.execute(settings);
  }
}
