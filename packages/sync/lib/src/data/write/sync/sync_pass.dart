import 'dart:isolate';

import 'package:primitives/primitives.dart';

import '../../../domain/ports/wallet_connection_port.dart';
import '../../../domain/public_wallet_descriptor.dart';
import '../../../domain/sync_completion.dart';
import '../../../domain/sync_failure.dart';
import '../../../domain/sync_transaction_target.dart';
import '../../writer_diagnostics.dart';

/// What the foreground hands the compute worker for one pass.
final class SyncParams {
  final PublicWalletDescriptor descriptor;
  final String root;
  final WalletConnection connection;
  final bool discover;
  final int generation;
  final SendPort diagnostics;
  final bool headless;
  final bool allowInitialScan;
  final bool collectIncoming;
  final int runId;

  /// The transactions this pass must judge, empty for an ordinary pass. A
  /// targeted pass covers only the wallet indices these resolve to.
  final List<SyncTransactionTarget> targets;

  const SyncParams(
    this.descriptor,
    this.root,
    this.connection,
    this.discover,
    this.generation,
    this.diagnostics,
    this.headless,
    this.allowInitialScan,
    this.collectIncoming,
    this.runId, {
    this.targets = const <SyncTransactionTarget>[],
  });

  void observationWarning(String message) =>
      diagnostics.send((WriterLogLevel.warning, message));
}

/// What a pass returns to the worker, and the worker to the foreground.
final class SyncPassOutcome {
  final Result<SyncCompletion, SyncFailure> result;

  /// Only a failure before any native store was opened may try another server.
  final bool retryable;

  /// Cache counts for the sync log line; never part of the public completion.
  final String? cacheDiagnostics;

  const SyncPassOutcome(
    this.result, {
    required this.retryable,
    this.cacheDiagnostics,
  });

  SyncPassOutcome.failed(SyncFailure failure)
    : result = Err(failure),
      retryable = false,
      cacheDiagnostics = null;
}
