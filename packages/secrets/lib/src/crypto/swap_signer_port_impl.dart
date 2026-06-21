import 'package:bull_sdk/boltz.dart' as boltz;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/intent_validation.dart';
import 'package:secrets/src/data/datasources/fss_secret_store.dart';
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/models/seed_secret.dart';
import 'package:secrets/src/domain/log_sanitizer.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/swap_signer_port.dart';
import 'package:secrets/src/domain/value_objects/created_swap.dart';
import 'package:secrets/src/domain/value_objects/signing_intent.dart';
import 'package:secrets/src/storage/secret_store.dart';

/// Creates Boltz swaps from the master seed (read internally; the mnemonic is
/// handed to the Boltz SDK from inside the package and never escapes). After
/// creation, the returned swap script is asserted to commit to OUR derived key
/// and the intent's preimage hash — the Boltz-supplied `scriptAddress` is
/// untrusted (`IntentValidator.validateSwapCommitment`).
///
/// Claim/refund of an existing swap stay in the `swaps` feature (stored
/// per-swap KeyPair). Native (Boltz/electrum) execution is integration-tier;
/// the security-critical commitment check is pure and unit-tested.
class SwapSignerPortImpl implements SwapSignerPort {
  SwapSignerPortImpl(this._store);
  final SecretStore _store;

  String _key(Fingerprint seed) => SecretStoreKeys.seedKey(seed.hex);

  static boltz.Chain _btcChain(bool t) =>
      t ? boltz.Chain.bitcoinTestnet : boltz.Chain.bitcoin;
  static boltz.Chain _lbtcChain(bool t) =>
      t ? boltz.Chain.liquidTestnet : boltz.Chain.liquid;

  @override
  Future<Result<CreatedSwap, SecretsFailure>> createBtcReverse({
    required Fingerprint seed,
    required int index,
    required SwapIntent intent,
    required int outAmountSat,
    required String electrumUrl,
    required String boltzUrl,
    required bool isTestnet,
    String? outAddress,
  }) =>
      _guard(seed, (m) async {
        final swap = await boltz.BtcLnSwap.newReverse(
          mnemonic: m,
          index: BigInt.from(index),
          outAmount: BigInt.from(outAmountSat),
          outAddress: outAddress,
          network: _btcChain(isTestnet),
          electrumUrl: electrumUrl,
          boltzUrl: boltzUrl,
        );
        return _assertBtc(intent, swap, ownClaim: swap.keys.publicKey);
      });

  @override
  Future<Result<CreatedSwap, SecretsFailure>> createBtcSubmarine({
    required Fingerprint seed,
    required int index,
    required SwapIntent intent,
    required String invoice,
    required String electrumUrl,
    required String boltzUrl,
    required bool isTestnet,
  }) =>
      _guard(seed, (m) async {
        final swap = await boltz.BtcLnSwap.newSubmarine(
          mnemonic: m,
          index: BigInt.from(index),
          invoice: invoice,
          network: _btcChain(isTestnet),
          electrumUrl: electrumUrl,
          boltzUrl: boltzUrl,
        );
        return _assertBtc(intent, swap, ownRefund: swap.keys.publicKey);
      });

  @override
  Future<Result<CreatedSwap, SecretsFailure>> createLbtcReverse({
    required Fingerprint seed,
    required int index,
    required SwapIntent intent,
    required int outAmountSat,
    required String electrumUrl,
    required String boltzUrl,
    required bool isTestnet,
    String? outAddress,
  }) =>
      _guard(seed, (m) async {
        final swap = await boltz.LbtcLnSwap.newReverse(
          mnemonic: m,
          index: BigInt.from(index),
          outAmount: BigInt.from(outAmountSat),
          outAddress: outAddress,
          network: _lbtcChain(isTestnet),
          electrumUrl: electrumUrl,
          boltzUrl: boltzUrl,
        );
        return _assertLbtc(intent, swap, ownClaim: swap.keys.publicKey);
      });

  @override
  Future<Result<CreatedSwap, SecretsFailure>> createLbtcSubmarine({
    required Fingerprint seed,
    required int index,
    required SwapIntent intent,
    required String invoice,
    required String electrumUrl,
    required String boltzUrl,
    required bool isTestnet,
  }) =>
      _guard(seed, (m) async {
        final swap = await boltz.LbtcLnSwap.newSubmarine(
          mnemonic: m,
          index: BigInt.from(index),
          invoice: invoice,
          network: _lbtcChain(isTestnet),
          electrumUrl: electrumUrl,
          boltzUrl: boltzUrl,
        );
        return _assertLbtc(intent, swap, ownRefund: swap.keys.publicKey);
      });

