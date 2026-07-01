part of 'secrets_api.dart';

/// A capability handle over a stored secret. Carries NON-secret metadata (from
/// the index) and the operations every secret-bearing kind supports. The object
/// holds NO words/bytes — each method does its own use-and-forget read
/// internally and discards the material.
///
/// Lives in the same library as [Secrets] (via `part`): the sealed hierarchy
/// must share a library with its subtypes, and the handle resolves the internal
/// wiring through [Secrets] (both are library-private-coupled).
sealed class Secret {
  const Secret(this._info);

  final SecretInfo _info;

  Fingerprint get fingerprint => _info.fingerprint;
  SecretKind get kind => _info.kind;
  bool get hasPassphrase => _info.hasPassphrase;
  DateTime? get createdAt => _info.createdAt;
  SecretInfo get info => _info;

  // ── derivation/signing/swaps map the chain-typed network → the internal
  //    ports' boolean seam via `isTestnet: !network.isMainnet`. NOTE: every
  //    non-mainnet env (Bitcoin signet/regtest, Liquid regtest) therefore
  //    collapses to `isTestnet: true`. Derivation is correct (they share the
  //    testnet coin type + version bytes); distinguishing them at the bdk/lwk
  //    signing layer is a documented later concern (the ports stay boolean). ──

  Future<Result<Xpub, SecretsFailure>> xpub({
    required ScriptType scriptType,
    required BitcoinNetwork network,
    required int account,
  }) =>
      Secrets._w.keyDerivation.accountXpub(
        fingerprint: fingerprint,
        scriptType: scriptType,
        isTestnet: !network.isMainnet,
        account: account,
      );

  Future<Result<BitcoinDescriptor, SecretsFailure>> bitcoinDescriptor({
    required ScriptType scriptType,
    required BitcoinNetwork network,
  }) =>
      Secrets._w.keyDerivation.bitcoinDescriptor(
        fingerprint: fingerprint,
        scriptType: scriptType,
        isTestnet: !network.isMainnet,
      );

  Future<Result<LiquidDescriptor, SecretsFailure>> liquidDescriptor({
    required LiquidNetwork network,
  }) =>
      Secrets._w.keyDerivation.liquidDescriptor(
        fingerprint: fingerprint,
        isTestnet: !network.isMainnet,
      );

  // ── signing ────────────────────────────────────────────────────────────────

  Future<Result<SignedPsbt, SecretsFailure>> signBitcoin({
    required Psbt psbt,
    required SigningIntent intent,
    required ScriptType scriptType,
    required BitcoinNetwork network,
  }) =>
      Secrets._w.signer.signBitcoinPsbt(
        fingerprint: fingerprint,
        psbt: psbt,
        intent: intent,
        scriptType: scriptType,
        isTestnet: !network.isMainnet,
      );

  Future<Result<SignedPsbt, SecretsFailure>> signLiquid({
    required Psbt pset,
    required SigningIntent intent,
    required LiquidNetwork network,
  }) =>
      Secrets._w.signer.signLiquidPset(
        fingerprint: fingerprint,
        pset: pset,
        intent: intent,
        isTestnet: !network.isMainnet,
      );

  // ── swaps (commitment-asserted) ────────────────────────────────────────────

  Future<Result<CreatedSwap, SecretsFailure>> createBtcReverse({
    required int index,
    required SwapIntent intent,
    required int outAmountSat,
    required String electrumUrl,
    required String boltzUrl,
    required BitcoinNetwork network,
    String? outAddress,
  }) =>
      Secrets._w.swap.createBtcReverse(
        fingerprint: fingerprint,
        index: index,
        intent: intent,
        outAmountSat: outAmountSat,
        electrumUrl: electrumUrl,
        boltzUrl: boltzUrl,
        isTestnet: !network.isMainnet,
        outAddress: outAddress,
      );

  Future<Result<CreatedSwap, SecretsFailure>> createBtcSubmarine({
    required int index,
    required SwapIntent intent,
    required String invoice,
    required String electrumUrl,
    required String boltzUrl,
    required BitcoinNetwork network,
  }) =>
      Secrets._w.swap.createBtcSubmarine(
        fingerprint: fingerprint,
        index: index,
        intent: intent,
        invoice: invoice,
        electrumUrl: electrumUrl,
        boltzUrl: boltzUrl,
        isTestnet: !network.isMainnet,
      );

