import 'package:ark/funding.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart' show BitcoinSpendStatus, WalletKey;
import 'package:sync/sync.dart' as sync;

final class PayjoinWalletAdapter implements PayjoinWalletPort {
  final Secrets _secrets;
  final ArkFundingSigningGuard _arkFundingGuard;
  final Future<Result<sync.Wallet, sync.SyncFailure>> Function(WalletKey)
  _wallet;
  final Future<BitcoinSpendStatus> Function(WalletKey key) _spendStatus;
  final WalletInventory _inventory;

  /// [_spendStatus] asks the guard through `wallet.tx.check`.
  const PayjoinWalletAdapter(
    this._secrets,
    this._wallet,
    this._spendStatus,
    this._inventory,
    this._arkFundingGuard,
  );

  /// Contention is transient and each check already waits for the wallet:
  /// a few attempts outlast a routine sync instead of pausing the proposal.
  Future<void> _requireSpend(WalletKey key) async {
    for (var attempt = 1; ; attempt++) {
      final status = await _spendStatus(key);
      if (status == BitcoinSpendStatus.ready) return;
      if (status != BitcoinSpendStatus.busy || attempt == 5) {
        throw PayjoinSpendBlockedException(
          busy: status == BitcoinSpendStatus.busy,
        );
      }
    }
  }

  @override
  Future<String> signPsbt({
    required String walletId,
    required BitcoinNetwork network,
    required String psbt,
  }) async {
    final key = WalletKey(id: walletId, network: network);
    await _requireSpend(key);
    final metadata = await _loadMetadata(walletId, network);
    if (await _arkFundingGuard.admit(
          walletId: walletId,
          network: network,
          unsignedPsbt: psbt,
        )
        case Err()) {
      throw const PayjoinSpendBlockedException(busy: false);
    }
    final secret = await _loadSecret(metadata);
    // The receiver's own input in a payjoin proposal carries no derivation
    // path, and the package signs only what it can derive: sync adds the
    // paths first, from the public descriptors.
    final handle = await _openWallet(key);
    final annotated = switch (await handle.tx.annotate(psbt)) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError('sync: ${failure.logCode}'),
    };
    return _unwrap(
      await secret.sign.psbt(
        annotated,
        network: network,
        scriptType: metadata.scriptType,
      ),
    );
  }

  @override
  Future<PayjoinWalletOwnership> captureOwnership({
    required String walletId,
    required BitcoinNetwork network,
  }) async {
    // No key is loaded: sync answers from the exact index at the latest committed revision, never from an older frame.
    // Outputs already spent are included, so one we owned and spent still answers as ours.
    await _loadMetadata(walletId, network);
    final handle = await _openWallet(WalletKey(id: walletId, network: network));
    final ownership = _syncValue(await handle.readExactOwnership());
    return PayjoinWalletOwnership(
      ownsScript: ownership.ownsScript,
      ownsOutpoint: ownership.ownsOutpoint,
    );
  }

  @override
  Future<List<PayjoinUtxo>> spendableUtxos({
    required String walletId,
    required BitcoinNetwork network,
  }) async {
    final key = WalletKey(id: walletId, network: network);
    await _requireSpend(key);
    await _loadMetadata(walletId, network);
    final handle = await _openWallet(key);
    final utxos = _syncValue(await handle.readExactUnspent());
    return utxos.whereType<sync.BitcoinCoin>().map((utxo) {
      return PayjoinUtxo(
        outpoint: utxo.outpoint,
        value: Sats(utxo.amountSat),
        scriptPubkey: utxo.scriptPubkey,
        confirmed: utxo.confirmations > 0,
      );
    }).toList();
  }

  Future<sync.Wallet> _openWallet(WalletKey key) async =>
      _syncValue(await _wallet(key));

  static T _syncValue<T>(Result<T, sync.SyncFailure> result) =>
      switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw sync.WalletSnapshotException(failure),
      };

  Future<WalletRegistration> _loadMetadata(
    String walletId,
    BitcoinNetwork network,
  ) async {
    final metadata = _unwrap(await _inventory.readWallet(walletId));
    if (metadata.network != network) {
      throw StateError('Wallet network does not match Payjoin network');
    }
    return metadata;
  }

  Future<Secret> _loadSecret(WalletRegistration metadata) async {
    final fingerprint = metadata.secretFingerprint;
    if (metadata.signer != WalletSigner.local || fingerprint == null) {
      throw Exception('Payjoin requires a local mnemonic wallet');
    }
    final secret = _unwrap(await _secrets.fetch(fingerprint));
    if (!secret.info.isMnemonic) {
      throw StateError('Payjoin requires a local mnemonic wallet');
    }
    return secret;
  }

  /// This adapter already reports every problem by throwing — the port has no failure type — so a package failure becomes a `StateError` naming its kind, never its message.
  static T _unwrap<T>(Result<T, SecretFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError('secrets: ${failure.runtimeType}'),
  };
}
