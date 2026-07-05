import 'package:bull_sdk/boltz.dart' as boltz;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/intent_validation.dart';
import 'package:secrets/src/data/adapters/secret_guard.dart';
import 'package:secrets/src/data/models/mnemonic.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
import 'package:secrets/src/domain/ports/swap_signer_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/created_swap.dart';
import 'package:secrets/src/domain/value_objects/swap_request.dart';

/// Creates Boltz swaps from the master seed (read internally; the mnemonic is
/// handed to the Boltz SDK from inside the package and never escapes). After
/// creation, the returned swap script is asserted to commit to OUR derived
/// key(s) and OUR generated preimage (`IntentValidator.validateSwapCommitment`).
/// The caller supplies a [SwapRequest] (caller-knowable inputs only); the
/// commitment is built internally from the SDK-returned swap.
///
/// RESIDUAL (documented, not closed here): the commitment check proves the
/// SCRIPT commits to our key/hashlock, but `scriptAddress` — where funds are
/// locked — is NOT re-derived from that script and compared. The boltz binding
/// exposes no script→address function, and re-implementing Boltz's HTLC address
/// template in-package would be error-prone; so `scriptAddress` is trusted from
/// the SDK and its binding to the validated script rests on SDK provenance.
/// A mismatch matters most for submarine/chain lockups (we PAY the address),
/// where it could strand our refund. Close by adding an SDK script→address API
/// (then assert here) or by pinning the SDK to a provenance-verified commit.
///
/// Claim/refund of an existing swap stay app-side (the per-swap KeyPair is
/// re-derived at the same index). Native (Boltz/electrum) execution is
/// integration-tier; the security-critical commitment check is pure and
/// unit-tested.
class SwapSignerAdapter implements SwapSignerPort {
  SwapSignerAdapter(SecretStorePort store) : _guard = SecretGuard(store);
  final SecretGuard _guard;

  static boltz.Chain _btcChain(bool t) =>
      t ? boltz.Chain.bitcoinTestnet : boltz.Chain.bitcoin;
  static boltz.Chain _lbtcChain(bool t) =>
      t ? boltz.Chain.liquidTestnet : boltz.Chain.liquid;
  static Future<boltz.SwapMasterKey> _swapMasterKey(
    String walletMnemonic,
    bool isTestnet,
  ) =>
      boltz.SwapMasterKey.create(
        walletMnemonic: walletMnemonic,
        network: isTestnet ? boltz.Network.testnet : boltz.Network.mainnet,
      );

  @override
  Future<Result<CreatedSwap, SecretsFailure>> createBtcReverse({
    required Fingerprint fingerprint,
    required int index,
    required ReverseSwapRequest request,
    required String electrumUrl,
    required String boltzUrl,
    required bool isTestnet,
  }) =>
      _readMnemonic(fingerprint, (m) async {
        final swap = await boltz.BtcLnSwap.newReverse(
          swapMasterKey: await _swapMasterKey(m, isTestnet),
          index: BigInt.from(index),
          outAmount: BigInt.from(request.requestedReceiveSat),
          outAddress: request.outAddress,
          network: _btcChain(isTestnet),
          electrumUrl: electrumUrl,
          boltzUrl: boltzUrl,
          description: request.description,
          referralId: request.referralId,
        );
        return _assertReverse(
          ownPubkey: swap.keys.publicKey,
          preimageSha256: swap.preimage.sha256,
          script: _btcLeg(swap.swapScript),
          outAmountSat: swap.outAmount.toInt(),
          requestedReceiveSat: request.requestedReceiveSat,
          id: swap.id,
          scriptAddress: swap.scriptAddress,
          invoice: swap.invoice,
        );
      });

  @override
  Future<Result<CreatedSwap, SecretsFailure>> createBtcSubmarine({
    required Fingerprint fingerprint,
    required int index,
    required SubmarineSwapRequest request,
    required String electrumUrl,
    required String boltzUrl,
    required bool isTestnet,
  }) =>
      _readMnemonic(fingerprint, (m) async {
        final swap = await boltz.BtcLnSwap.newSubmarine(
          swapMasterKey: await _swapMasterKey(m, isTestnet),
          index: BigInt.from(index),
          invoice: request.invoice,
          network: _btcChain(isTestnet),
          electrumUrl: electrumUrl,
          boltzUrl: boltzUrl,
          referralId: request.referralId,
        );
        return _assertSubmarine(
          ownPubkey: swap.keys.publicKey,
          preimageSha256: swap.preimage.sha256,
          script: _btcLeg(swap.swapScript),
          outAmountSat: swap.outAmount.toInt(),
          request: request,
          id: swap.id,
          scriptAddress: swap.scriptAddress,
          invoice: swap.invoice,
        );
      });

