import 'dart:io';

import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:convert/convert.dart' as conv;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/intent_validation.dart';
import 'package:secrets/src/data/adapters/secret_guard.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
import 'package:secrets/src/domain/ports/signer_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/psbt.dart';
import 'package:secrets/src/domain/value_objects/signing_intent.dart';

/// Validates the intent against the decoded transaction, then signs with a
/// throwaway key. Reads the seed via [SecretGuard].
class SignerAdapter implements SignerPort {
  SignerAdapter(SecretStorePort store) : _guard = SecretGuard(store);
  final SecretGuard _guard;

  /// How many script-pubkeys to pre-index per keychain on the throwaway signing
  /// wallet, so `wallet.isMine(...)` can recognize owned inputs/change.
  ///
  /// This wallet is built fresh in-memory and is NEVER scanned or revealed, so
  /// `isMine` answers purely from the lookahead-derived SPK cache. With the old
  /// `lookahead: 0`, that cache was empty → `isMine` returned false for every
  /// owned script → `IntentValidator` rejected every real send ("spends a
  /// non-wallet input" / "output not owned"). The lookahead alone must therefore
  /// cover the highest derivation index the PSBT references.
  ///
  /// `DerivationPath` components are not exposed by the bdk_dart bindings, so we
  /// cannot reveal exactly to the PSBT's referenced indices; instead we pre-index
  /// a depth that comfortably exceeds any realistic wallet (gap limit is ~20).
  /// An owned script beyond this depth fails CLOSED (signing is refused, never
  /// mis-signed). Verified on-device (host `flutter test` can't load the bdk FFI).
  static const int _ownershipLookahead = 5000;

  /// `SignOptions` with `trustWitnessUtxo: false` — the opposite of the live
  /// path's `true`, closing the SegWit fee-inflation footgun.
  static bdk.SignOptions _safeSignOptions() => bdk.SignOptions(
        trustWitnessUtxo: false,
        assumeHeight: null,
        allowAllSighashes: false,
        tryFinalize: true,
        signWithTapInternalKey: false,
        allowGrinding: true,
      );

