import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// Everything that moves money: revealing a receive address, simulating a
/// spend, and the irreversible finalize/sign/broadcast step.
abstract interface class SpPaymentsPort {
  /// Reveal a fresh taproot receive address to hand out. Each call derives the
  /// next never-before-issued address (advances + persists the receive tip); it
  /// must NEVER re-hand a previously revealed address. Call only on an explicit
  /// user "generate" action, not on every screen load.
  @useResult
  Future<Result<String, SpFailure>> generateTaprootAddress();

  @useResult
  Future<Result<SpTxDraft, SpFailure>> preparePsbt({
    required List<SpRecipient> recipients,
    required BigInt feerateSatVb,
  });

  /// finalize -> sign -> broadcast as one irreversible, simulation-pinned step.
  /// The [draft] round-trips its opaque FFI simulation UNCHANGED, so the tx is
  /// pinned to exactly what the confirm page showed. Returns the broadcast txid.
  @useResult
  Future<Result<String, SpFailure>> finalizeSignBroadcast({
    required SpTxDraft draft,
  });
}
