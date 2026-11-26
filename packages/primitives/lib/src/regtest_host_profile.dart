import 'network.dart';

/// The build-selected regtest stack shared by regtest service profiles.
///
/// Every build carries the shared hosted stack, whose services each live on
/// their own origin; `BULL_REGTEST_HOST` selects a local stack instead,
/// reached through one host on the fixed ports of the local fixtures. The
/// selected stack is validated here as a whole, so the regtest runtime is
/// offered only when every service it needs is configured. Services still own their transport policy. This value never
/// enables a network capability or creates a profile for another environment.
sealed class RegtestHostProfile {
  const RegtestHostProfile._();

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
    RegtestHostedDefines hosted = const RegtestHostedDefines(),
  }) {
    if (environment != NetworkEnv.regtest) {
      return null;
    }
    if (host.isEmpty && hosted.isSelected) {
      return HostedRegtestStack(RegtestHostedEndpoints.parse(hosted));
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
    return LocalRegtestHost._(address.host);
  }
}

/// A local stack: one host serving every regtest service on fixed ports.
final class LocalRegtestHost extends RegtestHostProfile {
  final String host;

  const LocalRegtestHost._(this.host) : super._();
}

/// A hosted stack: every regtest service on its own explicit origin.
///
/// It offers no Payjoin: OHTTP relaying between its mailrooms is not
/// available, so the Payjoin runtime reports itself unavailable there.
final class HostedRegtestStack extends RegtestHostProfile {
  final RegtestHostedEndpoints endpoints;

  const HostedRegtestStack(this.endpoints) : super._();
}

/// The hosted-stack endpoints, defaulting to the shared hosted regtest stack
/// (mirrored in tools/regtest/hosted.json). A define overrides one endpoint;
/// an empty value removes it, which leaves the hosted stack incomplete.
final class RegtestHostedDefines {
  final String electrumBitcoin;
  final String electrumLiquid;
  final String esploraBitcoin;
  final String esploraLiquid;
  final String boltzApi;
  final String boltzWebSocket;
  final String recoverBull;

  const RegtestHostedDefines({
    this.electrumBitcoin = const String.fromEnvironment(
      'BULL_REGTEST_HOSTED_ELECTRUM_BITCOIN',
      defaultValue: 'ssl://scuttle-regtest.tailc408a.ts.net:443',
    ),
    this.electrumLiquid = const String.fromEnvironment(
      'BULL_REGTEST_HOSTED_ELECTRUM_LIQUID',
      defaultValue: 'ssl://scuttle-regtest.tailc408a.ts.net:8443',
    ),
    this.esploraBitcoin = const String.fromEnvironment(
      'BULL_REGTEST_HOSTED_ESPLORA_BITCOIN',
      defaultValue: 'https://scuttle-regtest-esplora.vibecode.casa',
    ),
    this.esploraLiquid = const String.fromEnvironment(
      'BULL_REGTEST_HOSTED_ESPLORA_LIQUID',
      defaultValue: 'https://scuttle-regtest-liquid.vibecode.casa',
    ),
    this.boltzApi = const String.fromEnvironment(
      'BULL_REGTEST_HOSTED_BOLTZ_API',
      defaultValue: 'https://scuttle-regtest-boltz.vibecode.casa/v2',
    ),
    this.boltzWebSocket = const String.fromEnvironment(
      'BULL_REGTEST_HOSTED_BOLTZ_WS',
      defaultValue: 'wss://scuttle-regtest-boltz.vibecode.casa/v2/ws',
    ),
    this.recoverBull = const String.fromEnvironment(
      'BULL_REGTEST_HOSTED_RECOVERBULL',
      defaultValue: 'http://jvoev3472o6kq5cja7h622jogk6duperesp35st66y5coirxjbs6pwid.onion',
    ),
  });

  List<String> get _values => [
    electrumBitcoin,
    electrumLiquid,
    esploraBitcoin,
    esploraLiquid,
    boltzApi,
    boltzWebSocket,
    recoverBull,
  ];

  /// Any endpoint selects the hosted stack, which then requires them all.
  bool get isSelected => _values.any((value) => value.isNotEmpty);
}

/// The validated origins of a hosted regtest stack.
final class RegtestHostedEndpoints {
  /// `ssl://host:port` Electrum endpoints.
  final Uri electrumBitcoin;
  final Uri electrumLiquid;

  /// HTTPS Esplora APIs, also the explorers of the swap backend.
  final Uri esploraBitcoin;
  final Uri esploraLiquid;

  /// HTTPS Boltz API (including its `/v2` path) and its WSS `/ws` stream.
  final Uri boltzApi;
  final Uri boltzWebSocket;

  /// RecoverBull key server: HTTPS, or plain HTTP to a Tor onion service.
  final Uri recoverBull;

  const RegtestHostedEndpoints._({
    required this.electrumBitcoin,
    required this.electrumLiquid,
    required this.esploraBitcoin,
    required this.esploraLiquid,
    required this.boltzApi,
    required this.boltzWebSocket,
    required this.recoverBull,
  });

  /// Throws [ArgumentError] unless every endpoint is present and valid.
  factory RegtestHostedEndpoints.parse(RegtestHostedDefines defines) {
    final recoverBull = _url(defines.recoverBull, 'recoverBull', const {
      'http',
      'https',
    });
    if (recoverBull.scheme == 'http' && !recoverBull.host.endsWith('.onion')) {
      throw ArgumentError.value(
        defines.recoverBull,
        'recoverBull',
        'Plain HTTP is only accepted for an onion service',
      );
    }
    return RegtestHostedEndpoints._(
      electrumBitcoin: _electrum(defines.electrumBitcoin, 'electrumBitcoin'),
      electrumLiquid: _electrum(defines.electrumLiquid, 'electrumLiquid'),
      esploraBitcoin: _url(defines.esploraBitcoin, 'esploraBitcoin', const {
        'https',
      }),
      esploraLiquid: _url(defines.esploraLiquid, 'esploraLiquid', const {
        'https',
      }),
      boltzApi: _url(defines.boltzApi, 'boltzApi', const {'https'}),
      boltzWebSocket: _boltzWebSocket(defines.boltzWebSocket),
      recoverBull: recoverBull,
    );
  }

  static Uri _url(String value, String name, Set<String> schemes) {
    final uri = Uri.tryParse(value);
    if (value.isEmpty ||
        RegExp(r'\s').hasMatch(value) ||
        uri == null ||
        !schemes.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(value, name, 'Expected ${schemes.join('|')}');
    }
    return uri;
  }

  static Uri _boltzWebSocket(String value) {
    final uri = _url(value, 'boltzWebSocket', const {'wss'});
    if (!uri.path.endsWith('/ws')) {
      throw ArgumentError.value(value, 'boltzWebSocket', 'Expected a /ws path');
    }
    return uri;
  }

  static Uri _electrum(String value, String name) {
    final uri = _url(value, name, const {'ssl'});
    if (!uri.hasPort || uri.path.isNotEmpty) {
      throw ArgumentError.value(value, name, 'Expected ssl://host:port');
    }
    return uri;
  }
}
