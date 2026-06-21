import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../secrets_failure.dart';
import '../value_objects/created_swap.dart';
import '../value_objects/signing_intent.dart';

/// Boltz swap CREATION (claim/refund stay in the `swaps` feature via the stored
/// per-swap KeyPair). The master seed is read internally and passed to the
/// Boltz SDK from inside the package — it never escapes. After the SDK builds
/// the swap, the implementation MUST assert the returned swap script commits to
/// OUR derived key and the intent's preimage hash
/// (`IntentValidator.validateSwapCommitment`) before returning — the
/// Boltz-supplied address is untrusted.
///
/// Boltz parameters are passed as primitives (urls/amounts/invoice/isTestnet)
/// so this contract carries no Boltz/native types across the package boundary.
abstract interface class SwapSignerPort {
  @useResult
  Future<Result<CreatedSwap, SecretsFailure>> createBtcReverse({
    required Fingerprint seed,
    required int index,
    required SwapIntent intent,
    required int outAmountSat,
    required String electrumUrl,
    required String boltzUrl,
    required bool isTestnet,
    String? outAddress,
  });

  @useResult
  Future<Result<CreatedSwap, SecretsFailure>> createBtcSubmarine({
    required Fingerprint seed,
    required int index,
    required SwapIntent intent,
    required String invoice,
    required String electrumUrl,
    required String boltzUrl,
    required bool isTestnet,
  });

  @useResult
  Future<Result<CreatedSwap, SecretsFailure>> createLbtcReverse({
    required Fingerprint seed,
    required int index,
    required SwapIntent intent,
    required int outAmountSat,
    required String electrumUrl,
    required String boltzUrl,
    required bool isTestnet,
    String? outAddress,
  });

  @useResult
  Future<Result<CreatedSwap, SecretsFailure>> createLbtcSubmarine({
    required Fingerprint seed,
    required int index,
    required SwapIntent intent,
    required String invoice,
    required String electrumUrl,
    required String boltzUrl,
    required bool isTestnet,
  });

  @useResult
  Future<Result<CreatedSwap, SecretsFailure>> createChainSwap({
    required Fingerprint seed,
    required int index,
    required SwapIntent intent,
    required int amountSat,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    required String boltzUrl,
    required bool isTestnet,
    required ChainDirection direction,
  });
}
