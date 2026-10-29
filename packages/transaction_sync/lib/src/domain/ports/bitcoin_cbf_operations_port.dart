import 'dart:typed_data';
import 'package:primitives/primitives.dart';
import '../wallet_source_registration.dart';
import '../wallet_transaction_sync_failure.dart';
import '../../wallet_source_session.dart';

abstract interface class BitcoinCbfOperationsPort {
  Future<Result<String, WalletTransactionSyncFailure>> broadcastCbf(
    WalletSourceRegistration registration,
    WalletSourceSession session,
    Uint8List bytes,
  );
  Future<void> disposeCbf();
}
