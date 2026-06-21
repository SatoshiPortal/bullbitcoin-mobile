import 'dart:io';

import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:convert/convert.dart' as conv;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/intent_validation.dart';
import 'package:secrets/src/data/datasources/fss_secret_store.dart';
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/models/seed_secret.dart';
import 'package:secrets/src/domain/log_sanitizer.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/signer_port.dart';
import 'package:secrets/src/domain/value_objects/psbt.dart';
import 'package:secrets/src/domain/value_objects/signing_intent.dart';
import 'package:secrets/src/storage/secret_store.dart';

/// Validates the intent against the decoded transaction, then signs with a
/// throwaway key. Lives in `src/crypto` (reads the seed via `useAndForget`).
class SignerPortImpl implements SignerPort {
  SignerPortImpl(this._store);
  final SecretStore _store;

  String _key(Fingerprint fp) => SecretStoreKeys.seedKey(fp.hex);

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
    required Fingerprint seed,
    required Psbt psbt,
    required SigningIntent intent,
    required ScriptType scriptType,
    required bool isTestnet,
  }) =>
      _guard(seed, (secret) async {
        if (secret is! MnemonicSeedSecret) {
          return const Err(NotAMnemonicSeedFailure(
              'Bitcoin signing requires a mnemonic seed'));
        }
        final network =
            isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;
        final bdkMnemonic =
            bdk.Mnemonic.fromString(mnemonic: secret.words.join(' '));
        final secretKey = bdk.DescriptorSecretKey(
          network: network,
          mnemonic: bdkMnemonic,
          password: secret.passphrase,
        );
        final (external, internal) =
            _bitcoinDescriptors(secretKey, scriptType, network);

        final wallet = bdk.Wallet(
          descriptor: external,
          changeDescriptor: internal,
          network: network,
          persister: bdk.Persister.newInMemory(),
          lookahead: 0,
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
          if (script == null && inp.nonWitnessUtxo != null && i < txInputs.length) {
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

        final facts = TxFacts(
          outputs: outputs,
          feeSat: bdkPsbt.fee(),
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
        wallet.sign(psbt: bdkPsbt, signOptions: _safeSignOptions());
        return Ok(SignedPsbt(bdkPsbt.serialize()));
      });

  (bdk.Descriptor, bdk.Descriptor) _bitcoinDescriptors(
    bdk.DescriptorSecretKey secretKey,
    ScriptType scriptType,
    bdk.Network network,
  ) {
    bdk.Descriptor d(bdk.KeychainKind k) => switch (scriptType) {
          ScriptType.bip84 => bdk.Descriptor.newBip84(
              secretKey: secretKey, keychainKind: k, network: network),
          ScriptType.bip49 => bdk.Descriptor.newBip49(
              secretKey: secretKey, keychainKind: k, network: network),
          ScriptType.bip44 => bdk.Descriptor.newBip44(
              secretKey: secretKey, keychainKind: k, network: network),
        };
    return (d(bdk.KeychainKind.external_), d(bdk.KeychainKind.internal));
  }

  @override
  Future<Result<SignedPsbt, SecretsFailure>> signLiquidPset({
    required Fingerprint seed,
    required Psbt pset,
    required SigningIntent intent,
    required bool isTestnet,
  }) =>
      _guard(seed, (secret) async {
        if (secret is! MnemonicSeedSecret) {
          return const Err(NotAMnemonicSeedFailure(
              'Liquid signing requires a mnemonic seed'));
        }
        // LWK has no in-memory persistence (dep-audit §11): use an ephemeral
        // temp dir, deleted in `finally` (residual: a kill mid-sign leaks it;
        // see SPEC §10).
        final network = isTestnet ? lwk.Network.testnet : lwk.Network.mainnet;
        final tmpDir =
            await Directory.systemTemp.createTemp('secrets_lwk_');
        try {
          final mnemonic = secret.words.join(' ');
          final descriptor = await lwk.Descriptor.newConfidential(
            mnemonic: mnemonic,
            network: network,
          );

          // --- INTENT VALIDATION (before signing) ---
          // Liquid outputs are CONFIDENTIAL: amounts are blinded and only our
          // own outputs are unblindable, so the per-output / change-ownership
          // checks BDK allows are NOT soundly possible here. What IS always
          // unblinded is the network FEE — so we enforce the fee cap (the
          // inflation footgun) and reject a SwapIntent on this generic path
          // (swaps go through SwapSignerPort). Full confidential output
          // validation is a documented residual (SPEC §10).
          final liquidFeeBig =
              lwk.LiquidTransaction.fromPset(psetString: pset.base64).fee();
          // Guard the BigInt→int conversion: a crafted PSET reporting an absurd
          // fee could otherwise wrap to a small int and slip under the cap.
          // (21M BTC in sats < 2^53; anything beyond is hostile.)
          if (liquidFeeBig.isNegative ||
              liquidFeeBig > BigInt.from(2100000000000000)) {
            return const Err(SigningFailure('liquid fee out of range'));
          }
          final liquidVerdict =
              _validateLiquidFee(intent, liquidFeeBig.toInt());
          if (liquidVerdict != null) {
            return Err<SignedPsbt, SecretsFailure>(liquidVerdict);
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
      });

  /// Pure, testable Liquid fee-cap check. Returns a failure to reject, or null
  /// to proceed. A `SwapIntent` is refused (swaps use SwapSignerPort).
  static SecretsFailure? _validateLiquidFee(SigningIntent intent, int feeSat) {
    return switch (intent) {
      SendIntent(:final maxFeeSat) => feeSat > maxFeeSat
          ? SigningFailure('liquid fee $feeSat exceeds cap $maxFeeSat')
          : null,
      PayjoinIntent(:final maxFeeContributionSat) =>
        feeSat > maxFeeContributionSat
            ? SigningFailure(
                'liquid fee $feeSat exceeds cap $maxFeeContributionSat')
            : null,
      SwapIntent() => const SigningFailure(
          'swap intents must use SwapSignerPort, not signLiquidPset'),
    };
  }

  /// Test seam for [_validateLiquidFee].
  @visibleForTesting
  static SecretsFailure? debugValidateLiquidFee(
          SigningIntent intent, int feeSat) =>
      _validateLiquidFee(intent, feeSat);

  Future<Result<SignedPsbt, SecretsFailure>> _guard(
    Fingerprint seed,
    Future<Result<SignedPsbt, SecretsFailure>> Function(SeedSecret) sign,
  ) async {
    try {
      return await _store.useAndForget(
        _key(seed),
        (bytes) => sign(SeedSecret.fromStorageBytes(bytes)),
      );
    } on KeychainLockedException catch (e) {
      return Err(KeychainLockedFailure(sanitizeLog(e.toString())));
    } on SecretNotFoundException {
      return Err(SeedNotFoundFailure(seed));
    } on Exception catch (e) {
      return Err(SigningFailure(sanitizeLog(e.toString())));
    }
  }
}
