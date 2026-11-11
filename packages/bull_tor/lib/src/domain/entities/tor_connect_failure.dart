/// Why a connection through a Tor SOCKS proxy failed before any application byte was exchanged.
///
/// Derived from the SOCKS reply or the local socket error, so it survives libraries that turn every transport error into a string.
enum TorConnectFailure {
  /// Tor did not build the path within the session's connect budget.
  timeout,

  /// Tor could not build a circuit: directory, path or relay trouble.
  torNetworkUnreachable,

  /// The destination could not be reached; for an onion service, the descriptor fetch or the rendezvous failed.
  hostUnreachable,

  /// The destination closed or refused the stream.
  refused,

  /// The local SOCKS listener did not answer, so the session is gone.
  proxyUnreachable,

  /// Any other SOCKS or socket failure.
  other,
}
