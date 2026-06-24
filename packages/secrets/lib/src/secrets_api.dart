import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'package:secrets/src/data/adapters/backup_vault_adapter.dart';
import 'package:secrets/src/data/adapters/bip85_adapter.dart';
import 'package:secrets/src/data/adapters/flutter_secure_storage_adapter.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/key_derivation_adapter.dart';
import 'package:secrets/src/data/adapters/secret_lifecycle_adapter.dart';
import 'package:secrets/src/data/adapters/signer_adapter.dart';
import 'package:secrets/src/data/adapters/swap_signer_adapter.dart';
import 'package:secrets/src/domain/ports/backup_vault_port.dart';
import 'package:secrets/src/domain/ports/bip85_port.dart';
import 'package:secrets/src/domain/ports/key_derivation_port.dart';
import 'package:secrets/src/domain/ports/secret_index_port.dart';
import 'package:secrets/src/domain/ports/secret_lifecycle_port.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
import 'package:secrets/src/domain/ports/signer_port.dart';
import 'package:secrets/src/domain/ports/swap_signer_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/ark_secret.dart';
import 'package:secrets/src/domain/value_objects/backup.dart';
import 'package:secrets/src/domain/value_objects/bip85_types.dart';
import 'package:secrets/src/domain/value_objects/created_swap.dart';
import 'package:secrets/src/domain/value_objects/descriptors.dart';
import 'package:secrets/src/domain/value_objects/mnemonic_language.dart';
import 'package:secrets/src/domain/value_objects/mnemonic_length.dart';
import 'package:secrets/src/domain/value_objects/psbt.dart';
import 'package:secrets/src/domain/value_objects/secret_info.dart';
import 'package:secrets/src/domain/value_objects/signing_intent.dart';
import 'package:secrets/src/ui/mnemonic_reader.dart';

/// The internal object graph built once by [Secrets.init]. Holds the injected
/// [SecretIndexPort] plus the six adapters, all wired against a single
/// [SecretStorePort]. Process-global; resolved lazily per call so static-field
/// initializers never touch it before [Secrets.init].
class _Wiring {
  _Wiring._({
    required this.index,
    required this.lifecycle,
    required this.keyDerivation,
    required this.signer,
    required this.swap,
    required this.bip85,
    required this.mnemonicReader,
    required this.backup,
  });

  factory _Wiring({
    required SecretStorePort store,
    required SecretIndexPort index,
  }) {
    // One lifecycle adapter, shared with the backup adapter (which re-imports
    // restored secrets through it). They are stateless, but build it once.
    final lifecycle = SecretLifecycleAdapter(store: store, index: index);
    return _Wiring._(
      index: index,
      lifecycle: lifecycle,
      keyDerivation: KeyDerivationAdapter(store),
      signer: SignerAdapter(store),
      swap: SwapSignerAdapter(store),
      bip85: Bip85Adapter(store),
      mnemonicReader: MnemonicReader(store),
      backup: BackupVaultAdapter(store: store, repository: lifecycle),
    );
  }

  final SecretIndexPort index;
  final SecretLifecyclePort lifecycle;
  final KeyDerivationPort keyDerivation;
  final SignerPort signer;
  final SwapSignerPort swap;
  final Bip85Port bip85;
  final BackupVaultPort backup;

  /// In-package seam letting the sealed display widgets read a stored mnemonic
  /// for rendering — never exported.
  final MnemonicReader mnemonicReader;
}

/// The static entry point to the `secrets` package — wiring, creation, and the
/// cross-kind registry. Operations on an existing secret live on the [Secret]
/// handle returned by [fetch]/[importMnemonic]/[generateMnemonic].
///
/// Call [init] exactly once (at app start) with the app's [SecretIndexPort];
/// any use before [init] throws a [StateError].
abstract final class Secrets {
  static _Wiring? _instance;

  static _Wiring get _w =>
      _instance ??
      (throw StateError('Secrets.init() must be called before use.'));

  /// Builds the internal graph once. [index] is the app's (Drift-backed)
  /// non-secret index; [store] defaults to the OS keychain-backed
  /// [FssSecretStoreAdapter] and is the test/hardware-backend seam.
  static void init({required SecretIndexPort index, SecretStorePort? store}) {
    _instance = _Wiring(
      store:
          store ?? FssSecretStoreAdapter(FlutterSecureStorageAdapter.standard()),
      index: index,
    );
  }

  /// Drops the wired graph — test isolation only.
  @visibleForTesting
  static void reset() => _instance = null;

  /// In-package seam for the sealed display widgets ([SecretRevealer],
  /// [VerifyBackupView]) to read a stored mnemonic for rendering. NOT exported.
  @internal
  static MnemonicReader get mnemonicReader => _w.mnemonicReader;

  // ── create → a TYPED handle (operate immediately, no second fetch) ────────

  /// Imports an existing mnemonic, stores it, and returns its handle.
  static Future<Result<MnemonicSecret, SecretsFailure>> importMnemonic(
    List<String> words, {
    String? passphrase,
    MnemonicLanguage language = MnemonicLanguage.english,
  }) async {
    final r = await _w.lifecycle.importMnemonic(
      words: words,
      passphrase: passphrase,
      language: language,
    );
    return _hydrateMnemonic(r);
  }

  /// Generates a fresh mnemonic, stores it, and returns its handle.
  static Future<Result<MnemonicSecret, SecretsFailure>> generateMnemonic({
    MnemonicLength length = MnemonicLength.words12,
  }) async {
    final r = await _w.lifecycle.generateMnemonic(length: length);
    return _hydrateMnemonic(r);
  }

