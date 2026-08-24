import 'package:meta/meta.dart';

import 'entities/tor_connection_state.dart';
import 'entities/tor_session.dart';
import 'entities/tor_transport.dart';

/// The embedded Arti client's lifecycle and current readiness.
///
/// Orbot is deliberately absent: it is not an alternative source this
/// repository can select. It carries Bitcoin Electrum `.onion` traffic, has no
/// lifecycle of ours to manage, and is checked on its own through
/// `VerifyExternalTorUsecase`.
abstract interface class TorRepository {
  /// Last published state, for a caller that cannot wait for [watch].
  TorConnectionState get current;

  TorTransportMode get mode;

  /// Emits the current state on listen, then every change.
  Stream<TorConnectionState> watch();

  /// Starts the client, or adopts one that is already serving traffic.
  /// Concurrent callers share a single start.
  @useResult
  Future<TorConnectionState> ensureReady();

  /// Replaces the running client, including one still bootstrapping — the
  /// only way out of a bootstrap that is stuck rather than slow.
  @useResult
  Future<TorConnectionState> retry();

  @useResult
  Future<TorConnectionState> setMode(TorTransportMode mode);

  Future<TorSession> openSession();

  Future<void> setDormant(bool dormant);

  Future<void> close();
}