  Future<Result<CreatedSwap, SecretsFailure>> createLbtcReverse({
    required int index,
    required SwapIntent intent,
    required int outAmountSat,
    required String electrumUrl,
    required String boltzUrl,
    required LiquidNetwork network,
    String? outAddress,
  }) =>
      Secrets._w.swap.createLbtcReverse(
        fingerprint: fingerprint,
        index: index,
        intent: intent,
        outAmountSat: outAmountSat,
        electrumUrl: electrumUrl,
        boltzUrl: boltzUrl,
        isTestnet: !network.isMainnet,
        outAddress: outAddress,
      );

  Future<Result<CreatedSwap, SecretsFailure>> createLbtcSubmarine({
    required int index,
    required SwapIntent intent,
    required String invoice,
    required String electrumUrl,
    required String boltzUrl,
    required LiquidNetwork network,
  }) =>
      Secrets._w.swap.createLbtcSubmarine(
        fingerprint: fingerprint,
        index: index,
        intent: intent,
        invoice: invoice,
        electrumUrl: electrumUrl,
        boltzUrl: boltzUrl,
        isTestnet: !network.isMainnet,
      );

  Future<Result<CreatedSwap, SecretsFailure>> createChainSwap({
    required int index,
    required SwapIntent intent,
    required int amountSat,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    required String boltzUrl,
    required NetworkEnv env,
    required ChainDirection direction,
  }) =>
      Secrets._w.swap.createChainSwap(
        fingerprint: fingerprint,
        index: index,
        intent: intent,
        amountSat: amountSat,
        btcElectrumUrl: btcElectrumUrl,
        lbtcElectrumUrl: lbtcElectrumUrl,
        boltzUrl: boltzUrl,
        isTestnet: env != NetworkEnv.mainnet,
        direction: direction,
      );

  // ── backup vault ─────────────────────────────────────────────────────────

  Future<Result<({EncryptedVault vault, VaultKey vaultKey}), SecretsFailure>>
      encryptVault() =>
          Secrets._w.backup.encryptVault(fingerprint: fingerprint);

  // ── BIP85 child derivation ─────────────────────────────────────────────────

  Future<Result<Bip85Derivation, SecretsFailure>> bip85ChildMnemonic({
    required MnemonicLength length,
    required int index,
  }) =>
      Secrets._w.bip85.deriveChildMnemonic(
        fingerprint: fingerprint,
        length: length,
        index: index,
      );

  Future<Result<Bip85Derivation, SecretsFailure>> bip85Bip39Child({
    required Bip85Application app,
    required int index,
    required MnemonicLength length,
  }) =>
      Secrets._w.bip85.deriveBip39Child(
        fingerprint: fingerprint,
        app: app,
        index: index,
        length: length,
      );

  Future<Result<Bip85HexResult, SecretsFailure>> bip85Hex({
    required int numBytes,
    required int index,
  }) =>
      Secrets._w.bip85.deriveHex(
        fingerprint: fingerprint,
        numBytes: numBytes,
        index: index,
      );

  Future<Result<VaultKey, SecretsFailure>> bip85RecoverbullKey({
    required Bip85Path path,
  }) =>
      Secrets._w.bip85.deriveRecoverbullKey(
        fingerprint: fingerprint,
        path: path,
      );

  Future<Result<ArkSecret, SecretsFailure>> bip85Ark() =>
      Secrets._w.bip85.deriveArkSecret(fingerprint: fingerprint);

  // ── lifecycle ──────────────────────────────────────────────────────────────

  Future<Result<void, SecretsFailure>> delete() =>
      Secrets._w.lifecycle.delete(fingerprint);
}

/// A stored mnemonic (words + optional passphrase + language).
final class MnemonicSecret extends Secret {
  const MnemonicSecret._(super.info);

  int get wordCount => _info.wordCount;
  String get language => _info.language;
}

/// A stored bytes/hex seed. DORMANT — no bytes-import path exists yet; reachable
/// only once the seed-import seam is built.
final class SeedSecret extends Secret {
  const SeedSecret._(super.info);

  // `byteLength` is dormant — no field on SecretInfo carries it yet. Add once
  // the seed-import path lands (it would extend SecretInfo).
}