  @override
  Future<Result<CreatedSwap, SecretsFailure>> createLbtcReverse({
    required Fingerprint fingerprint,
    required int index,
    required ReverseSwapRequest request,
    required String electrumUrl,
    required String boltzUrl,
    required bool isTestnet,
  }) =>
      _readMnemonic(fingerprint, (m) async {
        final swap = await boltz.LbtcLnSwap.newReverse(
          swapMasterKey: await _swapMasterKey(m, isTestnet),
          index: BigInt.from(index),
          outAmount: BigInt.from(request.requestedReceiveSat),
          outAddress: request.outAddress,
          network: _lbtcChain(isTestnet),
          electrumUrl: electrumUrl,
          boltzUrl: boltzUrl,
          description: request.description,
          referralId: request.referralId,
        );
        return _assertReverse(
          ownPubkey: swap.keys.publicKey,
          preimageSha256: swap.preimage.sha256,
          script: _lbtcLeg(swap.swapScript),
          outAmountSat: swap.outAmount.toInt(),
          requestedReceiveSat: request.requestedReceiveSat,
          id: swap.id,
          scriptAddress: swap.scriptAddress,
          invoice: swap.invoice,
        );
      });

  @override
  Future<Result<CreatedSwap, SecretsFailure>> createLbtcSubmarine({
    required Fingerprint fingerprint,
    required int index,
    required SubmarineSwapRequest request,
    required String electrumUrl,
    required String boltzUrl,
    required bool isTestnet,
  }) =>
      _readMnemonic(fingerprint, (m) async {
        final swap = await boltz.LbtcLnSwap.newSubmarine(
          swapMasterKey: await _swapMasterKey(m, isTestnet),
          index: BigInt.from(index),
          invoice: request.invoice,
          network: _lbtcChain(isTestnet),
          electrumUrl: electrumUrl,
          boltzUrl: boltzUrl,
          referralId: request.referralId,
        );
        return _assertSubmarine(
          ownPubkey: swap.keys.publicKey,
          preimageSha256: swap.preimage.sha256,
          script: _lbtcLeg(swap.swapScript),
          outAmountSat: swap.outAmount.toInt(),
          request: request,
          id: swap.id,
          scriptAddress: swap.scriptAddress,
          invoice: swap.invoice,
        );
      });

  @override
  Future<Result<CreatedSwap, SecretsFailure>> createChainSwap({
    required Fingerprint fingerprint,
    required int index,
    required ChainSwapRequest request,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    required String boltzUrl,
    required bool isTestnet,
  }) =>
      _readMnemonic(fingerprint, (m) async {
        final swap = await boltz.ChainSwap.newSwap(
          direction: request.direction == ChainDirection.btcToLbtc
              ? boltz.ChainSwapDirection.btcToLbtc
              : boltz.ChainSwapDirection.lbtcToBtc,
          swapMasterKey: await _swapMasterKey(m, isTestnet),
          index: BigInt.from(index),
          amount: BigInt.from(request.sendAmountSat),
          isTestnet: isTestnet,
          btcElectrumUrl: btcElectrumUrl,
          lbtcElectrumUrl: lbtcElectrumUrl,
          boltzUrl: boltzUrl,
        );
        // A chain swap commits to BOTH our keys across TWO scripts (one per
        // chain), both hashlocking OUR preimage; the pure validator routes
        // lockup/claim legs by direction.
        final btcLeg = _btcLeg(swap.btcScriptStr);
        final lbtcLeg = _lbtcLeg(swap.lbtcScriptStr);
        final verdict = IntentValidator.validateChainSwapCommitment(
          direction: request.direction,
          ownClaimPubkey: swap.claimKeys.publicKey,
          ownRefundPubkey: swap.refundKeys.publicKey,
          preimageSha256: swap.preimage.sha256,
          btcScript: btcLeg,
          lbtcScript: lbtcLeg,
          outAmountSat: swap.outAmount.toInt(),
          sendAmountSat: request.sendAmountSat,
        );
        // The lockup (refund) leg is on the source chain.
        final lockupLeg =
            request.direction == ChainDirection.btcToLbtc ? btcLeg : lbtcLeg;
        return verdict.map(
          (_) => CreatedSwap(
            id: swap.id,
            scriptAddress: swap.scriptAddress,
            outAmountSat: swap.outAmount.toInt(),
            preimageSha256: swap.preimage.sha256,
            ownClaimPubkey: swap.claimKeys.publicKey,
            ownRefundPubkey: swap.refundKeys.publicKey,
            lockupLocktime: lockupLeg.locktime,
          ),
        );
      });

