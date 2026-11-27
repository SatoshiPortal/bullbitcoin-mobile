import 'dart:convert';

import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/swap_server.dart';
import '../domain/swap_server_setting_repository.dart';

class SwapServerSettingRepositoryImpl implements SwapServerSettingRepository {
  static const _mainnetKey = 'swaps.boltz.url';
  static const _testnetKey = 'swaps.boltz.url.testnet';
  static const _mainnetCredentialsKey = 'swap_server_credentials';
  static const _testnetCredentialsKey = 'swap_server_credentials_testnet';

  final SwapKeychain _secrets;

  const SwapServerSettingRepositoryImpl({required this._secrets});

  String _key({required bool isTestnet}) =>
      isTestnet ? _testnetKey : _mainnetKey;

  String _credentialsKey({required bool isTestnet}) =>
      isTestnet ? _testnetCredentialsKey : _mainnetCredentialsKey;

  @override
  Future<SwapServer> fetch({required bool isTestnet}) async {
    final fallback = SwapServer.defaultFor(isTestnet: isTestnet);
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key(isTestnet: isTestnet));
      final server = stored == null
          ? fallback
          : SwapServer.parse(stored, isTestnet: isTestnet) ?? fallback;
      return server.withCredentials(
        await _fetchCredentials(isTestnet: isTestnet),
      );
    } catch (e) {
      log.warning('Swap server setting unreadable (${e.runtimeType})');
      return fallback;
    }
  }

  Future<SwapServerCredentials?> _fetchCredentials({
    required bool isTestnet,
  }) async {
    switch (await _secrets.read(_credentialsKey(isTestnet: isTestnet))) {
      case Ok(value: final String stored):
        try {
          if (jsonDecode(stored) case {
            'username': final String username,
            'password': final String password,
          }) {
            return SwapServerCredentials.of(
              username: username,
              password: password,
            );
          }
        } on FormatException {
          log.warning('Swap server credentials unreadable (format)');
        }
        return null;
      case Ok():
        return null;
      case Err(:final failure):
        log.warning(
          'Swap server credentials unreadable (${failure.runtimeType})',
        );
        return null;
    }
  }

  @override
  Future<void> save(SwapServer server, {required bool isTestnet}) async {
    final credentialsKey = _credentialsKey(isTestnet: isTestnet);
    final credentials = server.credentials;
    final stored = credentials == null
        ? await _secrets.delete(credentialsKey)
        : await _secrets.write(
            credentialsKey,
            jsonEncode({
              'username': credentials.username,
              'password': credentials.password,
            }),
          );
    if (stored case Err()) throw const SwapServerSettingException();
    final prefs = await SharedPreferences.getInstance();
    final key = _key(isTestnet: isTestnet);
    final saved =
        server.host == SwapServer.defaultFor(isTestnet: isTestnet).host
        ? await prefs.remove(key)
        : await prefs.setString(key, server.host);
    if (!saved) throw const SwapServerSettingException();
  }
}
