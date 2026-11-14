import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../sync_failure.dart';

/// Inputs an external protocol holds for one of its sessions. Their owner
/// keeps them and their transitions; sync only reads them to check the
/// inputs of a spend. Mandatory at foreground open: no provider is never an
/// empty set.
abstract interface class InputReservationPort {
  /// Every reservation currently held. A failed read is an [Err], never an
  /// empty list.
  @useResult
  Future<Result<List<InputReservation>, SyncFailure>> reservations();
}

/// One reserved input and the session that owns it. Only an operation of that
/// session, for that wallet and network, may spend it.
final class InputReservation {
  final Outpoint outpoint;

  /// The owning protocol, such as `payjoin`, and its session id.
  final String protocol;
  final String session;

  final String walletId;
  final BitcoinNetwork network;

  /// The owner's state when read, for diagnostics; any listed reservation holds.
  final String state;

  InputReservation({
    required this.outpoint,
    required this.protocol,
    required this.session,
    required this.walletId,
    required this.network,
    required this.state,
  }) {
    if (protocol.isEmpty || session.isEmpty || walletId.isEmpty) {
      throw ArgumentError('A reservation needs its owner and scope');
    }
  }
}