  @override
  Future<Result<SignedPsbt, SecretsFailure>> signBitcoinPsbt({
    required Fingerprint fingerprint,
    required Psbt psbt,
    required SigningIntent intent,
    required ScriptType scriptType,
    required bool isTestnet,
  }) =>
      _guard.read(fingerprint, (m) async {
        final network = isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;
        final networkKind = isTestnet ? bdk.NetworkKind.test : bdk.NetworkKind.main;
        final bdkMnemonic =
            bdk.Mnemonic.fromString(mnemonic: m.words.join(' '));
        final secretKey = bdk.DescriptorSecretKey(
          networkKind: networkKind,
          mnemonic: bdkMnemonic,
          password: m.passphrase,
        );
        final (external, internal) =
            _bitcoinDescriptors(secretKey, scriptType, networkKind);

        final wallet = bdk.Wallet(
          descriptor: external,
          changeDescriptor: internal,
          network: network,
          persister: bdk.Persister.newInMemory(),
          // NOT 0: this wallet is never scanned, so `isMine` relies entirely on
          // the lookahead-derived SPK cache to recognize owned inputs/change.
          lookahead: _ownershipLookahead,
        );

        final bdkPsbt = bdk.Psbt(psbtBase64: psbt.base64);

        // --- INTENT VALIDATION (before signing) ---
        final tx = bdkPsbt.extractTx();
        final owned = <String>{};
        final outputs = <Output>[];
        for (final out in tx.output()) {
          final spkHex = conv.hex.encode(out.scriptPubkey.toBytes());
          outputs.add(
              Output(scriptPubKey: spkHex, amountSat: out.value.toSat()));
          if (wallet.isMine(script: out.scriptPubkey)) owned.add(spkHex);
        }

        // Resolve each input's AUTHENTIC prev-out (script + amount). Both BDK's
        // `fee()` and `isMine` PREFER `witnessUtxo` over `nonWitnessUtxo`. For a
        // LEGACY (bip44) input the sighash does NOT commit to the input amount,
        // so a compromised PSBT layer (#1703 — the exact threat this gate exists
        // for) could attach the genuine `nonWitnessUtxo` PLUS a FABRICATED
        // low-value `witnessUtxo`: `fee()` would then under-report, slip under
        // `maxFeeSat`, and still sign a broadcastable tx that burns the
        // difference in fees. `trustWitnessUtxo: false` closes this for segwit
        // SIGNING but not for the fee/ownership FACT. So we do NOT trust
        // `witnessUtxo`: when a `nonWitnessUtxo` is present we verify it hashes
        // to the input's prev-out txid and read amount/script from that
        // txid-verified prev tx; a co-present `witnessUtxo` must match it
        // exactly. The fee is then computed HERE from verified amounts, never
        // from `bdkPsbt.fee()`. Fail CLOSED on any unresolved/inconsistent input.
        final txInputs = tx.input();
        final psbtInputs = bdkPsbt.input();
        final inputScriptPubKeys = <String>[];
        var totalInSat = 0;
        for (var i = 0; i < psbtInputs.length && i < txInputs.length; i++) {
          final inp = psbtInputs[i];
          final prevOut = txInputs[i].previousOutput;
          final w = inp.witnessUtxo;
          final nw = inp.nonWitnessUtxo;
          bdk.TxOut? authentic;
          if (nw != null) {
            // The non-witness UTXO is the FULL prev tx — require it to actually
            // be the tx this input spends, or its amount/script are attacker-set.
            if (!_txidMatches(nw.computeTxid(), prevOut.txid)) {
              return const Err(SigningFailure(
                  'input non-witness utxo does not match its prev-out txid'));
            }
            final prevOuts = nw.output();
            if (prevOut.vout >= prevOuts.length) {
              return const Err(SigningFailure(
                  'input prev-out vout out of range in non-witness utxo'));
            }
            authentic = prevOuts[prevOut.vout];
            // A witness UTXO alongside the verified prev-out must be IDENTICAL —
            // a divergent one is a fee/ownership spoof against fee()'s witness
            // preference. Refuse rather than pick one.
            if (w != null && !_sameTxOut(w, authentic)) {
              return const Err(SigningFailure(
                  'input witness/non-witness utxo mismatch — refusing to sign'));
            }
          } else if (w != null) {
            // SegWit-only input: no full prev tx supplied. The v0/v1 sighash
            // COMMITS to this amount, so a wrong value invalidates the signature
            // (won't broadcast) — safe to take the amount/script here.
            authentic = w;
          }
          if (authentic == null) continue; // unresolved → count check refuses
          final spkHex = conv.hex.encode(authentic.scriptPubkey.toBytes());
          inputScriptPubKeys.add(spkHex);
          totalInSat += authentic.value.toSat();
          if (wallet.isMine(script: authentic.scriptPubkey)) owned.add(spkHex);
        }
        if (inputScriptPubKeys.length != txInputs.length) {
          return const Err(SigningFailure(
              'cannot resolve every input prev-out — refusing to sign'));
        }

        // Compute the fee from the txid-VERIFIED input amounts minus the tx
        // outputs — NOT from `bdkPsbt.fee()`, which prefers the (spoofable)
        // witnessUtxo. Guard the range: a wrap or absurd value must never slip
        // under a positive cap.
        var totalOutSat = 0;
        for (final o in outputs) {
          totalOutSat += o.amountSat;
        }
        final feeSat = totalInSat - totalOutSat;
        if (feeSat < 0 || feeSat > 2100000000000000) {
          return const Err(SigningFailure('bitcoin fee out of range'));
        }
        final facts = TxFacts(
          outputs: outputs,
          feeSat: feeSat,
          version: tx.version(),
          lockTime: tx.lockTime(),
          inputScriptPubKeys: inputScriptPubKeys,
        );
        final verdict = IntentValidator.validate(
          intent,
          facts,
          ownsScript: owned.contains,
        );
        if (verdict is Err<void, SecretsFailure>) {
          return Err<SignedPsbt, SecretsFailure>(verdict.failure);
        }

        // --- SIGN ---
        // `sign` returns whether the PSBT is now FINALIZED. With
        // `tryFinalize: true` and BULL's single-sig sends (every input owned),
        // a real signature finalizes; `false` means no owned input signed (e.g.
        // wrong scriptType, or an owned index beyond the lookahead) — return a
        // failure instead of a serialized-but-unsigned PSBT mislabeled
        // `SignedPsbt`, which would silently fail at broadcast.
        final finalized =
            wallet.sign(psbt: bdkPsbt, signOptions: _safeSignOptions());
        if (!finalized) {
          return const Err(SigningFailure(
              'psbt not finalized after signing — no owned input signed'));
        }
        return Ok(SignedPsbt(bdkPsbt.serialize()));
      }, onError: SigningFailure.new);

  (bdk.Descriptor, bdk.Descriptor) _bitcoinDescriptors(
    bdk.DescriptorSecretKey secretKey,
    ScriptType scriptType,
    bdk.NetworkKind networkKind,
  ) {
    bdk.Descriptor d(bdk.KeychainKind k) => switch (scriptType) {
          ScriptType.bip84 => bdk.Descriptor.newBip84(
              secretKey: secretKey, keychainKind: k, networkKind: networkKind),
          ScriptType.bip49 => bdk.Descriptor.newBip49(
              secretKey: secretKey, keychainKind: k, networkKind: networkKind),
          ScriptType.bip44 => bdk.Descriptor.newBip44(
              secretKey: secretKey, keychainKind: k, networkKind: networkKind),
        };
    return (d(bdk.KeychainKind.external_), d(bdk.KeychainKind.internal));
  }

