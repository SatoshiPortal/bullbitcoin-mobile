import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/created_swap.dart';
import 'package:secrets/src/domain/value_objects/swap_request.dart';

/// Boltz swap CREATION (claim/refund stay app-side via the re-derived per-swap
/// KeyPair). The master seed is read internally and passed to the Boltz SDK from
/// inside the package — it never escapes. After the SDK builds the swap, the
/// implementation MUST assert the returned swap script commits to OUR derived
/// key(s) and OUR generated preimage
/// (`IntentValidator.validateSwapCommitment`) before returning — the
/// Boltz-supplied address is untrusted.
///
/// Requests are CALLER-KNOWABLE ([SwapRequest]): the per-swap keys, preimage and
/// Boltz-chosen locktime are generated during creation, so the caller supplies
/// none of them — only amounts/invoice/direction. Boltz parameters are passed as
/// primitives (urls/isTestnet) so this contract carries no Boltz/native types.
///
/// INVARIANT — [index] uniqueness (CALLER'S BURDEN): the per-swap keys AND the
/// preimage are derived deterministically from the master seed at [index]. The
/// caller MUST pass a fresh, monotonically-unique [index] for every swap it
/// creates. Reusing an [index] re-derives the SAME preimage/hashlock, which
/// (depending on Boltz preimage semantics) risks a race-claimable or
/// permanently-unclaimable swap. This package cannot enforce it — the swap
/// index counter lives app-side and `CreatedSwap` deliberately omits the
/// preimage — so the caller owns this invariant.
///
/// RESIDUAL — `scriptAddress` provenance: the implementation asserts the
/// returned swap SCRIPT commits to our key(s) + our preimage hashlock, but it
/// does NOT derive the lockup ADDRESS from that script (the SDK exposes no
/// script→address function, and re-implementing Boltz's HTLC address template
/// here would be error-prone). So `CreatedSwap.scriptAddress` is trusted from
/// the SDK; its binding to the validated script rests on the SDK's provenance.
/// Matters most for submarine/chain lockups (we PAY the address): a mismatched
/// address could strand our refund. See `SwapSignerAdapter` docs.
abstract interface class SwapSignerPort {
  @useResult
  Future<Result<CreatedSwap, SecretsFailure>> createBtcReverse({
    required Fingerprint fingerprint,
    required int index,
    required ReverseSwapRequest request,
    required String electrumUrl,
    required String boltzUrl,
    required bool isTestnet,
  });

  @useResult
  Future<Result<CreatedSwap, SecretsFailure>> createBtcSubmarine({
    required Fingerprint fingerprint,
    required int index,
    required SubmarineSwapRequest request,
    required String electrumUrl,
    required String boltzUrl,
    required bool isTestnet,
  });

  @useResult
  Future<Result<CreatedSwap, SecretsFailure>> createLbtcReverse({
    required Fingerprint fingerprint,
    required int index,
    required ReverseSwapRequest request,
    required String electrumUrl,
    required String boltzUrl,
    required bool isTestnet,
  });

  @useResult
  Future<Result<CreatedSwap, SecretsFailure>> createLbtcSubmarine({
    required Fingerprint fingerprint,
    required int index,
    required SubmarineSwapRequest request,
    required String electrumUrl,
    required String boltzUrl,
    required bool isTestnet,
  });

  @useResult
  Future<Result<CreatedSwap, SecretsFailure>> createChainSwap({
    required Fingerprint fingerprint,
    required int index,
    required ChainSwapRequest request,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    required String boltzUrl,
    required bool isTestnet,
  });
}
