import 'package:bb_mobile/core/swaps/domain/entity/swap_server.dart';

/// The user's Boltz backend, one per network.
abstract interface class SwapServerSettingRepository {
  /// The stored server, or the network's default when none is stored or the
  /// store cannot be read.
  Future<SwapServer> fetch({required bool isTestnet});

  /// Throws [SwapServerSettingException] when the store cannot be written.
  Future<void> save(SwapServer server, {required bool isTestnet});
}

class SwapServerSettingException implements Exception {
  const SwapServerSettingException();

  @override
  String toString() => 'SwapServerSettingException: not persisted';
}
