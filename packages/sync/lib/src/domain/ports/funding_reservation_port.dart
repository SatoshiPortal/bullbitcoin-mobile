import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../spend.dart';
import '../sync_failure.dart';
import '../wallet_key.dart';
import 'input_reservation_port.dart';

/// Durable funding obligations, owned by the host protocol.
///
/// Sync calls [reserve] under its Bitcoin spend admission and freeze guard,
/// after native persistence and revision completion, before returning a PSBT.
/// Implementations must atomically persist the operation, exact unfinalised
/// PSBT/txid/context and effective input ownership. An identical owner and
/// transaction is idempotent; changed context/transaction or conflicting inputs
/// are refused. Validate [key] against [spend.key] and retain its generation.
///
/// A failed or uncertain write grants nothing. Keep ambiguous obligations for
/// reconciliation; timeouts and process shutdown never release them. Reads
/// must include these obligations and fail closed when storage is uncertain.
/// [context] is bounded public recovery metadata, never key material.
///
/// Neither [reserve] nor [reservations] may call back into Sync, a wallet
/// facade or the freeze authority: the wallet lease and freeze queue are
/// already held. The host journals a funding request before invoking sync;
/// any refusal can follow an uncertain commit and requires reconciliation
/// before releasing a previously recorded obligation.
abstract interface class FundingReservationPort
    implements InputReservationPort {
  @useResult
  Future<Result<void, SyncFailure>> reserve({
    required WalletKey key,
    required UnsignedSpend spend,
    required String context,
  });
}
