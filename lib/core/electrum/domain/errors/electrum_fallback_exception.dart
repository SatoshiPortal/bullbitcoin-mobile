import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

/// A single server attempt recorded during a fallback run.
///
/// Carries enough context to explain *why* the whole run failed: which server
/// was tried, whether it was a custom (user-configured) or default server, and
/// the error it produced.
class ElectrumServerAttempt {
  final String url;
  final bool isCustom;
  final Object error;

  const ElectrumServerAttempt({
    required this.url,
    required this.isCustom,
    required this.error,
  });

  @override
  String toString() => '$url (${isCustom ? 'custom' : 'default'}): $error';
}

/// Errors raised by the Electrum fallback executor.
///
/// These are the *only* failure types a caller of `runWithFallback` sees — the
/// raw SDK / socket errors are captured inside [AllElectrumServersFailedException.attempts]
/// rather than leaking out untyped.
sealed class ElectrumFallbackException implements Exception {
  final String message;

  const ElectrumFallbackException(this.message);

  @override
  String toString() => message;
}

/// No servers are configured for the network — there is nothing to try.
///
/// Distinct from "all servers failed": this means resolution returned an empty
/// set (e.g. a network with no seeded defaults and no custom server), so no
/// connection was ever attempted.
class NoElectrumServersConfiguredException extends ElectrumFallbackException {
  final ElectrumServerNetwork network;

  NoElectrumServersConfiguredException(this.network)
    : super('No Electrum servers configured for $network.');
}

/// A `.onion` server was reached for without a Tor route to carry it.
///
/// Connecting anyway would hand the hidden-service address to the device's DNS
/// resolver — the exact disclosure the user chose an onion server to avoid —
/// and fail regardless, since no resolver can answer for `.onion`. The attempt
/// is therefore abandoned before a socket is opened.
///
/// Reachable today when a Liquid server is configured as an onion address: LWK
/// exposes no SOCKS parameter, so that route cannot be built at all.
class OnionServerWithoutTorException extends ElectrumFallbackException {
  final String url;

  OnionServerWithoutTorException(this.url)
    : super('No Tor route available for onion Electrum server $url.');
}

/// A clearnet server cannot be contacted because the configured external Tor
/// proxy is unavailable. It must not be reported as an onion routing failure.
class ClearnetServerWithoutConfiguredTorException
    extends ElectrumFallbackException {
  final String url;

  ClearnetServerWithoutConfiguredTorException(this.url)
    : super('Configured external Tor is unavailable for Electrum server $url.');
}

/// Every server in the active set failed with a transient error.
///
/// The active set is resolved once and is *either* all custom *or* all default
/// (never mixed), so [triedCustomServers] tells the caller which tier was
/// exhausted — important for surfacing the privacy-relevant case where a user's
/// only custom server is down and we deliberately did NOT fall back to defaults.
class AllElectrumServersFailedException extends ElectrumFallbackException {
  final List<ElectrumServerAttempt> attempts;

  AllElectrumServersFailedException(this.attempts) : super(_describe(attempts));

  /// True when the exhausted tier was the user's custom server(s). In this case
  /// defaults were intentionally not tried.
  bool get triedCustomServers => attempts.isNotEmpty && attempts.first.isCustom;

  static String _describe(List<ElectrumServerAttempt> attempts) {
    final tier = attempts.isNotEmpty && attempts.first.isCustom
        ? 'custom'
        : 'default';
    final buffer = StringBuffer(
      'All $tier Electrum servers failed (${attempts.length} tried):',
    );
    for (final attempt in attempts) {
      buffer.write('\n  - $attempt');
    }
    return buffer.toString();
  }
}
