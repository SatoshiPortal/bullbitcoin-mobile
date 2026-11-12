import 'package:bb_mobile/core/swaps/domain/entity/swap_server.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_server_setting_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SwapServerSettingRepositoryImpl implements SwapServerSettingRepository {
  static const _mainnetKey = 'swaps.boltz.url';
  static const _testnetKey = 'swaps.boltz.url.testnet';

  String _key({required bool isTestnet}) =>
      isTestnet ? _testnetKey : _mainnetKey;

  @override
  Future<SwapServer> fetch({required bool isTestnet}) async {
    final fallback = SwapServer.defaultFor(isTestnet: isTestnet);
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key(isTestnet: isTestnet));
      if (stored == null) return fallback;
      return SwapServer.parse(stored, isTestnet: isTestnet) ?? fallback;
    } catch (e) {
      log.warning('Swap server setting unreadable (${e.runtimeType})');
      return fallback;
    }
  }

  @override
  Future<void> save(SwapServer server, {required bool isTestnet}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(isTestnet: isTestnet);
    final saved = server == SwapServer.defaultFor(isTestnet: isTestnet)
        ? await prefs.remove(key)
        : await prefs.setString(key, server.host);
    if (!saved) throw const SwapServerSettingException();
  }
}
