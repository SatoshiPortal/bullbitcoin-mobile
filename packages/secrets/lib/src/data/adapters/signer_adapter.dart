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

        // Resolve each input's prev-out script (witness or non-witness) so the
        // validator can require every send input to be wallet-owned. Fail
        // CLOSED if any input script can't be resolved.
        final txInputs = tx.input();
        final psbtInputs = bdkPsbt.input();
        final inputScriptPubKeys = <String>[];
        for (var i = 0; i < psbtInputs.length; i++) {
          final inp = psbtInputs[i];
          bdk.Script? script = inp.witnessUtxo?.scriptPubkey;
          if (script == null &&
              inp.nonWitnessUtxo != null &&
              i < txInputs.length) {
            final vout = txInputs[i].previousOutput.vout;
            final prevOuts = inp.nonWitnessUtxo!.output();
            if (vout < prevOuts.length) {
              script = prevOuts[vout].scriptPubkey;
            }
          }
          if (script == null) continue; // unresolved → caught by the count check
          final spkHex = conv.hex.encode(script.toBytes());
          inputScriptPubKeys.add(spkHex);
          if (wallet.isMine(script: script)) owned.add(spkHex);
        }
        if (inputScriptPubKeys.length != txInputs.length) {
          return const Err(SigningFailure(
              'cannot resolve every input prev-out script — refusing to sign'));
        }

        // `fee()` lifts a u64; a value >= 2^63 wraps to a negative Dart int,
        // which would slip under any positive cap. Reject a non-positive /
        // absurd fee outright (BDK normally throws first, but guard anyway).
        final feeSat = bdkPsbt.fee();
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
          return Ok(SignedPsbt(signed));
        } finally {
          if (tmpDir.existsSync()) {
            tmpDir.deleteSync(recursive: true);
          }
        }
      }, onError: SigningFailure.new);
}
