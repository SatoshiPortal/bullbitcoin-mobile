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
