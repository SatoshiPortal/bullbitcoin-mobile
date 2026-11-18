import 'package:bb_mobile/features/swap/domain/regtest_boltz_profile.dart';
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
    final environment = (await _settingsRepository.fetch()).environment;
    final profile = RegtestBoltzProfile.forNetwork(environment.networkEnv);
    if (profile != null) {
      final server = SwapServer.parse(profile.api.toString(), isTestnet: true);
      if (server == null) throw StateError('Invalid regtest Boltz endpoint');
      return (server: server, isTestnet: false);
    }
    final isTestnet = !environment.isMainnet;
    return (
      server: await _swapServerSettingRepository.fetch(isTestnet: isTestnet),
      isTestnet: isTestnet,
    );
  }
}