  @override
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
  }) =>
      _guard(seed, (m) async {
        final swap = await boltz.ChainSwap.newSwap(
          direction: direction == ChainDirection.btcToLbtc
              ? boltz.ChainSwapDirection.btcToLbtc
              : boltz.ChainSwapDirection.lbtcToBtc,
          mnemonic: m,
          index: BigInt.from(index),
          amount: BigInt.from(amountSat),
          isTestnet: isTestnet,
          btcElectrumUrl: btcElectrumUrl,
          lbtcElectrumUrl: lbtcElectrumUrl,
          boltzUrl: boltzUrl,
        );
        // A chain swap commits to BOTH our keys across TWO scripts (one per
        // chain); the pure validator routes lockup/claim legs by direction.
        final verdict = IntentValidator.validateChainSwapCommitment(
          intent,
          direction: direction,
          ownClaimPubkey: swap.claimKeys.publicKey,
          ownRefundPubkey: swap.refundKeys.publicKey,
          btcScript: SwapScriptLeg(
            receiverPubkey: swap.btcScriptStr.receiverPubkey,
            senderPubkey: swap.btcScriptStr.senderPubkey,
            hashlock: swap.btcScriptStr.hashlock,
          ),
          lbtcScript: SwapScriptLeg(
            receiverPubkey: swap.lbtcScriptStr.receiverPubkey,
            senderPubkey: swap.lbtcScriptStr.senderPubkey,
            hashlock: swap.lbtcScriptStr.hashlock,
          ),
        );
        return verdict.map(
          (_) => CreatedSwap(
            id: swap.id,
            scriptAddress: swap.scriptAddress,
            outAmountSat: swap.outAmount.toInt(),
          ),
        );
      });

  Result<CreatedSwap, SecretsFailure> _assertBtc(
    SwapIntent intent,
    boltz.BtcLnSwap swap, {
    String? ownClaim,
    String? ownRefund,
  }) =>
      IntentValidator.validateSwapCommitment(
        intent,
        ownClaimPubkey: ownClaim,
        ownRefundPubkey: ownRefund,
        scriptReceiverPubkey: swap.swapScript.receiverPubkey,
        scriptSenderPubkey: swap.swapScript.senderPubkey,
        scriptHashlock: swap.swapScript.hashlock,
      ).map((_) => CreatedSwap(
            id: swap.id,
            scriptAddress: swap.scriptAddress,
            outAmountSat: swap.outAmount.toInt(),
            invoice: swap.invoice,
          ));

  Result<CreatedSwap, SecretsFailure> _assertLbtc(
    SwapIntent intent,
    boltz.LbtcLnSwap swap, {
    String? ownClaim,
    String? ownRefund,
  }) =>
      IntentValidator.validateSwapCommitment(
        intent,
        ownClaimPubkey: ownClaim,
        ownRefundPubkey: ownRefund,
        scriptReceiverPubkey: swap.swapScript.receiverPubkey,
        scriptSenderPubkey: swap.swapScript.senderPubkey,
        scriptHashlock: swap.swapScript.hashlock,
      ).map((_) => CreatedSwap(
            id: swap.id,
            scriptAddress: swap.scriptAddress,
            outAmountSat: swap.outAmount.toInt(),
            invoice: swap.invoice,
          ));

  Future<Result<CreatedSwap, SecretsFailure>> _guard(
    Fingerprint seed,
    Future<Result<CreatedSwap, SecretsFailure>> Function(String mnemonic) body,
  ) async {
    try {
      return await _store.useAndForget(_key(seed), (bytes) async {
        final secret = SeedSecret.fromStorageBytes(bytes);
        if (secret is! MnemonicSeedSecret) {
          return const Err(
              NotAMnemonicSeedFailure('swap creation requires a mnemonic seed'));
        }
        return body(secret.words.join(' '));
      });
    } on KeychainLockedException catch (e) {
      return Err(KeychainLockedFailure(sanitizeLog(e.toString())));
    } on SecretNotFoundException {
      return Err(SeedNotFoundFailure(seed));
    } on Exception catch (e) {
      return Err(SigningFailure(sanitizeLog(e.toString())));
    }
  }
}
