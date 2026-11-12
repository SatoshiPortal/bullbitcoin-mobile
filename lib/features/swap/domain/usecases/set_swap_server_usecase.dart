import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_server.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_server_setting_repository.dart';
import 'package:bb_mobile/core/swaps/swap_engine_switcher.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Stores the Boltz backend typed by the user for the network the app is on
/// and moves the swap engine onto it. Empty input restores the default. A
/// plaintext (http://) server is refused outside testnet.
class SetSwapServerUsecase {
  final SwapServerSettingRepository _swapServerSettingRepository;
  final SettingsRepository _settingsRepository;
  final SwapEngineSwitcher _swapEngineSwitcher;

  const SetSwapServerUsecase({
    required this._swapServerSettingRepository,
    required this._settingsRepository,
    required this._swapEngineSwitcher,
  });

  @useResult
  Future<Result<SwapServer, SwapFailure>> execute(String input) async {
    try {
      final isTestnet =
          (await _settingsRepository.fetch()).environment.isTestnet;
      final server = SwapServer.parse(input, isTestnet: isTestnet);
      if (server == null) {
        return const Err(
          SwapValidationFailure(field: 'server', logMessage: 'not an address'),
        );
      }
      if (server.isPlaintext && !isTestnet) {
        return const Err(
          SwapValidationFailure(
            field: 'server',
            logMessage: 'plaintext outside testnet',
          ),
        );
      }
      await _swapServerSettingRepository.save(server, isTestnet: isTestnet);
      await _swapEngineSwitcher.rebuild(isTestnet: isTestnet);
      return Ok(server);
    } catch (e) {
      log.warning('Swap server not saved (${e.runtimeType})');
      return const Err(SwapStorageFailure());
    }
  }
}
