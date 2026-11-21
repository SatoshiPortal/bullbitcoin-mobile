import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:bb_mobile/features/swap/domain/regtest_boltz_profile.dart';
import 'package:preferences/preferences.dart';
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

  Future<({SwapServer server, NetworkEnv environment})> execute() async {
    final environment = (await _settingsRepository.fetch()).environment;
    final profile = RegtestBoltzProfile.forNetwork(environment.networkEnv);
    if (profile != null) {
      final server = SwapServer.parse(profile.api.toString(), isTestnet: true);
      if (server == null) throw StateError('Invalid regtest Boltz endpoint');
      return (server: server, environment: environment.networkEnv);
    }
    final isTestnet = environment.requireHistoricalTestnet();
    return (
      server: await _swapServerSettingRepository.fetch(isTestnet: isTestnet),
      environment: environment.networkEnv,
    );
  }
}
