import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_server.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_server_setting_repository.dart';

/// The Boltz backend for the network the app is on.
class GetSwapServerUsecase {
  final SwapServerSettingRepository _swapServerSettingRepository;
  final SettingsRepository _settingsRepository;

  const GetSwapServerUsecase({
    required this._swapServerSettingRepository,
    required this._settingsRepository,
  });

  Future<({SwapServer server, bool isTestnet})> execute() async {
    final isTestnet = (await _settingsRepository.fetch()).environment.isTestnet;
    return (
      server: await _swapServerSettingRepository.fetch(isTestnet: isTestnet),
      isTestnet: isTestnet,
    );
  }
}
