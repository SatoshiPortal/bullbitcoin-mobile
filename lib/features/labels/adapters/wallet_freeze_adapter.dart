import 'package:bb_mobile/core/wallet/domain/entities/frozen_wallet_outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/labels/application/wallet_freeze_port.dart';

/// Implements [WalletFreezePort] through the core wallet domain boundary.
class WalletFreezeAdapter implements WalletFreezePort {
  final WalletUtxoRepository _repository;

  WalletFreezeAdapter(this._repository);

  @override
  Future<List<({String walletId, String txId, int vout})>>
  getAllFrozen() async {
    final freezes = await _repository.getAllFrozenWalletOutpoints();
    return freezes
        .map(
          (freeze) =>
              (walletId: freeze.walletId, txId: freeze.txId, vout: freeze.vout),
        )
        .toList(growable: false);
  }

  @override
  Future<void> freeze(
    List<({String? walletId, String txId, int vout})> outputs,
  ) async {
    // A null/empty origin stores under '' — inert until some wallet owns the
    // coin, matched by outpoint either way (it can never be auto-attributed or
    // cleaned up on wallet deletion; this is the documented degraded import).
    await _repository.restoreFrozenWalletOutpoints(
      outputs
          .map(
            (output) => FrozenWalletOutpoint(
              walletId: output.walletId ?? '',
              txId: output.txId,
              vout: output.vout,
            ),
          )
          .toList(growable: false),
    );
  }
}
