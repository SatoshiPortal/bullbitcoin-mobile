import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/swap_network_policy.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/restored_swap.dart';
import 'package:bull_logger/bull_logger.dart';

class RestoreSwapsUsecase {
  final BoltzSwapRepository _swapRepository;
  final SettingsRepository _settingsRepository;

  RestoreSwapsUsecase({
    required this._swapRepository,
    required this._settingsRepository,
  });

  Future<Result<List<RestorableSwap>, SwapFailure>> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      if (!swapEnvironmentAvailable(settings.environment.networkEnv)) {
        log.config(
          'Swap recovery unavailable network=${settings.environment.name}',
        );
        return const Err(SwapUnsupportedNetworkFailure());
      }
      final isTestnet = settings.environment.networkEnv == NetworkEnv.testnet;
      log.fine('Swap restore started network=${settings.environment.name}');

      final restored = await _swapRepository.restoreSwaps(isTestnet: isTestnet);

      final localIds = (await _swapRepository.getAllSwaps())
          .map((swap) => swap.id)
          .toSet();

      final result = [
        for (final swap in restored)
          RestorableSwap(swap: swap, existsLocally: localIds.contains(swap.id)),
      ];
      final missing = result.where((r) => !r.existsLocally).length;
      log.fine('Swap restore finished count=${result.length} missing=$missing');
      return Ok(result);
    } on String {
      // The legacy provider still throws strings; contain them without
      // logging their payload or swallowing programmer Errors.
      return const Err(SwapUnexpectedFailure());
    } on Exception {
      log.warning('Swap restore unavailable');
      return const Err(SwapUnexpectedFailure());
    }
  }
}
