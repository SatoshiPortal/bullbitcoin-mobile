import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../transaction_sync_failure.dart';
import '../wallet_key.dart';
import '../wallet_revision.dart';

/// The lifecycle operations the app performs on native wallet stores. Each
/// one names the generation it expects and fails typed when it changed.
/// Sync, spend admission and native handles are outside this contract.
abstract interface class WalletWriterRepository {
  /// Reserves the next generation of a deleted wallet before re-import.
  @useResult
  Future<Result<WriterOutcome, TransactionSyncFailure>> prepareReimport(
    WalletKey key, {
    required int expectedGeneration,
  });

  /// Creates the store, or adopts an existing one with [existingOnly].
  @useResult
  Future<Result<WriterOutcome, TransactionSyncFailure>> create(
    WalletKey key, {
    required int expectedGeneration,
    bool existingOnly = false,
  });

  /// Issues a receive address that is neither reserved nor used.
  @useResult
  Future<Result<ReceiveAddressIssued, TransactionSyncFailure>> receive(
    WalletKey key, {
    required int expectedGeneration,
    bool advance = false,
  });

  @useResult
  Future<Result<WriterOutcome, TransactionSyncFailure>> delete(
    WalletKey key, {
    required int expectedGeneration,
  });

  /// Rebuilds a Liquid store after the precise LWK status conflict.
  @useResult
  Future<Result<WriterOutcome, TransactionSyncFailure>> repair(
    WalletKey key, {
    required int expectedGeneration,
  });
}
