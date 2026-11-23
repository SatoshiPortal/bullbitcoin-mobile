import 'ark_funding_signing_guard.dart';

import 'package:sync/sync.dart' show WalletKey;
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart' as sync;
import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show BitcoinSpendStatus;

final class PayjoinWalletAdapter implements PayjoinWalletPort {
  final Secrets _secrets;
  final ArkFundingSigningGuard _arkFundingGuard;
  final Future<Result<sync.Wallet, sync.SyncFailure>> Function(WalletKey)
  _wallet;
  final Future<BitcoinSpendStatus> Function(String walletId) _spendStatus;
  final SyncWalletValuesDatasource _values;
  final WalletMetadataDatasource _metadata;

  /// [_spendStatus] asks the guard through `wallet.tx.check`.
  const PayjoinWalletAdapter(
    this._secrets,
    this._wallet,
    this._spendStatus,
    this._values,
    this._metadata,
    this._arkFundingGuard,
  );

  /// Contention is transient and each check already waits for the wallet:
  /// a few attempts outlast a routine sync instead of pausing the proposal.
  Future<void> _requireSpend(String walletId) async {
    for (var attempt = 1; ; attempt++) {
      final status = await _spendStatus(walletId);
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
    await _requireSpend(walletId);
    final metadata = await _loadMetadata(walletId, network);
    if (await _arkFundingGuard.admit(
          key: WalletKey(id: walletId, network: network),
          unsignedPsbt: psbt,
        )
        case Err()) {
      throw const PayjoinSpendBlockedException(busy: false);
    }
    final secret = await _loadSecret(metadata);
    // The receiver's own input in a payjoin proposal carries no derivation
    // path, and the package signs only what it can derive: sync adds the
    // paths first, from the public descriptors.
    final handle = switch (await _wallet(
      WalletKey(id: walletId, network: network),
    )) {
      Ok(:final value) => value,
      Err(:final failure) => throw sync.WalletSnapshotException(failure),
    };
    final annotated = switch (await handle.tx.annotate(psbt)) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError('sync: ${failure.logCode}'),
    };
    return _unwrap(
      await secret.sign.psbt(
        annotated,
        network: network,
        scriptType: metadata.scriptType.shared,
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
    final ownership = await _values.getOwnership(
      key: WalletKey(id: walletId, network: network),
    );
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
    await _requireSpend(walletId);
    await _loadMetadata(walletId, network);
    final utxos = await _values.getExactUtxos(
      key: WalletKey(id: walletId, network: network),
    );
    return utxos.whereType<sync.BitcoinCoin>().map((utxo) {
      return PayjoinUtxo(
        outpoint: utxo.outpoint,
        value: Sats(utxo.amountSat),
        scriptPubkey: utxo.scriptPubkey,
        confirmed: utxo.confirmations > 0,
      );
    }).toList();
  }

  Future<WalletMetadataModel> _loadMetadata(
    String walletId,
    BitcoinNetwork network,
  ) async {
    final metadata = await _metadata.fetch(walletId);
    if (metadata == null || !metadata.isBitcoin) {
      throw StateError('Bitcoin wallet metadata not found');
    }
    if (metadata.network.shared != network) {
      throw StateError('Wallet network does not match Payjoin network');
    }
    return metadata;
  }

  Future<Secret> _loadSecret(WalletMetadataModel metadata) async {
    final fingerprint = metadata.seedFingerprint;
    if (fingerprint == null) {
      throw Exception('No secret for wallet: not a seed-derived wallet');
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
