import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_server.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_server_setting_repository.dart';
import 'package:bb_mobile/core/swaps/swap_engine_switcher.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:swaps/swaps.dart' show SwapStore, SwapsBusyFailure;
import 'package:meta/meta.dart';

/// Stores the Boltz backend typed by the user for the network the app is on
/// and moves the swap engine onto it. Empty input restores the default. A
/// plaintext (http://) server is refused outside testnet, and no change is
/// made while swaps on the current server are still open.
class SetSwapServerUsecase {
  final SwapServerSettingRepository _swapServerSettingRepository;
  final Preferences _settingsRepository;
  final SwapEngineSwitcher _swapEngineSwitcher;
  final SwapStore _swapStore;

  const SetSwapServerUsecase({
    required this._swapServerSettingRepository,
    required this._settingsRepository,
    required this._swapEngineSwitcher,
    required this._swapStore,
  });

  @useResult
  Future<Result<SwapServer, SwapFailure>> execute(String input) async {
    try {
      final environment = ((await _settingsRepository.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      )).environment.networkEnv;
      if (environment == NetworkEnv.regtest) {
        return const Err(SwapUnsupportedNetworkFailure());
      }
      final isTestnet = environment == NetworkEnv.testnet;
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
      final now = DateTime.now();
      switch (await _swapStore.ongoing()) {
        case Ok(value: final open)
            when open.any((swap) => swap.mayStillNeedProvider(now)):
          return const Err(SwapServerBusyFailure());
        case Err():
          return const Err(SwapStorageFailure());
        case Ok():
      }
      await _swapServerSettingRepository.save(server, isTestnet: isTestnet);
      return switch (await _swapEngineSwitcher.rebuild(
        environment: environment,
        waitForCompletion: true,
      )) {
        Ok() => Ok(server),
        Err(failure: SwapsBusyFailure()) => const Err(SwapServerBusyFailure()),
        Err() => const Err(SwapStorageFailure()),
      };
    } catch (e) {
      log.warning('Swap server not saved (${e.runtimeType})');
      return const Err(SwapStorageFailure());
    }
  }
}