  // Map the two distinct FRB-generated `*SwapScriptStr` types onto the pure
  // `SwapScriptLeg` (they share no supertype).
  static SwapScriptLeg _btcLeg(boltz.BtcSwapScriptStr s) => SwapScriptLeg(
        receiverPubkey: s.receiverPubkey,
        senderPubkey: s.senderPubkey,
        hashlock: s.hashlock,
        locktime: s.locktime,
      );

  static SwapScriptLeg _lbtcLeg(boltz.LBtcSwapScriptStr s) => SwapScriptLeg(
        receiverPubkey: s.receiverPubkey,
        senderPubkey: s.senderPubkey,
        hashlock: s.hashlock,
        locktime: s.locktime,
      );

  /// Reverse (Lightning → on-chain): WE claim, so our key is the RECEIVER and
  /// the amount must equal the requested receive exactly.
  Result<CreatedSwap, SecretsFailure> _assertReverse({
    required String ownPubkey,
    required String preimageSha256,
    required SwapScriptLeg script,
    required int outAmountSat,
    required int requestedReceiveSat,
    required String id,
    required String scriptAddress,
    String? invoice,
  }) =>
      IntentValidator.validateSwapCommitment(
        weAreReceiver: true,
        ownPubkey: ownPubkey,
        preimageSha256: preimageSha256,
        scriptReceiverPubkey: script.receiverPubkey,
        scriptSenderPubkey: script.senderPubkey,
        scriptHashlock: script.hashlock,
        outAmountSat: outAmountSat,
        exactSat: requestedReceiveSat,
      ).map((_) => CreatedSwap(
            id: id,
            scriptAddress: scriptAddress,
            outAmountSat: outAmountSat,
            preimageSha256: preimageSha256,
            ownClaimPubkey: ownPubkey,
            lockupLocktime: script.locktime,
            invoice: invoice,
          ));

  /// Submarine (on-chain → Lightning): WE refund, so our key is the SENDER and
  /// the lockup amount is bounded by `[invoiceAmount, maxLockup]` (invoice +
  /// Boltz fee is unknown pre-call).
  Result<CreatedSwap, SecretsFailure> _assertSubmarine({
    required String ownPubkey,
    required String preimageSha256,
    required SwapScriptLeg script,
    required int outAmountSat,
    required SubmarineSwapRequest request,
    required String id,
    required String scriptAddress,
    String? invoice,
  }) =>
      IntentValidator.validateSwapCommitment(
        weAreReceiver: false,
        ownPubkey: ownPubkey,
        preimageSha256: preimageSha256,
        scriptReceiverPubkey: script.receiverPubkey,
        scriptSenderPubkey: script.senderPubkey,
        scriptHashlock: script.hashlock,
        outAmountSat: outAmountSat,
        minSat: request.invoiceAmountSat,
        maxSat: request.maxLockupSat,
      ).map((_) => CreatedSwap(
            id: id,
            scriptAddress: scriptAddress,
            outAmountSat: outAmountSat,
            preimageSha256: preimageSha256,
            ownRefundPubkey: ownPubkey,
            lockupLocktime: script.locktime,
            invoice: invoice,
          ));

  /// Reads the mnemonic and hands the SDK its sentence form (stays in-package).
  ///
  /// A passphrase wallet is REJECTED: Boltz `SwapMasterKey` derives from the
  /// bare mnemonic (the passphrase is dropped), so a swap for a `hasPassphrase`
  /// seed would commit to keys of a DIFFERENT (bare-seed) wallet — refund keys
  /// the user can never reach. Fail closed rather than silently mis-derive
  /// (M2 — inherited boltz binding limitation, surfaced not swallowed).
  Future<Result<CreatedSwap, SecretsFailure>> _readMnemonic(
    Fingerprint fingerprint,
    Future<Result<CreatedSwap, SecretsFailure>> Function(String mnemonic) body,
  ) =>
      _guard.read<CreatedSwap>(
        fingerprint,
        (Mnemonic m) async {
          if (m.hasPassphrase) {
            return const Err(SigningFailure(
                'swaps are unsupported for passphrase wallets — the boltz '
                'SwapMasterKey drops the passphrase and would derive keys of '
                'the bare-seed wallet'));
          }
          return body(m.words.join(' '));
        },
        onError: SigningFailure.new,
      );
}
