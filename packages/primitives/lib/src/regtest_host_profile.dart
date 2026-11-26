import 'network.dart';

/// The build-selected host shared by regtest service profiles.
///
/// Each service owns its ports, paths and transport policy. This value never
/// enables a network capability or creates a profile for another environment.
final class RegtestHostProfile {
  final String host;

  const RegtestHostProfile._(this.host);

  /// Only a valid, explicitly configured build may offer the regtest runtime.
  static bool get isConfigured {
    try {
      return forNetwork(NetworkEnv.regtest) != null;
    } on ArgumentError {
      return false;
    }
  }

  static RegtestHostProfile? forNetwork(
    NetworkEnv environment, {
    String host = const String.fromEnvironment('BULL_REGTEST_HOST'),
  }) {
    if (environment != NetworkEnv.regtest) {
      return null;
    }

    final address = Uri.tryParse('http://$host');
    if (host.isEmpty ||
        RegExp(r'\s').hasMatch(host) ||
        address == null ||
        address.host.isEmpty ||
        address.userInfo.isNotEmpty ||
        address.hasPort ||
        address.path.isNotEmpty ||
        address.hasQuery ||
        address.hasFragment) {
      throw ArgumentError.value(host, 'host', 'Expected a host without a port');
    }
    return RegtestHostProfile._(address.host);
  }
}