  @override
  Future<Result<SignedPsbt, SecretsFailure>> signLiquidPset({
    required Fingerprint fingerprint,
    required Psbt pset,
    required SigningIntent intent,
    required bool isTestnet,
  }) =>
      _guard.read(fingerprint, (m) async {
        // Liquid signing uses the BARE mnemonic (LWK's confidential descriptor
        // derives from words only — no passphrase). A `hasPassphrase` wallet
        // would sign/derive under the DIFFERENT bare-seed wallet, so refuse
        // rather than mis-derive (M2 — inherited lwk binding limitation).
        if (m.hasPassphrase) {
          return const Err(SigningFailure(
              'liquid signing is unsupported for passphrase wallets — lwk '
              'derives from the bare mnemonic and would use a different wallet'));
        }
        // LWK has no in-memory persistence (dep-audit §11): use an ephemeral
        // temp dir, deleted in `finally` (residual: a kill mid-sign leaks it).
        final network = isTestnet ? lwk.LiquidNetwork.testnet : lwk.LiquidNetwork.mainnet;
        final tmpDir = await Directory.systemTemp.createTemp('secrets_lwk_');
        try {
          final mnemonic = m.words.join(' ');
          final descriptor = await lwk.Descriptor.newConfidential(
            mnemonic: mnemonic,
            network: network,
          );

          // --- INTENT VALIDATION (before signing) ---
          // Liquid output amounts/assets are CONFIDENTIAL (blinded): per-output
          // VALUE and change-ownership checks aren't soundly possible (SPEC
          // §10). The network FEE and the output SCRIPTS are NOT blinded, so we
          // extract those and enforce the fee cap AND that every declared
          // recipient script is present (blocking address substitution). Fails
          // closed if outputs can't be extracted.
          final tx = lwk.LiquidTransaction.fromPset(psetString: pset.base64);
          final liquidFeeBig = tx.fee();
          // Guard the BigInt→int conversion: a crafted PSET reporting an absurd
          // fee could otherwise wrap to a small int and slip under the cap.
          if (liquidFeeBig.isNegative ||
              liquidFeeBig > BigInt.from(2100000000000000)) {
            return const Err(SigningFailure('liquid fee out of range'));
          }
          final facts = LiquidFacts(
            feeSat: liquidFeeBig.toInt(),
            outputScriptPubKeys:
                tx.getOutputs().map((o) => o.scriptPubkey).toList(),
            lockTime: tx.lockTime(),
          );
          final verdict = IntentValidator.validateLiquid(intent, facts);
          if (verdict is Err<void, SecretsFailure>) {
            return Err<SignedPsbt, SecretsFailure>(verdict.failure);
          }

          final wallet = await lwk.Wallet.init(
            network: network,
            dbpath: tmpDir.path,
            descriptor: descriptor,
          );
          final signed = await wallet.signTx(
            network: network,
            pset: pset.base64,
            mnemonic: mnemonic,
          );
          // LWK's signTx returns a PSET even when NO owned input signed (wrong
          // wallet / out-of-window) — there is no `finalized` bool as on the
          // Bitcoin path. A real single-sig signing finalizes each owned input
          // with a witness, so require the signed tx to carry at least one input
          // witness before returning it; otherwise a no-op "signed" PSET is
          // mislabeled SignedPsbt and only fails later at broadcast.
          if (!_liquidTxHasWitness(signed)) {
            return const Err(SigningFailure(
                'liquid pset produced no input witness — no owned input signed'));
          }
          return Ok(SignedPsbt(signed));
        } finally {
          if (tmpDir.existsSync()) {
            tmpDir.deleteSync(recursive: true);
          }
        }
      }, onError: SigningFailure.new);

  /// Byte-equal comparison of two txids (the u64-handle `==` would compare
  /// object identity, not the hash).
  static bool _txidMatches(bdk.Txid a, bdk.Txid b) =>
      _sameBytes(a.serialize(), b.serialize());

  /// Two prev-outs are the SAME output iff their amount AND scriptPubKey agree.
  static bool _sameTxOut(bdk.TxOut a, bdk.TxOut b) =>
      a.value.toSat() == b.value.toSat() &&
      _sameBytes(a.scriptPubkey.toBytes(), b.scriptPubkey.toBytes());

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// True iff the signed Liquid [pset] extracts to a tx with at least one input
  /// carrying a non-empty witness — the lwk analogue of BDK's `finalized` flag.
  /// Any extraction/parse failure counts as "not signed" (fail closed). Verified
  /// on-device (host `flutter test` can't load the lwk FFI).
  bool _liquidTxHasWitness(String pset) {
    try {
      final tx = lwk.LiquidTransaction.fromPset(psetString: pset);
      return tx.getInputs().any((i) => i.witness.isNotEmpty);
    } catch (_) {
      return false;
    }
  }
}
