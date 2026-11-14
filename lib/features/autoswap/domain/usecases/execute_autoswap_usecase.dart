import 'package:bb_mobile/features/autoswap/domain/repositories/auto_swap_settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_provider_port.dart';
import 'package:meta/meta.dart';

class ExecuteAutoswapUsecase {
  final GetAutoSwapSettingsUsecase _getSettings;
  final AutoswapProviderPort _provider;

  const ExecuteAutoswapUsecase(this._getSettings, this._provider);

  @useResult
  Future<Result<String, AutoswapFailure>> execute() async {
    final AutoSwap settings;
    try {
      settings = await _getSettings.execute();
    } on AutoswapNetworkUnavailableException {
      return const Err(AutoswapUnsupportedNetworkFailure());
    }
    if (!settings.enabled || settings.showWarning) {
      return const Err(AutoswapDisabledFailure());
    }
    if (settings.violation case final violation?) {
      return Err(AutoswapInvalidSettingsFailure(violation));
    }
    return _provider.execute(settings);
  }
}
