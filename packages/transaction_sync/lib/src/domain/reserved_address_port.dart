import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'transaction_sync_failure.dart';
import 'wallet_key.dart';

abstract interface class ReservedAddressPort {
  /// [address] is the receive address, confidential for Liquid. Reservation
  /// follows the labels owner's system-label semantics, not any user label.
  @useResult
  Future<Result<bool, TransactionSyncFailure>> isReserved(
    WalletKey key,
    String address,
  );
}
