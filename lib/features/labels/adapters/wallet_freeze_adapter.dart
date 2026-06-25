import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/features/labels/application/wallet_freeze_port.dart';

/// Implements [WalletFreezePort] over the freeze datasource. The only place the
/// labels feature touches `core/wallet`'s freeze storage.
class WalletFreezeAdapter implements WalletFreezePort {
  final FrozenWalletUtxoDatasource _datasource;

  WalletFreezeAdapter({required this._datasource});

  @override
  Future<List<({String walletId, String txId, int vout})>>
  getAllFrozen() => _datasource.getAllFrozen();

  @override
  Future<void> freeze(
    List<({String? walletId, String txId, int vout})> outputs,
  ) async {
    // Group by attributed wallet so each wallet's freezes write in one batch.
    // A null/empty origin stores under '' — inert until some wallet owns the
    // coin, matched by outpoint either way (it can never be auto-attributed or
    // cleaned up on wallet deletion; this is the documented degraded import).
    final byWallet = <String, List<Outpoint>>{};
    for (final o in outputs) {
      (byWallet[o.walletId ?? ''] ??= []).add((txId: o.txId, vout: o.vout));
    }
    for (final entry in byWallet.entries) {
      await _datasource.freezeOutpoints(
        walletId: entry.key,
        outpoints: entry.value,
      );
    }
  }
}
