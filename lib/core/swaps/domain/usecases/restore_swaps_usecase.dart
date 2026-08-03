import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/restored_swap.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class RestoreSwapsUsecase {
  final BoltzSwapRepository _swapRepository;
  final SettingsRepository _settingsRepository;

  RestoreSwapsUsecase({
    required this._swapRepository,
    required this._settingsRepository,
  });

  Future<List<RestorableSwap>> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      log.fine('SWAP_RESTORE: starting (testnet=$isTestnet)');

      final restored = await _swapRepository.restoreSwaps(isTestnet: isTestnet);

      final localIds = (await _swapRepository.getAllSwaps())
          .map((swap) => swap.id)
          .toSet();

      final result = [
        for (final swap in restored)
          RestorableSwap(
            swap: swap,
            existsLocally: localIds.contains(swap.id),
          ),
      ];
      final missing = result.where((r) => !r.existsLocally).length;
      log.fine(
        'SWAP_RESTORE: ${result.length} restored, '
        '${result.length - missing} already local, $missing missing',
      );
      for (final r in result) {
        log.fine(
          'SWAP_RESTORE:   ${r.swap.id} ${r.swap.kind.name} '
          'local=${r.existsLocally}',
        );
      }
      return result;
    } catch (e) {
      log.warning('SWAP_RESTORE: failed: $e');
      throw RestoreSwapsException('$e');
    }
  }
}

class RestoreSwapsException extends BullException {
  RestoreSwapsException(super.message);
}