  /// Derives a mnemonic's fingerprint WITHOUT storing (duplicate pre-check).
  static Future<Result<Fingerprint, SecretsFailure>> fingerprintOfMnemonic(
    List<String> words, {
    String? passphrase,
    MnemonicLanguage language = MnemonicLanguage.english,
  }) =>
      _w.lifecycle.fingerprintOf(
        words: words,
        passphrase: passphrase,
        language: language,
      );

  // ── operate on an existing secret → resolves kind from the index ──────────

  /// Reads the index and returns the typed handle, or
  /// [SecretNotFoundFailure] if absent. Never touches the secret store.
  static Future<Result<Secret, SecretsFailure>> fetch(Fingerprint fp) async {
    final r = await _w.lifecycle.getInfo(fp);
    return switch (r) {
      Ok(:final value) =>
        value == null ? Err(SecretNotFoundFailure(fp)) : Ok(_build(value)),
      Err(:final failure) => Err(failure),
    };
  }

  // ── registry / umbrella (cross-kind) ──────────────────────────────────────

  /// All stored secrets, as handles.
  static Future<Result<List<Secret>, SecretsFailure>> list() async {
    final r = await _w.lifecycle.listSeeds();
    return r.map((infos) => infos.map(_build).toList());
  }

  /// Whether a secret with [fp] is stored.
  static Future<Result<bool, SecretsFailure>> exists(Fingerprint fp) =>
      _w.lifecycle.exists(fp);

  /// Decrypts [vault] in-package, writes the recovered secret(s) to the store,
  /// and returns their fingerprints. A static create/add op (no pre-existing
  /// handle to hang it on).
  static Future<Result<List<Fingerprint>, SecretsFailure>> restoreVault({
    required EncryptedVault vault,
    required VaultKey vaultKey,
  }) =>
      _w.backup.restoreVault(vault: vault, vaultKey: vaultKey);

  // ── file-private helpers ──────────────────────────────────────────────────

  static Secret _build(SecretInfo i) => switch (i.kind) {
        SecretKind.mnemonic => MnemonicSecret._(i),
        SecretKind.seed => SeedSecret._(i),
      };

  /// On `Ok(fp)`: reads the (just-stored) [SecretInfo] back and wraps it as a
  /// [MnemonicSecret]; on `Err`: passes the failure through.
  static Future<Result<MnemonicSecret, SecretsFailure>> _hydrateMnemonic(
    Result<Fingerprint, SecretsFailure> r,
  ) async {
    switch (r) {
      case Ok(:final value):
        final info = await _w.lifecycle.getInfo(value);
        return switch (info) {
          Ok(value: final i) => i == null
              ? Err(SecretNotFoundFailure(value))
              : Ok(MnemonicSecret._(i)),
          Err(:final failure) => Err(failure),
        };
      case Err(:final failure):
        return Err(failure);
    }
  }
}

/// A capability handle over a stored secret. Carries NON-secret metadata (from
/// the index) and the operations every secret-bearing kind supports. The object
/// holds NO words/bytes — each method does its own use-and-forget read
/// internally and discards the material.
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
        seed: fingerprint,
        scriptType: scriptType,
        isTestnet: !network.isMainnet,
        account: account,
      );

  Future<Result<BitcoinDescriptor, SecretsFailure>> bitcoinDescriptor({
    required ScriptType scriptType,
    required BitcoinNetwork network,
  }) =>
      Secrets._w.keyDerivation.bitcoinDescriptor(
        seed: fingerprint,
        scriptType: scriptType,
        isTestnet: !network.isMainnet,
      );

  Future<Result<LiquidDescriptor, SecretsFailure>> liquidDescriptor({
    required LiquidNetwork network,
  }) =>
      Secrets._w.keyDerivation.liquidDescriptor(
        seed: fingerprint,
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
        seed: fingerprint,
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
        seed: fingerprint,
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
        seed: fingerprint,
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
        seed: fingerprint,
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
        seed: fingerprint,
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
        seed: fingerprint,
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
        seed: fingerprint,
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
          Secrets._w.backup.encryptVault(seed: fingerprint);

  // ── BIP85 child derivation ─────────────────────────────────────────────────

  Future<Result<Bip85Derivation, SecretsFailure>> bip85ChildMnemonic({
    required MnemonicLength length,
    required int index,
  }) =>
      Secrets._w.bip85.deriveChildMnemonic(
        masterSeed: fingerprint,
        length: length,
        index: index,
      );

  Future<Result<Bip85Derivation, SecretsFailure>> bip85Bip39Child({
    required Bip85Application app,
    required int index,
    required MnemonicLength length,
  }) =>
      Secrets._w.bip85.deriveBip39Child(
        masterSeed: fingerprint,
        app: app,
        index: index,
        length: length,
      );

  Future<Result<Bip85HexResult, SecretsFailure>> bip85Hex({
    required int numBytes,
    required int index,
  }) =>
      Secrets._w.bip85.deriveHex(
        masterSeed: fingerprint,
        numBytes: numBytes,
        index: index,
      );

  Future<Result<VaultKey, SecretsFailure>> bip85RecoverbullKey({
    required Bip85Path path,
  }) =>
      Secrets._w.bip85.deriveRecoverbullKey(
        masterSeed: fingerprint,
        path: path,
      );

  Future<Result<ArkSecret, SecretsFailure>> bip85Ark() =>
      Secrets._w.bip85.deriveArkSecret(masterSeed: fingerprint);

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
